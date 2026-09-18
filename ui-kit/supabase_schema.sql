-- =====================================================================
-- LifeOS — Supabase / Postgres schema
-- Covers: profiles, accounts, categories, transactions, recurring rules
-- (expenses + SIP), investments, habits, todos, calendar, gym & diet.
-- Every table is RLS-scoped to auth.uid().
-- =====================================================================

create extension if not exists "pgcrypto";
create extension if not exists pg_cron;

-- ---------- enums -------------------------------------------------------
create type account_type   as enum ('bank','credit','cash','wallet','broker');
create type txn_kind       as enum ('expense','income','investment','transfer');
create type cat_kind       as enum ('expense','income','investment');
create type frequency      as enum ('daily','weekly','monthly','quarterly','yearly');
create type instrument     as enum ('index_fund','stock','gold_etf','ppf','fd','crypto','other');
create type habit_cadence  as enum ('daily','weekly');

-- ---------- profiles ----------------------------------------------------
create table profiles (
  id            uuid primary key references auth.users on delete cascade,
  full_name     text not null default '',
  avatar_url    text,
  currency      text not null default 'INR',
  locale        text not null default 'en_IN',
  timezone      text not null default 'Asia/Kolkata',
  theme         text not null default 'system' check (theme in ('light','dark','system')),
  haptics_enabled boolean not null default true,
  created_at    timestamptz not null default now()
);

create or replace function handle_new_user() returns trigger
language plpgsql security definer as $$
begin
  insert into profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''));
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ---------- accounts ----------------------------------------------------
create table accounts (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users on delete cascade,
  name            text not null,
  type            account_type not null default 'bank',
  opening_balance numeric(14,2) not null default 0,
  balance         numeric(14,2) not null default 0,
  color           text not null default '#4B7BA6',
  institution     text,
  is_archived     boolean not null default false,
  sort_order      int not null default 0,
  created_at      timestamptz not null default now()
);
create index on accounts (user_id) where not is_archived;

-- ---------- categories --------------------------------------------------
create table categories (
  id        uuid primary key default gen_random_uuid(),
  user_id   uuid not null references auth.users on delete cascade,
  name      text not null,
  kind      cat_kind not null default 'expense',
  color     text not null default '#9A9384',
  icon      text,
  is_system boolean not null default false,
  unique (user_id, name, kind)
);

-- Seed set matching the design's palette.
create or replace function seed_categories(uid uuid) returns void
language sql as $$
  insert into categories (user_id, name, kind, color, is_system) values
    (uid,'Rent','expense','#C2703D',true),
    (uid,'Food & Dining','expense','#0E9F6E',true),
    (uid,'Transport','expense','#4B7BA6',true),
    (uid,'Shopping','expense','#B0558E',true),
    (uid,'Bills & Utilities','expense','#D9A441',true),
    (uid,'Entertainment / OTT','expense','#7C6BC4',true),
    (uid,'Health','expense','#3FA6A0',true),
    (uid,'Misc','expense','#9A9384',true),
    (uid,'Salary','income','#0E9F6E',true),
    (uid,'Freelance','income','#4B7BA6',true),
    (uid,'Dividend','income','#7C6BC4',true),
    (uid,'Refund','income','#D9A441',true),
    (uid,'Index Fund','investment','#7C6BC4',true),
    (uid,'Stocks','investment','#4B7BA6',true),
    (uid,'Gold ETF','investment','#D9A441',true),
    (uid,'PPF','investment','#0E9F6E',true)
  on conflict do nothing;
$$;

-- ---------- investments -------------------------------------------------
create table investments (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users on delete cascade,
  name          text not null,
  type          instrument not null default 'index_fund',
  account_id    uuid references accounts on delete set null,
  units         numeric(18,6) not null default 0,
  avg_cost      numeric(14,4) not null default 0,
  invested      numeric(14,2) not null default 0,
  current_value numeric(14,2) not null default 0,
  xirr          numeric(6,2),
  updated_at    timestamptz not null default now(),
  created_at    timestamptz not null default now()
);
create index on investments (user_id);

-- ---------- recurring rules --------------------------------------------
-- Drives BOTH recurring expenses (insurance, OTT, rent, EMI) and
-- recurring investments (SIP). auto_post = true means the row is inserted
-- into transactions automatically on next_run_on.
create table recurring_rules (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users on delete cascade,
  label         text not null,
  kind          txn_kind not null default 'expense',
  amount        numeric(14,2) not null check (amount > 0),
  account_id    uuid references accounts on delete set null,
  category_id   uuid references categories on delete set null,
  investment_id uuid references investments on delete set null,
  freq          frequency not null default 'monthly',
  interval      int not null default 1 check (interval >= 1),
  day_of_month  int check (day_of_month between 1 and 31),
  weekday       int check (weekday between 0 and 6),          -- 0 = Sunday
  starts_on     date not null default current_date,
  ends_on       date,
  next_run_on   date not null,
  last_run_on   date,
  auto_post     boolean not null default true,
  is_paused     boolean not null default false,
  note          text,
  created_at    timestamptz not null default now()
);
create index on recurring_rules (user_id, next_run_on) where not is_paused;

-- ---------- transactions ------------------------------------------------
create table transactions (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users on delete cascade,
  account_id        uuid references accounts on delete set null,
  to_account_id     uuid references accounts on delete set null,  -- transfers
  category_id       uuid references categories on delete set null,
  investment_id     uuid references investments on delete set null,
  recurring_rule_id uuid references recurring_rules on delete set null,
  kind              txn_kind not null,
  amount            numeric(14,2) not null check (amount > 0),
  occurred_at       timestamptz not null default now(),
  merchant          text,
  note              text,
  is_auto           boolean not null default false,  -- generated by a rule
  created_at        timestamptz not null default now()
);
create index on transactions (user_id, occurred_at desc);
create index on transactions (user_id, category_id, occurred_at desc);

-- Keep account balances in sync.
create or replace function apply_txn_to_balance() returns trigger
language plpgsql as $$
declare sign int;
begin
  if (tg_op in ('INSERT','UPDATE')) then
    sign := case when new.kind = 'income' then 1 else -1 end;
    update accounts set balance = balance + sign * new.amount where id = new.account_id;
    if new.kind = 'transfer' and new.to_account_id is not null then
      update accounts set balance = balance + new.amount where id = new.to_account_id;
    end if;
  end if;
  if (tg_op in ('UPDATE','DELETE')) then
    sign := case when old.kind = 'income' then 1 else -1 end;
    update accounts set balance = balance - sign * old.amount where id = old.account_id;
    if old.kind = 'transfer' and old.to_account_id is not null then
      update accounts set balance = balance - old.amount where id = old.to_account_id;
    end if;
  end if;
  return coalesce(new, old);
end $$;

create trigger txn_balance
  after insert or update or delete on transactions
  for each row execute function apply_txn_to_balance();

-- ---------- recurring engine -------------------------------------------
create or replace function advance_date(d date, f frequency, n int) returns date
language sql immutable as $$
  select case f
    when 'daily'     then d + (n || ' days')::interval
    when 'weekly'    then d + (n || ' weeks')::interval
    when 'monthly'   then d + (n || ' months')::interval
    when 'quarterly' then d + (3 * n || ' months')::interval
    when 'yearly'    then d + (n || ' years')::interval
  end::date;
$$;

-- Posts every due rule and rolls next_run_on forward. Idempotent per day.
create or replace function post_due_recurring() returns int
language plpgsql security definer as $$
declare r record; posted int := 0;
begin
  for r in
    select * from recurring_rules
    where not is_paused and auto_post
      and next_run_on <= current_date
      and (ends_on is null or next_run_on <= ends_on)
  loop
    insert into transactions (user_id, account_id, category_id, investment_id,
                              recurring_rule_id, kind, amount, occurred_at,
                              merchant, note, is_auto)
    values (r.user_id, r.account_id, r.category_id, r.investment_id,
            r.id, r.kind, r.amount, r.next_run_on::timestamptz,
            r.label, r.note, true);

    update recurring_rules
       set last_run_on = r.next_run_on,
           next_run_on = advance_date(r.next_run_on, r.freq, r.interval)
     where id = r.id;

    posted := posted + 1;
  end loop;
  return posted;
end $$;

select cron.schedule('post-recurring', '5 0 * * *', $$select post_due_recurring()$$);

-- ---------- habits ------------------------------------------------------
create table habits (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users on delete cascade,
  name       text not null,
  unit       text not null default 'times',
  goal       numeric(10,2) not null default 1,
  cadence    habit_cadence not null default 'daily',
  color      text not null default '#0E9F6E',
  remind_at  time,
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

create table habit_logs (
  id       uuid primary key default gen_random_uuid(),
  user_id  uuid not null references auth.users on delete cascade,
  habit_id uuid not null references habits on delete cascade,
  on_date  date not null default current_date,
  value    numeric(10,2) not null default 1,
  unique (habit_id, on_date)
);
create index on habit_logs (user_id, on_date desc);

-- ---------- todos & reminders ------------------------------------------
create table todos (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users on delete cascade,
  title      text not null,
  notes      text,
  due_at     timestamptz,
  remind_at  timestamptz,
  priority   int not null default 2 check (priority between 1 and 3),
  color      text,
  done_at    timestamptz,
  created_at timestamptz not null default now()
);
create index on todos (user_id, due_at) where done_at is null;

-- ---------- calendar & notes -------------------------------------------
create table calendar_events (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users on delete cascade,
  title      text not null,
  starts_at  timestamptz not null,
  ends_at    timestamptz,
  location   text,
  source     text not null default 'lifeos',
  color      text default '#4B7BA6',
  created_at timestamptz not null default now()
);
create index on calendar_events (user_id, starts_at);

create table notes (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users on delete cascade,
  title      text not null default '',
  body       text not null default '',
  tags       text[] not null default '{}',
  pinned     boolean not null default false,
  updated_at timestamptz not null default now()
);

-- ---------- gym & diet planner -----------------------------------------
create table workout_plans (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users on delete cascade,
  name       text not null,
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

create table workout_days (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users on delete cascade,
  plan_id      uuid not null references workout_plans on delete cascade,
  weekday      int not null check (weekday between 0 and 6),
  label        text not null,                    -- 'Push Day'
  focus        text,                             -- 'Chest & Triceps'
  starts_at    time not null default '07:00',
  ends_at      time not null default '08:00',
  unique (plan_id, weekday)
);

create table exercises (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users on delete cascade,
  workout_day_id uuid not null references workout_days on delete cascade,
  name           text not null,                  -- 'Incline Dumbbell Press'
  sets           int not null default 3,
  reps           int not null default 10,
  weight_kg      numeric(6,2),
  rest_sec       int not null default 90,
  sort_order     int not null default 0
);

create table workout_logs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users on delete cascade,
  exercise_id uuid not null references exercises on delete cascade,
  on_date     date not null default current_date,
  sets_done   int not null default 0,
  weight_kg   numeric(6,2),
  notes       text
);
create index on workout_logs (user_id, on_date desc);

create table diet_plans (
  id        uuid primary key default gen_random_uuid(),
  user_id   uuid not null references auth.users on delete cascade,
  name      text not null,
  is_active boolean not null default true
);

create table meals (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users on delete cascade,
  diet_plan_id uuid not null references diet_plans on delete cascade,
  weekday      int not null check (weekday between 0 and 6),
  slot         text not null,                    -- breakfast | lunch | snack | dinner
  items        text not null,
  kcal         int,
  protein_g    int,
  at_time      time,
  sort_order   int not null default 0
);

-- ---------- dashboard feed ---------------------------------------------
-- Single query behind the "Coming up" list: calendar + due recurring + todos.
create or replace view upcoming_feed as
  select user_id, 'calendar' as source, title as label, starts_at as due_at, null::numeric as amount
    from calendar_events where starts_at >= now()
  union all
  select user_id, case when kind = 'investment' then 'investment' else 'scheduled_expense' end,
         label, next_run_on::timestamptz, amount
    from recurring_rules where not is_paused
  union all
  select user_id, 'todo', title, due_at, null
    from todos where done_at is null and due_at is not null;

-- ---------- RLS ---------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['accounts','categories','transactions','recurring_rules',
                           'investments','habits','habit_logs','todos','calendar_events',
                           'notes','workout_plans','workout_days','exercises','workout_logs',
                           'diet_plans','meals']
  loop
    execute format('alter table %I enable row level security', t);
    execute format($f$create policy "own rows" on %I for all
                      using (user_id = auth.uid())
                      with check (user_id = auth.uid())$f$, t);
  end loop;
end $$;

alter table profiles enable row level security;
create policy "own profile" on profiles for all
  using (id = auth.uid()) with check (id = auth.uid());
