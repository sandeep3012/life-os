import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Streaks and the 7-day dot grid shown on the Tasks & Habits screen are
/// derived from [HabitLogs] at query time — no separate streak counter is
/// persisted, so it can never drift out of sync with the logged history.
class Habits extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text()();

  /// daily | weekly | custom
  TextColumn get frequency => text().withDefault(const Constant('daily'))();
  IntColumn get targetPerWeek => integer().withDefault(const Constant(7))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  /// Per-habit daily reminder, independent of the app-wide "Habit reminders"
  /// generic check-in nudge in Settings — off by default (opt-in), unlike
  /// tasks, since there's no natural due-date signal implying "remind me."
  BoolColumn get reminderEnabled => boolean().withDefault(const Constant(false))();
  IntColumn get reminderHour => integer().nullable()();
  IntColumn get reminderMinute => integer().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

class HabitLogs extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get habitId => text().references(Habits, #id)();

  /// Date-only (time truncated to midnight) — one log per habit per day.
  DateTimeColumn get date => dateTime()();
  BoolColumn get completed => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {habitId, date},
  ];
}
