# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

LifeOS — a Flutter daily-life-management app (finance & spend analysis, habits,
tasks, notes, documents, calendar, goals, rule-based AI insights). Local-only
SQLite storage, no accounts/backend, mobile-first (Android/iOS) with desktop
targets scaffolded for development convenience. All 9 planned build phases are
complete; work is now bug-fix/iteration, not net-new module scaffolding.

## Critical: local environment setup

This project is developed from both a Windows machine and a macOS machine;
the Windows-only notes below apply only there, the JDK note applies to both.

**On Windows, `flutter`/`dart` MUST be invoked through `C:\flutter-sdk`, not
`C:\Program Files\flutter`.** The real SDK lives under Program Files; a
directory junction at `C:\flutter-sdk` (no admin rights needed) points to it.
Any dependency using Dart's native-asset build hooks (currently: `sqlite3`,
`path_provider`'s `objective_c`/`jni`) fails with `'C:\Program' is not
recognized...` when invoked via the real path, because the hook runner
doesn't quote paths containing spaces. This affects `flutter test` and
`flutter run`; `flutter analyze`/`pub get` are unaffected. Prepend to PATH for
every command:

```bash
export PATH="/c/flutter-sdk/bin:$PATH"   # Git Bash
```

If `C:\flutter-sdk` doesn't exist on a given machine, recreate it:

```powershell
New-Item -ItemType Junction -Path "C:\flutter-sdk" -Target "C:\Program Files\flutter"
```

**Android builds (`flutter build apk`, `flutter run` on Android) need a JDK
in the 17–21 range, which is usually *not* the machine's default.** Gradle
8.14 + AGP 8.11 reject both ends: Java 8/11 is too old for AGP, and Java 22+
is unsupported by Gradle 8.14 (`The Java version used for the build is 25.x,
which is incompatible with Gradle 8.14`).

Select the JDK **per machine, out of the repo** — never by pinning
`org.gradle.java.home` in `android/gradle.properties`. That property takes an
absolute path, so committing it hard-fails every other machine with `Value
'...' given for org.gradle.java.home Gradle property is invalid (Java home
supplied is invalid)`. It was committed twice (a Windows Adoptium path, then a
macOS Homebrew path) and broke the other platform both times. Use instead:

```bash
flutter config --jdk-dir="<path to a JDK 17-21>"   # stored in ~/.flutter_settings
```

**Setting `--jdk-dir` is required even when every JDK on the machine is
already a good one.** Flutter's resolution order is `--jdk-dir` → **Android
Studio's bundled JBR** → `JAVA_HOME` → `java` on `PATH`, and the JBR wins
over the last two. On the macOS machine that JBR is **Java 25**, so builds
failed with `incompatible with Gradle 8.14` despite `JAVA_HOME` being empty
and `PATH`'s `java` being Zulu 17. Do not assume the JBR is a safe default —
check it before pointing anything at it:

```bash
"/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java" -version
```

The macOS machine's working value is the Zulu 17 install:

```bash
flutter config --jdk-dir="/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home"
```

This is the agreed lever. Do **not** "fix" it by putting `org.gradle.java.home`
in `~/.gradle/gradle.properties` either — that applies to every Gradle project
on the machine, Flutter or not, which is a far wider blast radius than
`--jdk-dir` (Flutter Android builds only, where JDK 17 is safe because both
Gradle 8.x and 9.x support it).

To find candidates on another Mac (`java_home` lists only JDKs registered
under `/Library/Java/JavaVirtualMachines`, which excludes the Studio JBR and
excludes `brew install openjdk@NN`):

```bash
/usr/libexec/java_home -V                 # all registered JDKs, with versions
ls -d /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home   # Apple Silicon
ls -d /usr/local/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home      # Intel
```

If nothing in 17–21 exists: `brew install --cask temurin@21` (casks register
with `/usr/libexec/java_home`; plain `brew install openjdk@21` does not).
Homebrew's prefix is `/opt/homebrew` on Apple Silicon and `/usr/local` on
Intel — a path copied from the wrong one produces the "Java home supplied is
invalid" error above. On Windows, point `--jdk-dir` at a JDK 17 install such
as `C:/Program Files/Eclipse Adoptium/jdk-17.0.19.10-hotspot`.

Verify with `flutter doctor -v`, which prints the resolved Java binary and
version under the Android toolchain entry. Note that a *stale* `--jdk-dir`
fails silently-ish: Flutter falls back down the chain, so the reported
version won't match what you set.

**Android builds can intermittently fail with `Unable to establish loopback
connection` or `The first result from the daemon was empty`.** This is
Gradle's daemon (or Gradle's "single-use daemon" fallback, which forks a
child JVM the same way) failing to open its own IPC socket back to itself —
not a project bug. It's most likely local antivirus/firewall/EDR software
intercepting a newly-spawned JVM process's socket. `org.gradle.daemon=false`
is set to reduce how often this is hit, but doesn't fully avoid it (Gradle
still forks a "single-use daemon" for the same reason). If it persists: add
an AV/firewall exclusion for `java.exe` and the project/`.gradle` folders, or
just retry — it's been observed to succeed on a subsequent attempt without
any config change.

**Uncommitted working-tree changes on this machine have been silently
discarded mid-session before** (a Gradle-config fix and a notification-
timezone fix both vanished between turns, with `git status` clean afterward
— i.e. reverted to the last commit, not just unstaged). Cause unconfirmed.
Commit fixes promptly rather than leaving them uncommitted for long stretches
while iterating on something unrelated (e.g. build troubleshooting).

## Commands

```bash
flutter pub get                          # install dependencies
flutter analyze                          # static analysis — must be clean
flutter test                             # full test suite
flutter test test/features/foo_test.dart # single test file
flutter test --plain-name "test name"    # single test by name (any file)
dart run build_runner build --delete-conflicting-outputs   # regenerate Drift code after schema changes
dart run flutter_launcher_icons          # regenerate app icons from assets/icon/
dart run flutter_native_splash:create    # regenerate splash screens from assets/icon/
```

Always run `flutter analyze` and `flutter test` after changes, before
reporting work as done.

## Architecture

**Feature-first layout.** Each module lives under `lib/features/<name>/` with
up to four layers: `data/` (Drift repository, DB-only), `domain/` (plain Dart
model classes with derived/computed fields), `application/` (Riverpod
providers + a `*Controller` class that orchestrates repository calls plus any
side effects like notifications), `presentation/` (screens + widgets). Cross-
cutting modules (`home`, `ai_analyser`) import other features' `application/`
providers directly — this is intentional, not a layering violation; it's why
everything shares one Riverpod `ProviderContainer` and one Drift database
instead of per-feature stores.

**Single Drift database, one source of truth.** `lib/core/database/app_database.dart`
defines every table (tables live individually under `lib/core/database/tables/`).
Money is stored as integer minor units (paise), never floats. UUID primary
keys throughout. Notably:
- `Events` is a *polymorphic* view over tasks/habits/goals (`sourceType`/`sourceId`)
  plus standalone entries — the Calendar screen merges tasks-due-today,
  completed `HabitLogs`, and `Events` rows at the application layer
  (`calendar_providers.dart`); it never duplicates task/habit data into `Events`.
- `Folders` is shared by Notes and Documents, distinguished by a `scope` column.
- `GoalLinks` is a generic many-to-many join (goal → habit/account/task) rather
  than typed foreign key columns on `Goals`.
- Habit streaks and week-completion are *derived* from `HabitLogs` at query
  time (`habits_providers.dart`), never stored — same pattern for budget
  spend-vs-actual (derived from `Transactions`, not cached on `Budgets`).

**AI Analyser is a pure rule engine.** `features/ai_analyser/domain/analytics_rule_engine.dart`
exports `computeInsights(...)`, a pure function (no DB/Riverpod access) that
takes already-fetched domain data and returns insight drafts. This is the
seam for ever swapping in an LLM-backed engine later — everything downstream
(`InsightsRepository.reconcile`) only cares about the draft list, matching
drafts against persisted `Insights` rows by a `type:relatedEntityId` dedupe
key so a dismissed-but-still-true insight doesn't reappear on refresh.

**Theme is data, not hardcoded widget colors.** `lib/app/theme/app_colors.dart`
defines `AppColors extends ThemeExtension<AppColors>` with separate `light`
and `dark` const instances (module accent colors, status colors, spend-
category colors) — read via `context.appColors` (extension on `BuildContext`).
`lib/app/theme/app_theme.dart` builds `ColorScheme.fromSeed` then overrides
specific slots with exact neutrals rather than trusting the seed algorithm,
so the shipped UI matches the design comp exactly. Fonts: **Newsreader**
(headings, hero numbers, *and* card/section titles) and **Manrope** (body, UI,
plus currency/tabular figures via `AppMonoText.style()`) — bundled as local
variable-font assets in `assets/fonts/`, not `google_fonts`, to stay fully
offline. Reference families through `AppFonts` (`lib/app/theme/app_fonts.dart`),
never as string literals: 19 widget-level `fontFamily: 'Fraunces'` /
`'PlexMono'` literals survived the previous design and would have silently
fallen back to the system font once those families left `pubspec.yaml`, since a
missing family is not an analyzer or runtime error in Flutter.

Radii come from `AppSpacing`, which carries the comp's own scale (cards 22,
tiles 16, controls 15, icon buttons 13, nav pill 24, sheets 30) rather than one
shared value.

**The design system lives in `ui-kit/`.** `BRAND_AND_UI_KIT.md` is the authority
for tokens, component metrics, motion, haptics and the accessibility floor;
`LifeOS.dc.html` is the authority for how the screens are assembled. Read the kit
first. Its hard rules are enforced by `test/app/design_system_conformance_test.dart`
— semantic inks must differ per theme, category hues must not, every token must
lerp, and the brand assets must exist.

`lib/app/theme/app_colors.dart` is **generated** by `scripts/gen_app_colors.js`
from the kit's §2 token table. Edit the table in the script, re-run it, don't
hand-edit the Dart: 46 tokens × (constructor + light + dark + copyWith + lerp) is
five parallel lists, and an omission there stops a colour animating rather than
failing to compile.

**One place the two files disagree, and how it was resolved.** The kit's §2 type
table says "Manrope for everything"; the prototype sets every heading in
Newsreader (38 occurrences). The screens are what ships, so headings stay
Newsreader and Manrope carries body/UI — the kit's *scale* (sizes, weights,
tracking) is followed. JetBrains Mono is registered and used strictly for code
blocks, per the kit. If you want Manrope-only headings, that's a one-line change
in `AppFonts.serif` — but it restyles every screen.

**Design source of truth for screen assembly is `ui-kit/LifeOS.dc.html`**
(project `f364705c-f902-455f-a879-20af25c40ed9`, read via the `DesignSync`
tool after `/design-login`). If a screen's visual design is ambiguous, the comp
— not intuition — is the tiebreaker. Two things the comp does *not* settle, and
where the code deliberately departs from it:

- **It defines no error/red colour at all** (its only reds are the Google logo
  in its social sign-in buttons). `AppColors.critical` is therefore derived
  from the comp's terracotta rather than taken from it.
- **Its chrome is monochrome** — nav, sidebar and headers use only the accent
  plus text tones. Per-entity colour comes solely from its 8-colour data
  palette, so the nine `modulePalette` accents are drawn from that palette
  instead of being a separate set of hues.

This replaced an earlier, unrelated design (a violet-seeded HTML prototype with
Fraunces/Figtree/PlexMono). Anything still describing that palette is stale.

**Where the comp's screens live.** Every section of `LifeOS.dc.html` that has
data behind it is implemented:

| Comp section | Implementation |
|---|---|
| Login / Signup | `features/auth/` |
| Dashboard | `features/home/.../home_screen.dart` + `now_hero_card`, `todo_row`, `habit_ring_tile`, `upcoming_row` |
| Expenses | `features/finance/.../finance_overview_screen.dart` + `finance_cards.dart` |
| Habits | `features/habits/.../habits_overview_screen.dart` + `habit_consistency_providers.dart` |
| Bottom nav + centre FAB | `app/router/app_shell.dart` |
| Sidebar | `app/router/app_sidebar.dart` |
| Add menu sheet | `features/home/.../add_menu_sheet.dart` |
| Entry form + keypad | `features/finance/.../entry_form_sheet.dart` |
| Success | `core/widgets/success_overlay.dart` |
| Health (medication + gym) | `features/health/.../health_screen.dart` + `medication_editor_sheet.dart` |
| Learn | `features/learn/.../learn_screen.dart` + `note_editor_sheet.dart` |
| Note reader | `features/learn/.../note_reader_screen.dart` |
| Gym plan + set logging | `features/health/.../workout_plan_sheet.dart`, `add_exercise_sheet.dart`, `log_set_sheet.dart` |

Every screen reachable from the drawer sets `drawer: const AppSidebar()` on its
own Scaffold and opens it with `AppTopBar(onMenu:)`; an inner Scaffold shadows
the shell's, so a drawer declared only on the shell is unreachable. Segmented
controls use `AppTabRail`, never Material's `SegmentedButton` — this design's
segments are borderless and transparent, so `SegmentedButton` renders no track
and disappears into the page. Habits, Health and Learn live in the `more` branch
with the other drawer destinations; nesting them under `tasks-habits` made them
render inside the Tasks screen.

Reusable comp primitives are in `core/widgets/`: `Tappable` (the universal 0.94
press), `SurfaceCard`, `SectionHeader`/`Overline`, `ProgressRing`, `DonutChart`,
`InitialWell`, `AppTopBar`. Motion constants are in `app/motion.dart`, haptics in
`app/haptics.dart` — both transcribed from the handoff's tables; don't inline
durations or `HapticFeedback` calls.

Health and Learn are the two modules the redesign added from scratch
(`features/health/`, `features/learn/`), on schema **v15** — seven new tables in
`tables/health_tables.dart` and `tables/learn_tables.dart`. The migration is
purely additive, so an upgrade keeps every existing row. As everywhere else in
this app, the headline numbers are derived, never stored: "doses today" comes
from `MedicationLogs`, workout progress from `WorkoutLogs`, and a notebook's
percentage from how many of its notes have a `lastReviewedAt`.

**Two comp elements intentionally have no Flutter counterpart.** The
`<image-slot>` appears exactly once (line 659, gym exercise photos) and is an
authoring scaffold, not app content. The "haptic indicator" is a prototype debug
pill naming the haptic that just fired; its real counterpart is the device
vibration, which `LifeHaptics` provides.

**Documented departures from the comp** — each because the data or platform
doesn't exist, not by preference:
- The dashboard hero is **schedule-driven, not a gym card**. There is no workout
  module, and adding one needs new Drift tables (`build_runner`).
- Habit rings show **week completion against `targetPerWeek`**; the comp's
  per-day counter ("6 / 8 glasses") has nowhere to be stored.
- The add menu has **4 tiles, not 6** — Investment and Recurring SIP have no
  module behind them.
- The entry sheet omits the comp's **recurring block**: recurring entries are a
  separate table with their own sheet, which the menu's Recurring tile opens.
- Login/Signup are built but **not wired to a backend**. Sync is a paid, opt-in
  feature; free use stays fully local with no account, so nothing routes to them
  on launch — they hang off the sidebar. `features/auth/application/sync_auth_providers.dart`
  is the single seam: it returns `SyncAuthNotConfigured` and the screens surface
  that verbatim. **Do not make it fake a success.** Wiring it needs
  `supabase_flutter`, a project URL + anon key, and deep links on both platforms.
- Social buttons carry **placeholder marks**. Google's multicolour "G" and the
  Apple logo must be their official assets per brand guidelines; a hand-drawn
  approximation would breach those.
- The pre-redesign finance screen is kept at `/finance/ledger` for the budget
  tools the comp has no slot for.

## Testing patterns specific to this codebase

- **Riverpod 3.x**: `StateProvider` was moved to a legacy import in this
  version — use `Notifier`/`NotifierProvider` instead. `AsyncValue.valueOrNull`
  doesn't exist; use the now-nullable `.value` instead.
- **`Ref` and `WidgetRef` are unrelated types in Riverpod 3** — a widget's
  `ref` (from `ConsumerState`/`ConsumerWidget`) is a `WidgetRef`, a provider's
  or controller's is a `Ref`, and neither implements a shared interface. A
  helper written as `Foo.of(Ref ref)` therefore *cannot* be called from a
  widget. Expose shared services as a `Provider<Foo>` instead (see
  `hapticsProvider` in `lib/app/haptics.dart`): `ref.read(someProvider)` is the
  one call that works from both sides.
- **`ref.read(someStreamProvider.future)` hangs if nothing else is watching
  that provider** — Riverpod tears down an unlistened `StreamProvider` before
  its first emission ever arrives. Any code that awaits a stream provider's
  first value outside a widget (see `AiAnalyserController.refresh()`) must
  hold an explicit `ref.listen(...)` subscription for the duration of the
  call. This caused a real cold-start freeze before being caught by tests.
- **Widget tests must dispose cleanly before ending**: Drift schedules a
  zero-duration cleanup timer when a watched query's stream is cancelled,
  which normally happens at `ProviderScope` teardown — *after* the test body
  returns, where `flutter_test` can't pump it away, tripping the "Timer is
  still pending" assertion. Fix: end every widget test with
  `await tester.pumpWidget(const SizedBox()); await tester.pump(const Duration(milliseconds: 1));`
  to force disposal inside the test body. Several test files define a local
  `_disposeCleanly` helper for this.
- **Mocking `path_provider`** (needed for any `FileStorageService`-touching
  test): override `PathProviderPlatform.instance` with a fake subclass
  returning a `Directory.systemTemp.createTemp()` path — don't try to mock
  the method channel directly.
- **In-memory DB for tests**: `AppDatabase.forTesting(NativeDatabase.memory())`,
  injected via `appDatabaseProvider.overrideWithValue(db)` in a `ProviderScope`
  (widget tests) or `ProviderContainer` (pure logic tests).
- **`flutter test`/`flutter run` file-lock errors** (`Flutter failed to
  delete file at ...\sqlite3.dll`) mean another `flutter run`/`flutter test`
  process still holds the native-asset build lock — find and stop it (or kill
  stray `dart.exe`/`flutter_tester.exe`/`dartaotruntime.exe` processes) before
  retrying, don't just re-run blindly.

## Traps found the hard way in the redesign

- **`ButtonStyle.minimumSize` must not use `Size.fromHeight`.** That constructor
  is `Size(double.infinity, h)`, so a themed `minimumSize` demands *infinite
  width* from every button in the app and crashes any that isn't inside a
  width-bounded parent (`BoxConstraints forces an infinite width`). Use
  `Size(64, h)` — Material's default min width — and let full-width CTAs get
  their width from their layout.
- **Never await a haptic before invoking a tap's action.** `Tappable` originally
  did; one throwing platform channel then silently swallowed *every* tap in the
  app. Fire the action first and let the haptic be fire-and-forget;
  `LifeHaptics` also swallows its own errors.
- **`CrossAxisAlignment.stretch` on a `Row` needs a bounded height.** Inside a
  `ListView` or a `mainAxisSize.min` `Column` it asserts `forces an infinite
  height`. Wrap in `IntrinsicHeight` (which also gives grid cells equal heights).
  On a `Column` it's fine — that cross axis is horizontal and bounded.
- **Any widget test that pumps the whole app must stub
  `NotificationService.scheduleDailyHabitReminder`.** The app schedules it on the
  first frame and the real one reads `tz.local`, throwing a
  `LateInitializationError` unless the timezone DB was initialised.
- **A failing `expect` skips the test's teardown**, so the Drift cleanup timer
  stays pending and the suite then hangs for `pumpAndSettle`'s full 10-minute
  timeout. A 10-minute stall in `flutter test` usually means an assertion failed
  earlier in that file, not that something is slow.
- **Icons are Lucide only** (`lucide_icons_flutter`), per kit §3 — no Material or
  Cupertino glyphs anywhere in `lib/` or `test/`. The kit names `lucide_icons`,
  but that package is pinned to Dart <3.0.0 and last shipped in 2023; this is the
  maintained port of the same set. `scripts/` has the mapping used for the
  original sweep if more need converting.
- **Gym weights are integer grams**, the same reasoning as money in paise: 2.5 kg
  plate increments are exact as integers and drift as doubles. `ExerciseSession.kg`
  / `.formatKg` convert for display. A recurring session is one `WorkoutDays` row
  per weekday rather than a recurrence rule, so the daily lookup stays an equality
  check; the plan sheet's multi-select creates them in one go.
- **Category hues never carry text.** Kit §2: the raw hue is for 14–18% alpha
  wells, swatches and dots; when one has to colour *text*, use its semantic ink —
  `warm` for Spend, `info` for Water/Calendar, `deep` for Learn. `text3` is
  decorative only and fails 4.5:1 in both themes; informational captions use
  `onSurfaceVariant`.
- **Reduce-motion is not optional.** Pass every duration through
  `AppMotion.of(context, …)` and every curve through `AppMotion.curveOf`; the kit
  collapses all motion to a 160 ms cross-fade when `disableAnimations` is set.
- **`Tappable.enforceMinTouchTarget` shrink-wraps its child** — opt in on
  sub-44px icon buttons, never on a full-width row (it would collapse the row).
  For `Expanded` children like tab-rail segments, add the height instead.
- **Widget tests must pin the phone viewport or they hide real overflows.** The
  default test surface is 800x600 — wider and shorter than any phone — so
  horizontal overflows simply don't reproduce. `test/features/layout_overflow_test.dart`
  sets 392x844 (the comp's size) and asserts `tester.takeException()` is null;
  that's what caught 95px and 98px overflows on Net worth and Calendar that
  passed at the default size. A bare `Row` cannot shrink below its children's
  intrinsic width — use `Wrap` for title-plus-legend rows.
- **Raw `customStatement` does not invalidate Drift's streams.** A medication's
  stock was updated with raw SQL and `watchMedications()` never re-emitted, so
  the screen kept showing a stale count. Use the typed `update(...).write(...)`
  API for anything a `watch` depends on.
- **Never run `flutter pub get` in this repo with a non-default `PUB_CACHE` or a
  different Flutter SDK.** It rewrites `.dart_tool/package_config.json`,
  `.flutter-plugins-dependencies` and `ios/Flutter/Generated.xcconfig` with
  absolute paths, and the project then fails to resolve `package:flutter` at all
  — surfacing as thousands of bogus "`Color` isn't a type" errors in files you
  never touched. Recovery: delete those (all gitignored) and re-run
  `flutter pub get` normally.

**The suite is green: 126 passing, `flutter analyze` clean.** It was not before
the redesign — five tests failed on `main`, all because assertions had drifted
from the widgets they described (an icon-only `FloatingActionButton`'s label
lives in its `tooltip`, not in a `Text`; a habit log row renders
`"Done · <note>"` as one string, so `find.text(note)` can never match). When a
finder fails, check what the widget actually renders before assuming the code
regressed — `tester.widgetList<Text>(find.byType(Text)).map((w) => w.data)`
dumps it.

**Before assuming a failure is yours, baseline it:**
`git worktree add --detach <dir> HEAD` gives a clean checkout to run the same
test against, without touching your working tree.

## Known gaps (not yet done)

- Release signing (`android/key.properties` / keystore) is deliberately not
  set up yet.
- Data export/backup is unimplemented (mentioned as "Soon" in Settings UI).
- No CI configured.
