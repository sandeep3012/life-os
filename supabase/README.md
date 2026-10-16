# LifeOS sync — server setup

Sync is optional: a build without the key below is the same local-only app
as before. Everything is encrypted on the phone, so the server only ever
holds ciphertext.

Project: `https://hxqvkhtulmmocfwpzeiv.supabase.co`

## 1. Database

Dashboard → **SQL Editor** → paste all of
[`migrations/20261009000000_sync.sql`](migrations/20261009000000_sync.sql)
→ **Run**. It's safe to run again.

It creates `sync_records`, `user_keys`, `entitlements` and `devices` with
row-level security, plus the `push_records`, `pull_records`,
`my_sync_access` and `delete_my_account` functions.

## 2. Auth settings

**Authentication → URL Configuration**

- Redirect URLs: add `lifeos://auth-callback`

**Authentication → Providers → Email**: on, with *Confirm email* on.

**Authentication → Providers → Google**

1. Google Cloud Console → APIs & Services → Credentials → *Create OAuth
   client ID* → type **Web application**.
2. Authorised redirect URI:
   `https://hxqvkhtulmmocfwpzeiv.supabase.co/auth/v1/callback`
3. Paste its Client ID and Client secret into Supabase and enable.

**Authentication → Providers → Apple** — *not set up yet; the app hides the
Apple button until `SupabaseConfig.appleSignIn` is true.* Needs a paid Apple
Developer membership.

1. Identifiers → App ID `com.sandeep.lifeos` with *Sign in with Apple*.
2. Identifiers → a **Services ID** (e.g. `com.sandeep.lifeos.signin`) with
   *Sign in with Apple*: domain `hxqvkhtulmmocfwpzeiv.supabase.co`, return URL
   `https://hxqvkhtulmmocfwpzeiv.supabase.co/auth/v1/callback`.
3. Keys → a key with *Sign in with Apple* → download the `.p8` (once only);
   note its Key ID and your Team ID.
4. In Supabase: Client IDs = the Services ID; Secret Key = a JWT generated
   from the `.p8`, Team ID, Key ID and Services ID (generator on Supabase's
   Apple sign-in docs page). **Apple expires it every 6 months** — regenerate
   and paste it again, or Apple sign-in stops working.
5. Set `SupabaseConfig.appleSignIn = true`.

Note: App Store review requires Sign in with Apple on iOS once Google sign-in
is offered there — set this up before submitting to the App Store.

Both social sign-ins open in the browser and come back through
`lifeos://auth-callback`, which the app registers on Android
(`AndroidManifest.xml`) and iOS (`Info.plist`).

## 3. Give your account sync (until payments exist)

Uploads are refused without an active entitlement. After signing up in the
app, run in the SQL editor with your email:

```sql
insert into public.entitlements (user_id, active, store)
select id, true, 'manual' from auth.users where email = 'you@example.com'
on conflict (user_id) do update set active = true;
```

## 4. Run the app with sync

Use the **publishable** key (Project Settings → API Keys; `sb_publishable_…`,
or the legacy `anon` key). Never the secret / `service_role` key.

```bash
flutter run --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxx
```

Or copy `supabase.example.json` to `supabase.json` (gitignored), fill it in,
and run `flutter run --dart-define-from-file=supabase.json`.

## What syncs

Every module's data — finance, habits, tasks, goals, calendar, notes,
documents' records, health, learn, folders, tags. Not synced: insights
(recomputed on each phone), app settings (app lock, motion, theme, sounds,
currency), and sample data.

Not yet: document **files** (only their records sync, so a document added on
another phone shows without its file), background sync while the app is
closed, and payments.
