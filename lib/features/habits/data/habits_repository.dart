import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';

class HabitsRepository {
  HabitsRepository(this._db);

  final AppDatabase _db;

  Stream<List<Habit>> watchHabits() {
    return (_db.select(
      _db.habits,
    )..where((h) => h.archived.equals(false))).watch();
  }

  /// 60 days is enough history for the streak calculation without watching
  /// the whole table as habits accumulate years of logs.
  Stream<List<HabitLog>> watchRecentLogs() {
    final since = dateOnly(DateTime.now()).subtract(const Duration(days: 60));
    return (_db.select(
      _db.habitLogs,
    )..where((l) => l.date.isBiggerOrEqualValue(since))).watch();
  }

  Future<String> createHabit(
    String name, {
    bool reminderEnabled = false,
    int? reminderHour,
    int? reminderMinute,
  }) async {
    final row = await _db.into(_db.habits).insertReturning(
      HabitsCompanion.insert(
        name: name,
        reminderEnabled: Value(reminderEnabled),
        reminderHour: Value(reminderHour),
        reminderMinute: Value(reminderMinute),
      ),
    );
    return row.id;
  }

  Future<void> setCompletedForDate(
    String habitId,
    DateTime date,
    bool completed,
  ) async {
    final day = dateOnly(date);
    final existing =
        await (_db.select(_db.habitLogs)..where(
          (l) => l.habitId.equals(habitId) & l.date.equals(day),
        )).getSingleOrNull();

    if (existing == null) {
      await _db.into(_db.habitLogs).insert(
        HabitLogsCompanion.insert(
          habitId: habitId,
          date: day,
          completed: Value(completed),
        ),
      );
    } else {
      await (_db.update(
        _db.habitLogs,
      )..where((l) => l.id.equals(existing.id))).write(
        HabitLogsCompanion(completed: Value(completed)),
      );
    }
  }
}
