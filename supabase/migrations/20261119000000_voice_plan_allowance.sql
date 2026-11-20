-- LifeOS voice entry: the allowance depends on the plan.
--
--   Free         15 voice entries, once (a taste — never refills)
--   LifeOS Plus  300 a month, and no more than 40 in a day
--
-- "Plus" is an active row in `entitlements` — the same test sync's uploads
-- use (`has_sync`). The numbers live here, on the server, so the app can't
-- raise them.
--
-- Replaces `consume_voice_quota(daily_limit)`, which counted a request before
-- checking it (so refused attempts used up allowance) and took its limit from
-- the caller. That function is left in place for the previously deployed
-- `voice-parse`; nothing calls it once the new one is live.
--
-- Safe to re-run.

-- What [uid] has left. Internal: takes any user id, so it isn't callable
-- from outside.
create or replace function public.voice_allowance(uid uuid)
returns jsonb
language plpgsql stable security definer
set search_path = public
as $$
declare
  plus_limit  constant int := 300;
  plus_daily  constant int := 40;
  free_limit  constant int := 15;
  used_total int;
  used_month int;
  used_today int;
begin
  select
    coalesce(sum(count), 0),
    coalesce(sum(count) filter (
      where day >= date_trunc('month', current_date)::date), 0),
    coalesce(sum(count) filter (where day = current_date), 0)
  into used_total, used_month, used_today
  from public.voice_usage
  where user_id = uid;

  if public.has_sync(uid) then
    return jsonb_build_object(
      'plan', 'plus',
      'period', 'month',
      'limit', plus_limit,
      'used', used_month,
      'dailyLimit', plus_daily,
      'usedToday', used_today,
      'remaining',
        greatest(0, least(plus_limit - used_month, plus_daily - used_today))
    );
  end if;
  return jsonb_build_object(
    'plan', 'free',
    'period', 'once',
    'limit', free_limit,
    'used', used_total,
    'remaining', greatest(0, free_limit - used_total)
  );
end;
$$;

-- The signed-in user's own allowance, for the app to show before they speak.
create or replace function public.my_voice_allowance()
returns jsonb
language sql stable security definer
set search_path = public
as $$
  select case
    when auth.uid() is null then null
    else public.voice_allowance(auth.uid())
  end;
$$;

-- Uses one voice entry if there's one left. Checks first, so a refused
-- request costs nothing. Returns the allowance afterwards plus "allowed".
create or replace function public.use_voice_entry()
returns jsonb
language plpgsql security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  allowance jsonb;
begin
  if uid is null then
    return jsonb_build_object('allowed', false, 'reason', 'not_signed_in');
  end if;
  allowance := public.voice_allowance(uid);
  if (allowance->>'remaining')::int <= 0 then
    return allowance || jsonb_build_object('allowed', false);
  end if;
  insert into public.voice_usage as v (user_id, day, count)
  values (uid, current_date, 1)
  on conflict (user_id, day) do update set count = v.count + 1;
  return public.voice_allowance(uid) || jsonb_build_object('allowed', true);
end;
$$;

revoke all on function public.voice_allowance(uuid) from public, anon, authenticated;
revoke all on function public.my_voice_allowance() from public, anon;
revoke all on function public.use_voice_entry() from public, anon;
grant execute on function public.my_voice_allowance() to authenticated;
grant execute on function public.use_voice_entry() to authenticated;
