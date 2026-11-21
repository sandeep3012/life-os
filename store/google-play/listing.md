# Google Play — listing text and form answers (draft)

Draft answers for the Play Console forms, written from what the app does as
of November 2026. Check each against the form's own wording when filling it
in; Google changes these forms.

## Store listing

**App name** (30 max)

    PersonalOS: Money & Habits

**Short description** (80 max)

    Money, habits, tasks, notes and documents in one private app that works offline.

**Full description** (4000 max)

    PersonalOS keeps the everyday parts of your life in one place — your money, your habits, your to-dos, your notes and your important documents — and keeps them on your phone.

    No account needed. No ads. No tracking. It works with no internet at all.

    MONEY
    • Track spending and income across your bank accounts, cards, wallets and cash
    • Set budgets and see how each month is going
    • Keep bills and recurring payments in view, with reminders before they're due
    • See where the money went, by category and by payment method
    • Export a report as a PDF

    HABITS
    • Build routines with weekly targets
    • Streaks and a consistency view that show how you're really doing
    • Reminders at the times you choose

    TASKS AND CALENDAR
    • To-dos with due dates, repeats and reminders
    • Alarms for the things you can't miss
    • One calendar for tasks, habits and events

    NOTES AND DOCUMENTS
    • Notes organised in folders
    • Keep photos and PDFs of receipts, IDs, policies and warranties, and find them when you need them

    GOALS AND INSIGHTS
    • Set goals and link them to the habits, tasks and accounts that move them
    • Insights worked out on your phone from your own data — a budget running hot, a streak about to break

    SAY IT INSTEAD OF TYPING IT
    Hold the + button and say "spent 250 on lunch from HDFC card" or "call mom tomorrow at six". PersonalOS offers the entry; you confirm. (Needs a free account and internet.)

    PRIVATE BY DESIGN
    • Your data is stored on your phone
    • Lock the app with your fingerprint, face or a PIN
    • Back up everything to a file, with a password if you want one
    • Optional sync between phones is encrypted on your phone before it's uploaded

    MAKE IT YOURS
    Light and dark modes, colour themes, backgrounds and fonts.

    Questions or ideas? Write to sand.it.support@gmail.com.

_Add when subscriptions open:_ a "PERSONALOS PLUS" paragraph — sync across
phones, more voice entries, every theme and font — with the price and how
to cancel.

**Category:** Productivity.
**Tags:** personal finance, habit tracker, to-do list, notes.
**Contact details:** email `sand.it.support@gmail.com`; website: the site's
home page (optional); phone: leave empty.
**Countries:** all.

## Graphics

| Asset | Spec | Status |
|---|---|---|
| App icon | 512 × 512, 32-bit PNG | `developer-profile/developer-icon-512.png` (same icon) |
| Feature graphic | 1024 × 500, JPG or 24-bit PNG | `feature-graphic-1024x500.png` |
| Phone screenshots | 2–8, each side 320–3840 px, long side at most twice the short | `screenshots/` (1080 × 2160), nine to choose from |

The screenshots are made from the real app with sample data, no phone
needed. Re-run after any screen changes:

    flutter test tool/store_screenshots/store_screenshots_test.dart

Suggested order on the listing: `01-home`, `02-money`, `04-habits`,
`05-tasks`, `06-calendar`, `07-goals`, `09-documents`, `08-notes`.
`03-spending` is left out until the category names on that screen stop
breaking mid-word.

## App content forms

**Privacy policy:** `https://sandeep3012.github.io/personalos/privacy/`
(built from `docs/privacy-policy.md` by `scripts/build_site.py`).

**Ads:** No, the app contains no ads.

**App access:** All or some functionality is restricted → sync and voice
entry need an account. Give reviewers a test account's email and password in
the form (create one just for this).

**Content rating questionnaire:** Category "Utility, Productivity,
Communication, or Other". No violence, sexual content, profanity, drugs or
gambling; no user-to-user communication; does not share location.

**Target audience:** 18 and over.

**News app:** No. **Government app:** No. **Health apps:** no health
features (Health is hidden in release builds).

**Financial features:** the app is a personal budgeting and expense tracker.
It offers no loans, banking, payments, investments, crypto or financial
advice — select the "none of these" / personal finance management option.

**Permission declarations Google may ask about:**
- *Full-screen intent* (`USE_FULL_SCREEN_INTENT`): used only for alarms the
  person sets, to show the ringing screen over the lock screen. Play grants
  this automatically only to alarm and calling apps, so expect a declaration
  form; the answer is "alarm".
- *Exact alarms* (`SCHEDULE_EXACT_ALARM`): reminders and alarms set by the
  person must fire at the chosen minute.

## Data safety form

**Does the app collect or share any of the required user data types?** Yes.
**Is all of it encrypted in transit?** Yes.
**Can users ask for their data to be deleted?** Yes — in the app (Sync &
account → Delete account) and at a web address, which Google requires:
`https://sandeep3012.github.io/personalos/delete-account/`.
**Account creation:** email and password; Google sign-in.

Nothing is "shared" in Google's sense: Supabase, Anthropic and RevenueCat
process data on our behalf. Everything is optional, because the app works
without an account.

| Data type | Collected? | Why | Notes |
|---|---|---|---|
| Personal info → Email address | Yes | Account management | Only if an account is created |
| Personal info → Name | Yes | Account management | Optional at sign-up |
| Personal info → User IDs | Yes | Account management, app functionality | The account id |
| Financial info → Other financial info | Yes | App functionality | Synced transactions and accounts; account names in voice entry |
| Financial info → Purchase history | Yes, once subscriptions open | App functionality | Plan and expiry, via Google Play and RevenueCat |
| Calendar → Calendar events | Yes | App functionality | Synced events |
| App activity → Other user-generated content | Yes | App functionality | Synced notes, tasks, habits; the text of voice entries |
| Files and docs | Yes | App functionality | Document details only; the files themselves are not uploaded |
| Device or other IDs | Yes | App functionality | A random id per install, to tell synced devices apart |
| Audio → Voice or sound recordings | No | | Speech is turned into text by the phone's own speech service; the app never receives audio |
| Location, Contacts, Messages, Photos and videos, Health and fitness, Web browsing | No | | |
| App info and performance (crash logs, diagnostics) | No | | No analytics or crash reporting |

Why synced data is declared at all: Google lets end-to-end encrypted data go
undeclared, but under Standard recovery the server holds a copy of the key,
so it doesn't qualify. Declaring it is the safe answer.
