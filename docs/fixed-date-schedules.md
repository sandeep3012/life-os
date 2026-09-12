# Fixed-date schedules

- Tasks: optional date/time, repeat, task category, description, priority and due-time reminder.
- Habits: start date/time, repeat, category, description and separate reminder time. No priority.
- Events: date/time, repeat, description and existing before-start reminder. No category or priority.
- Repeat choices: none, daily, weekly (one or more weekdays), monthly and yearly; end dates are inclusive.
- Short months clamp to their last day without moving the original anchor. All days use local calendar arithmetic.

## Persistence

Schema 15 adds nullable schedule JSON and descriptions where needed. Task recurrence IDs and generation cursors are additive. Old rows and old backup JSON retain their defaults. Regenerate Drift after changing table definitions:

```sh
dart run build_runner build --delete-conflicting-outputs
```

Recurring tasks and events are materialized through a rolling one-year horizon. Completion never changes the next date. Habit schedules are evaluated against their logs, not materialized as tasks. Habit edits preserve the previous rule for dates before the edit day. Unscheduled days do not count as absent, in the weekly denominator, or as streak breaks.

Event editing offers this occurrence only or this and future occurrences. Future edits split the series and cap the old head, preserving earlier event content. Text/time-only updates retain existing future dates and the original monthly anchor. The stored template keeps subsequent generation independent of edits to the first occurrence. Task deletion remains occurrence-only; deleting the head also stops later horizon extensions, while already-generated occurrences remain.

## Reminders

ScheduleCoordinator observes database changes, startup/resume and date rollover. It queues the earliest eligible reminders, cancels obsolete managed reminders and preserves unrelated bill/goal notifications. iOS's finite queue is respected with up to 60 total pending entries, including unrelated entries already queued. No network is needed. The queue is replenished while the app is running or when it reopens; uninterrupted delivery for an unlimited period without reopening is not promised.

## Verification

```sh
flutter analyze
flutter test test/core/repeat_schedule_test.dart test/core/recurring_items_repository_test.dart test/core/schedule_migration_test.dart test/features/calendar/quick_add_event_sheet_test.dart
```

Device checks: create a weekday-only habit, confirm an off-day is disabled, mark an occurrence done, restart the app, edit the schedule and verify earlier history. Create a repeating task, complete one occurrence and confirm the next date and total remain unchanged. Check both notification and alarm modes with device permissions enabled. Use a full restart after migrating the database, not just hot reload.
