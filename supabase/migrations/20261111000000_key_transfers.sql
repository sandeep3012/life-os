-- LifeOS: "Approve from my other phone".
--
-- A phone that wants to join shows a QR code holding a one-off public key.
-- A phone that already syncs scans it, seals the data key to that public key
-- (X25519 → HKDF-SHA256 → XChaCha20-Poly1305) and leaves the sealed copy here
-- for the new phone to collect. The server only relays ciphertext: the
-- public key travelled by camera, never through the server, so it can't
-- swap in its own.
--
-- Rows are the account's own, readable for 15 minutes, and deleted by the
-- new phone as soon as it has the key (and with the account).

create table if not exists public.key_transfers (
  id         uuid primary key,
  user_id    uuid not null default auth.uid()
             references auth.users (id) on delete cascade,
  sealed     text not null,
  created_at timestamptz not null default now()
);

alter table public.key_transfers enable row level security;

drop policy if exists "leave own transfer" on public.key_transfers;
create policy "leave own transfer" on public.key_transfers
  for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists "collect own recent transfer" on public.key_transfers;
create policy "collect own recent transfer" on public.key_transfers
  for select to authenticated
  using (
    user_id = (select auth.uid())
    and created_at > now() - interval '15 minutes'
  );

drop policy if exists "remove own transfer" on public.key_transfers;
create policy "remove own transfer" on public.key_transfers
  for delete to authenticated
  using (user_id = (select auth.uid()));

create index if not exists key_transfers_user_idx
  on public.key_transfers (user_id);
