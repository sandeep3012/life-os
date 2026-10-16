-- LifeOS sync: the server side.
--
-- Run once in the Supabase dashboard → SQL editor. Safe to re-run: every
-- statement replaces or skips what's already there.
--
-- The server only ever holds ciphertext. It can see how many records a user
-- has, their sizes and when they changed — never what they say, or which
-- part of the app they belong to.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create sequence if not exists public.sync_seq;

-- One row per synced app row, whatever table it came from.
create table if not exists public.sync_records (
  user_id    uuid    not null references auth.users on delete cascade,
  id         uuid    not null,              -- derived from the app row's key
  seq        bigint  not null,              -- server-assigned, only increases
  hlc        text    not null,              -- writer's hybrid logical clock
  device_id  uuid    not null,
  deleted    boolean not null default false,
  payload    bytea   not null,              -- nonce + ciphertext + tag
  schema_ver int     not null,              -- app schema that wrote it
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);
create index if not exists sync_records_user_seq
  on public.sync_records (user_id, seq);

-- The data key, sealed with the user's recovery key. Base64.
create table if not exists public.user_keys (
  user_id          uuid primary key references auth.users on delete cascade,
  wrapped_recovery text not null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- Who may upload. Written only by the payments webhook (later) or by hand
-- while testing — never by the app.
create table if not exists public.entitlements (
  user_id    uuid primary key references auth.users on delete cascade,
  active     boolean not null,
  product_id text,
  store      text,                           -- app_store | play_store | manual
  expires_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.devices (
  id        uuid primary key,
  user_id   uuid not null references auth.users on delete cascade,
  name      text,
  last_seen timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Row-level security: each user reaches only their own rows.
-- ---------------------------------------------------------------------------

alter table public.sync_records enable row level security;
alter table public.user_keys    enable row level security;
alter table public.entitlements enable row level security;
alter table public.devices      enable row level security;

-- Records: read your own (a lapsed subscriber can still restore). There is
-- no write policy — every write goes through push_records().
drop policy if exists "read own records" on public.sync_records;
create policy "read own records" on public.sync_records
  for select using (user_id = auth.uid());

drop policy if exists "own key" on public.user_keys;
create policy "own key" on public.user_keys
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "read own entitlement" on public.entitlements;
create policy "read own entitlement" on public.entitlements
  for select using (user_id = auth.uid());

drop policy if exists "own devices" on public.devices;
create policy "own devices" on public.devices
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Functions
-- ---------------------------------------------------------------------------

-- An active subscription, with three days' grace after it lapses.
create or replace function public.has_sync(uid uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.entitlements
    where user_id = uid and active
      and (expires_at is null or expires_at > now() - interval '3 days')
  );
$$;

create or replace function public.my_sync_access()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select public.has_sync(auth.uid());
$$;

-- The only way records are written. For each record: kept if the server's
-- copy is newer (and that copy returned as a conflict), otherwise stored
-- with a new seq.
--
-- batch: [{id, hlc, device_id, deleted, payload (base64), schema_ver}, …]
-- returns: {accepted: [id, …], conflicts: [record with seq, …]}
create or replace function public.push_records(batch jsonb)
returns jsonb
language plpgsql security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  item jsonb;
  existing public.sync_records%rowtype;
  accepted jsonb := '[]'::jsonb;
  conflicts jsonb := '[]'::jsonb;
begin
  if uid is null then
    raise exception 'not_signed_in' using errcode = '28000';
  end if;
  if not public.has_sync(uid) then
    raise exception 'not_entitled' using errcode = 'P0001';
  end if;
  if jsonb_array_length(batch) > 500 then
    raise exception 'batch_too_large' using errcode = '22023';
  end if;

  -- One push per user at a time, so seqs are committed in the order they
  -- were handed out and a pull can never skip past one still in flight.
  perform pg_advisory_xact_lock(hashtextextended(uid::text, 0));

  for item in select * from jsonb_array_elements(batch) loop
    select * into existing from public.sync_records
      where user_id = uid and id = (item->>'id')::uuid;

    if found and existing.hlc > (item->>'hlc') then
      conflicts := conflicts || jsonb_build_object(
        'id', existing.id,
        'hlc', existing.hlc,
        'device_id', existing.device_id,
        'deleted', existing.deleted,
        'payload', encode(existing.payload, 'base64'),
        'schema_ver', existing.schema_ver,
        'seq', existing.seq
      );
    else
      insert into public.sync_records
        (user_id, id, seq, hlc, device_id, deleted, payload, schema_ver, updated_at)
      values (
        uid,
        (item->>'id')::uuid,
        nextval('public.sync_seq'),
        item->>'hlc',
        (item->>'device_id')::uuid,
        (item->>'deleted')::boolean,
        decode(item->>'payload', 'base64'),
        (item->>'schema_ver')::int,
        now()
      )
      on conflict (user_id, id) do update set
        seq = excluded.seq,
        hlc = excluded.hlc,
        device_id = excluded.device_id,
        deleted = excluded.deleted,
        payload = excluded.payload,
        schema_ver = excluded.schema_ver,
        updated_at = now();
      accepted := accepted || to_jsonb(item->>'id');
    end if;
  end loop;

  return jsonb_build_object('accepted', accepted, 'conflicts', conflicts);
end;
$$;

-- Records changed after the given seq, oldest first, payloads in base64.
create or replace function public.pull_records(after_seq bigint, max_rows int default 500)
returns table (
  id uuid, seq bigint, hlc text, device_id uuid, deleted boolean,
  payload text, schema_ver int
)
language sql stable security invoker
set search_path = public
as $$
  select r.id, r.seq, r.hlc, r.device_id, r.deleted,
         encode(r.payload, 'base64'), r.schema_ver
  from public.sync_records r
  where r.user_id = auth.uid() and r.seq > after_seq
  order by r.seq
  limit least(greatest(max_rows, 1), 1000);
$$;

-- Settings → Sync → Delete account. Removes the auth user; every table
-- above goes with it through its foreign key. Data on the phone stays.
create or replace function public.delete_my_account()
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_signed_in' using errcode = '28000';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

-- Only signed-in users may call these; never the anonymous role.
revoke all on function public.has_sync(uuid) from public, anon;
revoke all on function public.my_sync_access() from public, anon;
revoke all on function public.push_records(jsonb) from public, anon;
revoke all on function public.pull_records(bigint, int) from public, anon;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.my_sync_access() to authenticated;
grant execute on function public.push_records(jsonb) to authenticated;
grant execute on function public.pull_records(bigint, int) to authenticated;
grant execute on function public.delete_my_account() to authenticated;

-- ---------------------------------------------------------------------------
-- While testing, before payments exist: give an account sync by hand.
-- Replace the email and run this line on its own.
--
--   insert into public.entitlements (user_id, active, store)
--   select id, true, 'manual' from auth.users where email = 'you@example.com'
--   on conflict (user_id) do update set active = true;
-- ---------------------------------------------------------------------------
