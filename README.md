# LifeOS

An all-in-one daily life manager built with Flutter: finance & spend analysis,
habits, tasks, notes, documents, calendar, goals, and rule-based AI insights —
all local-only, no accounts required.

## Modules

- **Home** — cross-module dashboard (spend, tasks, habit streaks, goals, upcoming)
- **Finance & Spend Analyzer** — accounts, transactions, budgets, category breakdowns
- **Tasks & Habits** — due-date tasks with reminders, streak-tracked habits
- **Notes & Documents** — folders, search, on-device file import/capture
- **Calendar** — unified view merging tasks, habits, and standalone events
- **Goals** — progress tracking linked to habits/accounts/tasks
- **AI Analyser** — rule-based insights (overspend, at-risk streaks, goal pacing, task momentum)
- **Settings** — theme, notification preferences

## Stack

Flutter + Riverpod (state) + Drift/SQLite (local relational DB) + go_router
(navigation) + fl_chart (charts) + flutter_local_notifications.

## Getting started

```bash
flutter pub get
flutter run
```

### Windows-specific note

If `flutter test`/`flutter run` fails with a `'C:\Program' is not recognized`
error, it's a known Dart native-asset-hooks bug triggered by the Flutter SDK
living under a path with a space (`C:\Program Files\flutter`). Route
`flutter`/`dart` through a space-free path — e.g. a directory junction to the
SDK — instead.

## Tests

```bash
flutter analyze
flutter test
```
