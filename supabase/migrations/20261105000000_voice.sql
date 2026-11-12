-- LifeOS voice entry: a per-user daily allowance for the `voice-parse`
-- function, so one account can't run up the AI bill.
--
-- Run once in the Supabase dashboard → SQL editor, after the sync migration.
-- Safe to re-run.

create table if not exists public.voice_usage (
  user_id uuid not null references auth.users on delete cascade,
  day     date not null,
  count   int  not null default 0,
  primary key (user_id, day)
);

alter table public.voice_usage enable row level security;

drop policy if exists "read own voice usage" on public.voice_usage;
create policy "read own voice usage" on public.voice_usage
  for select using (user_id = auth.uid());

-- Counts one request for the signed-in user and says whether it's within
-- today's allowance. The only writer of voice_usage.
create or replace function public.consume_voice_quota(daily_limit int default 100)
returns boolean
language plpgsql security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  used int;
begin
  if uid is null then
    return false;
  end if;
  insert into public.voice_usage as v (user_id, day, count)
  values (uid, current_date, 1)
  on conflict (user_id, day) do update set count = v.count + 1
  returning v.count into used;
  return used <= daily_limit;
end;
$$;

revoke all on function public.consume_voice_quota(int) from public, anon;
grant execute on function public.consume_voice_quota(int) to authenticated;
