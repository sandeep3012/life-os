# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

LifeOS — a Flutter daily-life-management app (finance & spend analysis, habits,
tasks, notes, documents, calendar, goals, rule-based AI insights). Local-only
SQLite storage, no accounts/backend, mobile-first (Android/iOS) with desktop
targets scaffolded for development convenience. All 9 planned build phases are
complete; work is now bug-fix/iteration, not net-new module scaffolding.

## Critical: Windows environment setup

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
17+ that isn't the machine's default.** `JAVA_HOME` on this machine points at
a Java 8 JDK (`jdk1.8.0_231`), which AGP/Gradle 8.14 can't build with (needs
11+) — `android/gradle.properties` pins `org.gradle.java.home` to a JDK 17
install instead of relying on the system-wide `JAVA_HOME`. If that path
(`C:/Program Files/Eclipse Adoptium/jdk-17.0.19.10-hotspot`) doesn't exist on
a given machine, find another JDK 17+ install and update the property.

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
so the shipped UI matches the validated prototype design exactly. Fonts:
Fraunces (headings/hero numbers), Figtree (body/UI), PlexMono (currency/
tabular figures via `AppMonoText.style()`) — bundled as local assets in
`assets/fonts/`, not `google_fonts`, to stay fully offline.

**Design source of truth was an HTML prototype**, built and color-validated
(WCAG/CVD-safe categorical palette) before any Flutter UI, then ported
1:1 into `AppColors`/`AppTheme`. If a screen's visual design is ambiguous,
the prototype (not intuition) is the tiebreaker.

## Testing patterns specific to this codebase

- **Riverpod 3.x**: `StateProvider` was moved to a legacy import in this
  version — use `Notifier`/`NotifierProvider` instead. `AsyncValue.valueOrNull`
  doesn't exist; use the now-nullable `.value` instead.
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

## Known gaps (not yet done)

- Release signing (`android/key.properties` / keystore) is deliberately not
  set up yet.
- Data export/backup is unimplemented (mentioned as "Soon" in Settings UI).
- No CI configured.
