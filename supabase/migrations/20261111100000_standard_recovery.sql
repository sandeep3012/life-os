-- LifeOS: Standard recovery — an opt-in copy of the account's data key held
-- by the server, so signing in on any phone gets the data back even with
-- every phone, the platform backup and the recovery key lost.
--
-- The trade, stated plainly in the app: with this on, the server *could*
-- read that account's data. It's kept in Supabase Vault (encrypted with a key
-- Supabase holds outside the database, so a database dump alone doesn't
-- reveal it) and only these functions touch it, each limited to the caller's
-- own copy. Maximum privacy (the default before this) simply has no copy.

create or replace function public.escrow_store(data_key text)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  existing uuid;
begin
  if uid is null then
    raise exception 'not_signed_in' using errcode = '28000';
  end if;
  if data_key is null or length(data_key) < 40 or length(data_key) > 64 then
    raise exception 'bad_key' using errcode = '22023';
  end if;
  select id into existing from vault.secrets
    where name = 'lifeos_escrow_' || uid::text;
  if existing is null then
    perform vault.create_secret(
      data_key,
      'lifeos_escrow_' || uid::text,
      'LifeOS sync data key (Standard recovery)'
    );
  else
    perform vault.update_secret(existing, data_key);
  end if;
end;
$$;

create or replace function public.escrow_fetch()
returns text
language sql stable security definer
set search_path = ''
as $$
  select decrypted_secret from vault.decrypted_secrets
  where auth.uid() is not null
    and name = 'lifeos_escrow_' || auth.uid()::text;
$$;

create or replace function public.escrow_exists()
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from vault.secrets
    where auth.uid() is not null
      and name = 'lifeos_escrow_' || auth.uid()::text
  );
$$;

create or replace function public.escrow_remove()
returns void
language sql security definer
set search_path = ''
as $$
  delete from vault.secrets
  where auth.uid() is not null
    and name = 'lifeos_escrow_' || auth.uid()::text;
$$;

-- Deleting an account takes its copy with it.
create or replace function public.escrow_forget_user()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  delete from vault.secrets where name = 'lifeos_escrow_' || old.id::text;
  return old;
end;
$$;

drop trigger if exists escrow_forget_user on auth.users;
create trigger escrow_forget_user
  after delete on auth.users
  for each row execute function public.escrow_forget_user();

revoke all on function public.escrow_store(text) from public, anon;
revoke all on function public.escrow_fetch() from public, anon;
revoke all on function public.escrow_exists() from public, anon;
revoke all on function public.escrow_remove() from public, anon;
revoke all on function public.escrow_forget_user() from public, anon, authenticated;
grant execute on function public.escrow_store(text) to authenticated;
grant execute on function public.escrow_fetch() to authenticated;
grant execute on function public.escrow_exists() to authenticated;
grant execute on function public.escrow_remove() to authenticated;
