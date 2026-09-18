# Handoff: LifeOS — Auth, Dashboard, Finance & Add-Money Flow

## Overview
LifeOS is a personal-life operating system: finance (expenses, income, investments, recurring/SIP), habits, calendar & notes, gym + diet planner, and to-dos/reminders. This handoff covers the **first slice**: Login, Signup, Dashboard, Finance (Expenses), the sidebar drawer + bottom navigation, and the complete **add-entry flow** (expense, income, investment, recurring SIP, recurring expense, account).

Target stack: **Flutter (iOS + Android)** with **Supabase** (Postgres + Auth + Realtime + Edge Functions).

## About the Design Files
`LifeOS.dc.html` in this bundle is a **design reference created in HTML** — an interactive prototype showing intended look, motion, and behavior. It is **not production code to copy**. The task is to **recreate these designs in Flutter** using idiomatic Flutter widgets, the app's theming system, and the packages listed below. Read the HTML for exact values (colors, radii, sizes, copy) — do not port its markup.

> **Read `BRAND_AND_UI_KIT.md` first.** It carries the app icon spec, the complete token set (including the per-theme semantic colour pairs), the icon family, and every reusable component with its Flutter mapping. `LifeOS UI Kit.dc.html` is the live version of it — open it in a browser and press things. Build the shared widgets from that document *before* building screens from this one; the section below then becomes assembly rather than design.

## Fidelity
**High-fidelity.** Colors, typography, spacing, radii, copy, and interaction timings are final. Recreate pixel-faithfully. Both **light and dark** themes are specified, and both **iOS and Android** status-bar/chrome treatments are shown.

---

## Design Tokens

### Colors — Light
| Token | Hex | Use |
|---|---|---|
| `bg` | `#F5F1E9` | screen background (warm cream) |
| `surface` | `#FFFFFF` | cards, inputs, list rows |
| `surface2` | `#FAF6EE` | segmented-control track, keypad tray |
| `text` | `#1C1B18` | primary text |
| `text2` | `#6E6A61` | secondary text |
| `text3` | `#9C978C` | tertiary / captions / inactive nav |
| `border` | `rgba(28,27,24,0.09)` | 1px card borders |
| `border2` | `rgba(28,27,24,0.06)` | dividers |
| `accent` | `#0E9F6E` | primary emerald |
| `accentInk` | `#0B7C56` | accent text on light bg |
| `accentSoft` | `rgba(14,159,110,0.12)` | selected chip / icon wells |
| `btn` | `#0B7C56` | fill of any accent surface that carries text |
| `onAccent` | `#FFFFFF` | ink/glyphs on `btn` and hero gradients |
| `heroA` → `heroB` | `#0A6E4D` → `#0C8058` | 150° gym-card / avatar gradient |
| `heroVeil` | `rgba(255,255,255,0.10)` | decorative circles on hero |
| `heroTrack` | `rgba(255,255,255,0.28)` | progress track on hero |

### Colors — Dark
| Token | Hex |
|---|---|
| `bg` | `#161512` |
| `surface` | `#201E1A` |
| `surface2` | `#2A2823` |
| `raised` (bottom nav) | `#26241F` |
| `text` | `#F4F0E7` |
| `text2` | `#A9A499` |
| `text3` | `#736F66` |
| `border` | `rgba(255,255,255,0.10)` |
| `border2` | `rgba(255,255,255,0.05)` |
| `accent` | `#34D399` |
| `accentInk` | `#6EE7B7` |
| `accentSoft` | `rgba(52,211,153,0.16)` |
| `btn` | `#34D399` |
| `onAccent` | `#0C0B09` |
| `heroA` → `heroB` | `#34D399` → `#6EE7B7` |
| `heroVeil` | `rgba(12,11,9,0.10)` |
| `heroTrack` | `rgba(12,11,9,0.24)` |

**Contrast rule (important):** never put white on the accent. Text and glyphs on any accent fill or hero gradient use `onAccent` — white in light (5.21:1 on `#0B7C56`), near-black in dark (5.81:1 on `#34D399`). This covers the gym hero card, avatar initials, all primary CTAs, selected frequency chips, the FAB plus, and every checkmark. In Flutter, expose it as `LifeOSColors.onAccent` and set it as the `ColorScheme.onPrimary` / `foregroundColor` of every filled button.

### Category / semantic colors (same in both themes)
`Rent #C2703D` · `Food & Dining #0E9F6E` · `Transport #4B7BA6` · `Shopping #B0558E` · `Bills & Utilities #D9A441` (text-on-light variant `#C99320`) · `Entertainment/OTT #7C6BC4` · `Health #3FA6A0` · `Misc #9A9384`.
Category chip/avatar wells use the category color at **15% alpha**; the glyph/initial uses it at full opacity.

### Typography
- **Display / headings:** `Newsreader` (serif), weights 400/500/600. Google Fonts.
  - Screen hero: 38–42px, w500, letter-spacing −0.5px, line-height 1.02–1.06
  - Section headings: 17–19px, w600
  - Big money figures: 42–46px, w500, tabular figures
- **UI / body:** `Manrope` (sans), weights 400–800.
  - Body: 14–15px w600 · Captions: 11–12.5px w600–800 · Buttons: 15.5px w700
  - Overline labels: 11px, w800, letter-spacing 0.6–1.2px, uppercase
- All money uses **tabular figures** (`fontFeatures: [FontFeature.tabularFigures()]`).
- Indian digit grouping throughout: `₹1,85,000` (2-2-3 lakh grouping), **not** `₹185,000`.

### Radii
Chips/keys `11–13` · inputs & rows `15–16` · cards `18–22` · bottom nav & sheets `24–30` · sheet top corners `30` · phone screen `42`.

### Spacing
4/8-based: `4, 6, 8, 9, 11, 14, 16, 20, 22, 26, 34`. Screen horizontal padding **20px** (28px on auth screens). Bottom-nav safe padding **108px** at the end of scroll views.

### Shadows
- Cards: `0 12px 30px -12px rgba(0,0,0,0.35)` (bottom nav only; cards use borders, not shadows)
- Accent FAB: `0 8px 18px -6px accent`
- Segmented selected pill: `0 2px 6px -2px rgba(0,0,0,0.2)`

---

## Screens / Views

### 1. Login
**Purpose:** returning-user sign-in.
**Layout:** single column, 28px horizontal padding, vertically centered.
- Brand row: 34×34 accent square (radius 11) with serif "L", + "LifeOS" 20px Newsreader w600.
- Hero: "Welcome / back." 40px Newsreader w500; the period is `accent`.
- Sub: "Your whole life, one calm place. Let's pick up where you left off." 14.5px, `text2`, line-height 1.5.
- Two fields (Email, Password): 12px w600 `text2` label above; 52px-tall row, `surface` bg, 1px `border`, radius 15, leading 18px outline icon in `text3`, 15px w400 value. Password shows an eye toggle.
- "Forgot password?" right-aligned, 13px w600 `accentInk`.
- Primary button: 54px, radius 16, `accent` bg, white 15.5px w700, trailing arrow icon.
- Divider row: 1px `border` lines flanking "or continue with" (12px w600 `text3`).
- Social row: 2-up grid, 50px tall, radius 14, `surface` + `border`, Google (brand-color mark) and Apple.
- Footer: "New here? **Create an account**" — bold part `accentInk`.

### 2. Signup
Same field system. Back row at top (chevron + "Back", 14px w600 `text2`). Hero "Start your / LifeOS.". Fields: Full name, Email, Password. Password-strength meter = 4 bars, 4px tall, radius 2, 5px gap; filled bars `accent` (3rd at 0.55 opacity), empty `border`. Terms checkbox = 20×20 radius-6 `accent` square with white check. Primary button "Create account".

### 3. Dashboard
**Purpose:** the "right now" view — what is happening this hour.
- **App bar:** 42×42 hamburger button (radius 13, `surface` + `border`) · centered date overline `SUN · 31 AUG 2026` (11px w600 `text3`, uppercase) · 42px circular avatar with `accent → accentInk` 135° gradient, white initials, 2px `surface` ring.
- **Greeting:** "Good morning, / Hitesh." 30px Newsreader w500. Sub: 14px `text2`.
- **"Now" gym card** (hero, radius 24, padding 20): 150° gradient `accentInk → accent`, white text, two decorative translucent circles (150px top-right, 110px bottom-right at 8–10% white). Contents: pulsing live dot (8px white with 4px `rgba(255,255,255,.25)` ring) + `NOW · 7:00–8:00 AM` overline; "Push Day" overline + "Chest & Triceps" 26px Newsreader; "Up next / Incline Dumbbell Press · 4×10"; 46px white circular play FAB with `accentInk` triangle; progress row ("Exercise 2 of 6" / "32% complete") over a 6px white-28% track with white fill.
- **Today's to-dos:** section head 19px Newsreader w600 + "1 of 3 done" counter. Rows: `surface`, radius 16, padding 14/15, 23×23 checkbox (radius 8, 2px border; when checked → `accent` fill + white check), title 14.5px w600 (strikethrough when done), time 12px `text3`, trailing 7px category dot. **Tapping a row toggles it** (selection haptic).
- **Habits to keep:** 2-column grid, radius 18. Each: 48px circular progress ring (r=20, 5px stroke, `border` track, `accent` progress, round cap, rotated −90°) with `%` or `✓` centered (12px w800); name 14px w700; sub 11.5px `text3`. **Tapping increments** the habit, wrapping to 0 when complete (light haptic).
- **Coming up:** three rows (radius 16, `surface`): 40px radius-12 icon well at 15% of the row color, title 14px w700, sub 12px `text3`, trailing bold relative time in the row color.
  - Team standup · Calendar · 10:30 AM · Zoom → `in 1h` (`#4B7BA6`)
  - Car insurance renewal · Scheduled expense · ₹18,400 → `in 3d` (`#C99320`)
  - SIP auto-debit · Investment · Index Fund · ₹15,000 → `in 5d` (`accentInk`)

### 4. Finance (Expenses)
- **App bar:** hamburger · "Finance" 19px Newsreader w600 · filter button (radius 13).
- **Headline:** overline `NET SAVED · AUGUST`; `₹47,600` 42px Newsreader w500 tabular; trailing up-arrow + `26%` in `accentInk` 13px w800.
- **Three stat pills** (equal grid, radius 16, `surface`): 26px radius-8 icon well, 11px `text3` label, 15px w800 value.
  - Income `₹1,85,000` (accent well, down-into-account arrow)
  - Outgoing `₹92,400` (`#C2703D`)
  - Invested `₹45,000` (`#7C6BC4`)
- **Segmented tabs:** Overview / Income / Spending. 5px-padded `surface2` track, radius 14; selected pill `surface` + shadow, 13px w700.
- **"Where it went" donut** (card radius 22): SVG-equivalent ring, r=52, stroke-width 15, rotated −90°, one arc per category sized by share, `border` as the base track; center shows `SPENT` overline + total. Legend right: top 5 categories, 9px radius-3 swatch, name 12.5px w600 `text2`, share % 12.5px w800.
  Data: Rent 32,000 · Food 14,200 · Misc 14,000 · Shopping 9,500 · Bills 7,900 · Transport 6,800 · Health 4,800 · OTT 3,200 (total 92,400).
- **"Monthly spending" bars** (card radius 22, 6 months, 130px tall): bars max-width 26px, radius `8 8 4 4`, height proportional to the max month; the **max month is `accent`**, others `border`-toned. Value label above (`₹96k`, 10px w800), month label below (11px w700 `text3`).
  Data: Mar 78k · Apr 84k · May 71k · Jun 96k · Jul 88k · Aug 92.4k.
- **Accounts** (horizontal scroll, 158px cards, radius 20): 30px initial well + type overline (`BANK`/`CREDIT`/`INVEST`/`CASH`), name 13px w700, balance 17px w800 (negative balances render `#C2703D` with a `−` sign), sub caption. `+ Add account` link opens the Account sheet.
  Data: HDFC Bank ₹2,48,900 (Salary account) · ICICI Credit −₹12,340 (Due 18 Sep) · Zerodha ₹6,84,200 (XIRR 14.2%) · Cash ₹4,500 (Wallet).
- **Recurring & scheduled:** heading + `+ New` link + helper line "Added to your ledger automatically on each due date." Rows carry a tag pill (`SIP` in accentSoft/accentInk, `AUTO` in surface2/text3), sub line "account · cadence · day", right-aligned amount 14px w800 + next-run date.
  Data: Index Fund SIP ₹15,000 monthly 3rd → 3 Oct · Car insurance ₹18,400 yearly → 12 Sep · Netflix + Spotify ₹1,148 monthly → 18 Sep · Rent ₹32,000 monthly 1st → 1 Oct · Gold ETF SIP ₹2,500 weekly Mon → 14 Sep.
- **Transactions:** hairline-divided list (`border2` bottom), 42px radius-13 initial avatar at 15% category alpha, name 14.5px w700, sub "Category · date", amount 14.5px w800 with `+ ₹` (accentInk) or `− ₹` (`text`).

### 5. Navigation
- **Bottom nav:** floating bar inset 14px from each side and the bottom, 66px tall, radius 24, `raised` bg, 1px `border`, shadow `0 12px 30px -12px rgba(0,0,0,.35)`. Five slots: Home · Finance · **center FAB** · Planner · Calendar. Icons 23px, labels 10px w700; active = `accent`, inactive = `text3`.
- **Center FAB:** 50px, radius 17, `accent`, white plus, accent glow shadow. The plus **rotates to 135° over 300ms** (`cubic-bezier(.2,.8,.2,1)`) while any sheet is open.
- **Sidebar drawer:** 290px wide, `bg`, 1px right `border`, slides in from the left over a `rgba(0,0,0,.45)` scrim. Header: 44px gradient avatar + name (17px Newsreader w600) + email (12px `text3`). Items: 13/14px padding, radius 14, 20px outline icon + 14.5px w700 label; active item = `accentSoft` bg + `accentInk` text; optional count badge (11px w800 pill in accentSoft). Items: Home, Finance, Habits (4), Calendar & Notes, Investments, Gym Planner, To-dos & Reminders (2), Settings. Footer row toggles **Dark/Light mode** with a 42×24 accent switch.
- **iOS vs Android chrome:** iOS = 112×32 pill notch + 132×5 home indicator at the bottom (28% `text`). Android = 9px punch-hole camera, no home indicator. Status bar is 52px, 9:41, with signal/wifi/battery glyphs in `text`.

### 6. Add flow — menu sheet
Opens from the FAB. Bottom sheet, `bg`, top radius 30, 40×4 grab handle, title "What are we adding?" (23px Newsreader w600). **2-column grid of six tiles** (radius 19, `surface` + `border`, padding 15): 38px radius-12 icon well at 15% of the tile color, label 14px w700, sub 11.5px `text3`.

| Tile | Sub | Color | Opens |
|---|---|---|---|
| Expense | One-off spend | `#C2703D` | expense form |
| Income | Salary, refunds | `#0E9F6E` | income form |
| Investment | One-time or SIP | `#7C6BC4` | investment form |
| Recurring expense | Auto-adds monthly | `#D9A441` | recurring form |
| Recurring SIP | Auto-invest on schedule | `#3FA6A0` | investment form, SIP mode |
| Account | Bank, card, cash | `#4B7BA6` | account form |

Tiles **stagger in** at 40ms intervals (`stagger`: opacity 0→1 + translateY 14→0, 340ms). Full-width "Cancel" button below.

### 7. Add flow — entry form sheet
Near-full-height sheet (top inset 52px), top radius 30, three regions:

**Header (fixed):** grab handle · 38px colored icon well · title (19px Newsreader w600) + sub (12px `text3`) · 34px close button.

**Scroll body:**
1. **Amount display** — centered: overline label (varies per type: `AMOUNT SPENT`, `AMOUNT RECEIVED`, `PER INSTALMENT`, `AMOUNT TO INVEST`, `AMOUNT PER CYCLE`, `OPENING BALANCE`), then `₹` (30px Newsreader `text3`) + value (46px Newsreader w500, tabular, `text3` when empty/`0`) + a 2px `accent` blinking caret. Value is grouped Indian-style live as digits are entered; 8-digit cap; one decimal point.
2. **Account name field** (account type only) — 50px input, radius 15.
3. **Primary chip group** — wrapping chips, 38px tall, radius 12, 8px gap; each has an 8px category swatch + 13px w700 label. Selected = `accentSoft` bg, `accent` border, `accentInk` text.
   - Expense: Food & Dining, Transport, Shopping, Bills, Health, OTT, Rent
   - Income: Salary, Freelance, Dividend, Refund
   - Investment: Index Fund, Stocks, Gold ETF, PPF, Crypto, FD
   - Recurring: Rent, Insurance, OTT / Subs, EMI, Utilities, School fees
   - Account: Bank, Credit card, Cash, Wallet, Broker
4. **Type segmented control** (investment only): `Recurring SIP` / `One-time`. Choosing SIP switches the amount label to `PER INSTALMENT`, turns the recurring block on, and changes the CTA to "Schedule SIP".
5. **Account picker** — horizontal chips, radius 14, label 13px w700 + balance 11px `text3`. Label varies: "Paid from" / "Credited to" / "Auto-debit from" / "Charged to".
6. **Recurring block** — card (radius 18) with a 34px accent well, title/sub, and a 46×27 switch (knob 21px, 220ms `cubic-bezier(.2,.8,.2,1)`). When ON, reveals (rise 260ms): **Frequency** chips `Weekly / Monthly / Quarterly / Yearly` (selected = solid `accent`, white text) and an "Auto-adds next on" row in `surface2` showing the computed next date (`Mon, 14 Sep` / `9 Oct 2026` / `9 Dec 2026` / `9 Sep 2027`).
7. **Meta rows** — date row ("Today · 9 Sep 2026", chevron) and optional note input.

**Keypad tray (fixed):** `surface2` bg with a `border2` top edge. 3×4 grid of 46px keys (radius 13, `surface`, Newsreader 21px): `1–9`, `.`, `0`, backspace glyph. Below: 54px primary CTA, radius 16, `accent`, trailing check icon. CTA is **60% opacity + `text3` bg while the amount is empty**; tapping it then fires a **heavy** (error) haptic and does not submit.

**CTA labels:** Save expense · Save income · Save investment / Schedule SIP · Create recurring · Create account.

### 8. Success confirmation
Full-screen `rgba(0,0,0,.55)` + 4px blur. 250px card (radius 26, `bg`, `border`), `popIn` 420ms (`scale .82 → 1.06 → 1`). 72px accent circle with a white check whose path **draws over 400ms** (`stroke-dasharray: 36`, offset 36→0, 120ms delay), plus an expanding accent ring (`ringPulse`: scale .6→2.4, opacity .5→0, 900ms). Title 21px Newsreader w600, sub 13px `text2`. Auto-dismisses after **1.9s**.

Copy (dynamic): "SIP scheduled — ₹15,000 auto-invests monthly from Zerodha." · "Recurring set up — ₹1,148 will auto-add monthly — no reminders needed." · "Expense saved — ₹420 logged to HDFC Bank." · "Account created — HDFC Salary opened with ₹2,48,900."

---

## Interactions & Behavior

### Motion spec
| Element | Animation | Duration / curve |
|---|---|---|
| Screen enter | opacity 0→1, translateY 10→0 | 320ms `cubic-bezier(.2,.7,.3,1)` |
| Sheet open | translateY 102% → −1.2% → 0 (overshoot) | 420ms `cubic-bezier(.2,.86,.3,1)` |
| Sheet close | translateY 0 → 104% | 190ms `cubic-bezier(.4,0,1,1)` |
| Scrim | fade in / out | 220ms / 190ms |
| Drawer | translateX −100% → 0 | 300ms `cubic-bezier(.2,.8,.2,1)` |
| Any tap target | scale → 0.94 while pressed | 130ms `cubic-bezier(.2,.7,.3,1)` |
| FAB plus | rotate 0 → 135° | 300ms `cubic-bezier(.2,.8,.2,1)` |
| Menu tiles | staggered rise | 340ms, 40ms apart |
| Recurring reveal | rise | 260ms |
| Switch knob | left 3px ↔ 22px | 220ms |
| Success card | popIn + ring pulse + check draw | 420 / 900 / 400ms |
| Theme change | background/color cross-fade | 400ms |

In Flutter: use `AnimatedContainer`/`AnimatedSwitcher` for state changes, `showModalBottomSheet(isScrollControlled: true)` with a custom `transitionAnimationController` (or `flutter_animate`) for the overshoot, `AnimatedScale` (or `ScaleTransition` driven by a `GestureDetector` on tap-down/up) for the 0.94 press, `AnimatedRotation` for the FAB, `CustomPaint` + `Tween` for the check-draw and progress rings, and `TweenAnimationBuilder` for the staggered tiles.

### Haptics map
The prototype names each haptic; wire these to Flutter's `HapticFeedback`:

| Prototype label | Flutter call | Fires on |
|---|---|---|
| Selection click | `HapticFeedback.selectionClick()` | keypad key, chip/category/account/frequency select, segmented switch, to-do toggle |
| Light impact | `HapticFeedback.lightImpact()` | opening a form from a tile or link, closing a sheet, habit increment |
| Medium impact | `HapticFeedback.mediumImpact()` | FAB tap (open add menu), recurring switch toggle |
| Heavy impact | `HapticFeedback.heavyImpact()` | invalid submit (empty amount) |
| Success | `HapticFeedback.vibrate()` or `Haptics.vibrate(HapticsType.success)` | successful save |

Use the `haptic_feedback` or `gaptic`/`flutter_vibrate` package if you want richer iOS notification-style patterns; otherwise `HapticFeedback` + `Feedback.forTap` covers everything above. Respect a user setting `settings.haptics_enabled` — gate every call behind it.

### Gestures
- **Swipe-down to dismiss** on both sheets (`DraggableScrollableSheet` / drag handle) — the grab handle is the affordance.
- **Swipe from the left edge** opens the drawer (`Scaffold.drawer` gives this free); tapping the scrim closes it.
- **Horizontal drag** on the Accounts row and the account-picker chips (already horizontal scrollers).
- **Swipe a transaction row** left → Delete, right → Edit (`Dismissible` / `flutter_slidable`). Not shown in the mock; implement with `#C2703D` destructive and `accent` edit backgrounds.
- **Pull-to-refresh** on Dashboard and Finance (`RefreshIndicator`, `color: accent`).
- **Long-press** a habit ring → open habit detail. Long-press a recurring row → pause/skip next run.
- **Tap the to-do checkbox or row** → toggle. Tap a habit card → increment, wrapping at goal.

### Validation
- Amount required and `> 0`; max 8 integer digits; a single decimal point, max 2 decimals.
- Category required for expense/income/investment/recurring; account name required (non-empty, ≤ 40 chars) for accounts.
- Frequency required when the recurring switch is ON.
- Disabled CTA state = `text3` bg at 60% opacity; on tap → heavy haptic + shake the amount (not in the mock, recommended).

### Responsive
Designed at **392×844** (iPhone 14 logical size). Use `MediaQuery` + `SafeArea`; the bottom-nav inset (14px) and its 108px scroll padding must respect the device's bottom inset. Keep the keypad tray pinned above the keyboard inset. Type scales via `MediaQuery.textScalerOf` — cap at ~1.3 so the 46px money figure and 66px nav don't break.

---

## State Management

Recommended: **Riverpod** (`flutter_riverpod`) + `freezed` models, or Bloc if the team prefers it.

Providers / state:
- `authProvider` — `Supabase.auth` session stream; drives Login/Signup → Dashboard routing.
- `themeProvider` — `light | dark | system`, persisted (`shared_preferences`).
- `platformChrome` — derived from `Theme.of(context).platform` (the prototype's iOS/Android toggle is a review affordance only; ship the real platform).
- `dashboardProvider` — today's aggregate: current/next workout block, today's to-dos, habit progress, next 3 upcoming items (calendar + scheduled expenses + upcoming SIPs).
- `financeProvider(month)` — income, outgoing, invested, net saved, category breakdown, 6-month trend.
- `accountsProvider`, `transactionsProvider(filter)`, `recurringProvider`, `holdingsProvider`.
- `addEntryController` — the sheet's form state: `type`, `amount` (string buffer), `categoryId`, `accountId`, `mode (sip|once)`, `isRecurring`, `frequency`, `note`, `date`, `nextRunDate` (computed), `status (idle|saving|success|error)`.
- `habitsProvider`, `todosProvider` — optimistic local toggle, then Supabase write, rollback on failure.

All list/aggregate providers subscribe to Supabase **Realtime** so a write from any device updates the dashboard live.

---

## Supabase — Schema

Full DDL in `supabase_schema.sql` (in this bundle). Summary:

- `profiles` — 1:1 with `auth.users`; name, avatar, currency (`INR`), timezone (`Asia/Kolkata`), locale, haptics/theme prefs.
- `accounts` — name, type (`bank|credit|cash|wallet|broker`), opening balance, current balance, color, is_archived.
- `categories` — name, kind (`expense|income|investment`), color hex, icon key, is_system.
- `transactions` — account, category, `kind (expense|income|investment|transfer)`, amount (numeric 14,2), occurred_at, note, `recurring_rule_id` (set when auto-generated), `investment_id`.
- `recurring_rules` — the engine for "auto add every month/schedule": kind, amount, account, category, `frequency (weekly|monthly|quarterly|yearly)`, `interval`, `day_of_month` / `weekday`, `starts_on`, `ends_on`, `next_run_on`, `last_run_on`, `auto_post` (bool), `is_paused`. Powers both **recurring expenses** (insurance, OTT, rent, EMI) and **recurring investments (SIP)**.
- `investments` — instrument name, type (`index_fund|stock|gold_etf|ppf|fd|crypto`), broker account, units, avg cost, current value, XIRR.
- `habits` + `habit_logs` — goal, unit, cadence, per-day value.
- `todos` — title, due_at, remind_at, priority, done_at.
- `calendar_events` — title, start/end, location, source.
- `workout_plans`, `workout_days`, `exercises`, `workout_logs` — weekly gym plan; the dashboard's "Now" card reads the block whose time window contains `now()`.
- `diet_plans`, `meals` — weekly diet plan.
- `notes` — title, body, tags.

**Security:** RLS ON for every table with `user_id = auth.uid()` for select/insert/update/delete. `profiles` keyed on `id = auth.uid()`.

**Recurring engine:** a `post_due_recurring()` SQL function inserts a `transactions` row for every rule where `next_run_on <= current_date AND NOT is_paused AND auto_post`, then advances `next_run_on`. Schedule it daily with **pg_cron** (`select cron.schedule('post-recurring','5 0 * * *', $$select post_due_recurring()$$)`), or from an Edge Function on a scheduled trigger. Balance updates ride an `AFTER INSERT/UPDATE/DELETE` trigger on `transactions`.

**Auth:** email/password + Google and Apple OAuth (both shown on Login). Use `supabase_flutter`'s `signInWithOAuth` with deep-link redirect; Apple Sign-In is mandatory for App Store review since Google is offered.

---

## Suggested Flutter structure

```
lib/
  main.dart                     # Supabase.initialize, ProviderScope
  app/
    theme.dart                  # LifeOSColors (light/dark), text theme (Newsreader + Manrope)
    router.dart                 # go_router: /login /signup /dashboard /finance ...
    haptics.dart                # LifeHaptics.selection/light/medium/heavy/success (setting-gated)
    motion.dart                 # durations + curves from the motion table
  data/
    supabase/                   # typed clients per table
    models/                     # freezed models
    repositories/
  features/
    auth/         login_page.dart  signup_page.dart  widgets/
    dashboard/    dashboard_page.dart  widgets/now_workout_card.dart  todo_row.dart  habit_ring.dart  upcoming_row.dart
    finance/      finance_page.dart  widgets/category_donut.dart  monthly_bars.dart  account_card.dart  recurring_row.dart  txn_row.dart
    add_entry/    add_menu_sheet.dart  entry_form_sheet.dart  widgets/amount_display.dart  money_keypad.dart  chip_group.dart  recurring_block.dart  success_overlay.dart
  shared/
    widgets/      tappable.dart (0.94 press scale + haptic)  app_scaffold.dart  bottom_nav.dart  app_drawer.dart  section_header.dart
    format/       inr.dart (2-2-3 lakh grouping)  dates.dart
```

### Packages
`supabase_flutter` · `flutter_riverpod` · `freezed` + `json_serializable` · `go_router` · `google_fonts` · `fl_chart` (donut + bars — the prototype's ring/bar geometry maps to `PieChart(centerSpaceRadius, sectionsSpace: 0)` and `BarChart` with `BorderRadius.vertical`) · `flutter_animate` (staggers, overshoot) · `flutter_slidable` (swipe actions) · `shared_preferences` · `intl` · `flutter_local_notifications` (to-do reminders, recurring due alerts) · `sign_in_with_apple`, `google_sign_in`.

**Charts note:** the donut is drawn without gaps and with a full-circle track behind it; `fl_chart`'s `PieChart` needs `sectionsSpace: 0` and a `Stack`ed background circle to match. If `fl_chart` fights the design, a `CustomPainter` reproduces both charts exactly and is ~60 lines.

---

## Assets
No raster assets. All iconography is 1.9–2.4px stroke-weight outline icons on a 24px grid — use `lucide_icons` (closest match to the prototype's set) or hand-rolled `CustomPaint`/SVG via `flutter_svg`. Fonts (`Newsreader`, `Manrope`) come from Google Fonts. Brand marks: Google's official multicolor "G" and the Apple logo, per each provider's brand guidelines. The user avatar is a gradient initials fallback — no image required.

## What is NOT in this slice
Planner (exercise + diet detail), Calendar & Notes, Investments detail, and the To-dos/Reminders screen are stubbed in the drawer and bottom nav but not designed yet. Build navigation destinations for them now; the screens follow.

## Designed since this README was written
The prototype has grown past the slice documented above. These are in `LifeOS.dc.html` and specified only there — read the file for exact values:

- **Health — medication scheduling.** Today/Schedule toggle on the Health screen. Schedule view lists medicines with repeat rules and timing chips. The edit sheet sets name, dose, repeat (Every day / Weekly / Alternate days / As needed), a weekday picker, multi-select dose timings, a reminder toggle, and a live English summary of the rule. Today's dose rows carry frequency pills. The add flow reuses the same sheet. Maps onto `recurring_rules`-style fields on a `medications` table: `freq`, `days[]`, `times[]`, `remind`.
- **Learn.** New nav item, sidebar entry and jump-rail entry. Review-queue hero with a due count, a notebooks rail with progress indicators, Recent/Due/Starred filters, note cards, and a full reader with body/quote/code blocks, a recall prompt, a star action, and Mark reviewed (which clears the note from the queue). Spaced-review scheduling: `notes.next_review_on` advances on review.

## Token note — semantic colours changed
The semantic status colours in the token tables above (`#A62F2F`, `#C99320`/`#8A6410`, `#C2703D`/`#8C4C22`) are **light-theme values only**. They have since been split into per-theme pairs — `danger` / `warn` / `warm` / `cool` / `deep`, each with a dark counterpart plus `-soft` and `-bd` variants. **Use the table in `BRAND_AND_UI_KIT.md` §2, not the one above**, for anything that carries text in dark mode.

## Files
- `BRAND_AND_UI_KIT.md` — **start here.** App icon spec, full token set, icon family, component inventory with Flutter mappings, motion/haptics/a11y floor.
- `LifeOS UI Kit.dc.html` — the live UI kit. Light/dark toggle in the header; every control is interactive.
- `LifeOS.dc.html` — the interactive prototype (all screens, both themes, both platform chromes, the full add flow, medication scheduling, Learn, haptic labels and animations).
- `supabase_schema.sql` — Postgres DDL, RLS policies, balance trigger, and the recurring-posting function + cron schedule.
- `brand/` — app icons (1024/512/192, full-bleed 180 for iOS and 512 for Play), Paper and Ink variants, favicons (64/32/16 + `.ico`), and `icon-gen.js` to re-render any size.
- `support.js` — the runtime the two `.dc.html` files load. Keep it in the same folder as them.

Both `.dc.html` files open directly in a browser — no build step, no server.
