-- TEMPORARY — testing period only. Remove when payments (RevenueCat) go live.
--
-- Sync is a paid feature: push_records only accepts uploads from accounts
-- with an active `entitlements` row, which the payments webhook will write.
-- Until that exists, this gives every account sync automatically, the moment
-- it signs up, instead of granting each one by hand.
--
-- Grants made here are marked store = 'beta', so they can be told apart from
-- real subscriptions later.
--
-- To remove (when payments launch):
--   drop trigger if exists grant_beta_sync on auth.users;
--   drop function if exists public.grant_beta_sync();
--   -- then decide what happens to existing beta grants, e.g.:
--   -- update public.entitlements set active = false where store = 'beta';

create or replace function public.grant_beta_sync()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  insert into public.entitlements (user_id, active, store)
  values (new.id, true, 'beta')
  on conflict (user_id) do nothing;
  return new;
end;
$$;

-- A trigger function only; never callable from the API.
revoke all on function public.grant_beta_sync() from public, anon, authenticated;

drop trigger if exists grant_beta_sync on auth.users;
create trigger grant_beta_sync
  after insert on auth.users
  for each row execute function public.grant_beta_sync();

-- Accounts that already exist get the same.
insert into public.entitlements (user_id, active, store)
select id, true, 'beta' from auth.users
on conflict (user_id) do nothing;
