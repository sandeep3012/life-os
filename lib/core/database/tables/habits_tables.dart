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
