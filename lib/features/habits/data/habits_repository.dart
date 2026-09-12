import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/scheduling/repeat_schedule.dart';
import '../domain/habit_schedule.dart';

class HabitsRepository {
  HabitsRepository(this._db);

  final AppDatabase _db;

  Stream<List<Habit>> watchHabits() {
    return (_db.select(
      _db.habits,
    )..where((h) => h.archived.equals(false))).watch();
  }

  Stream<List<Habit>> watchArchivedHabits() {
    return (_db.select(
      _db.habits,
    )..where((h) => h.archived.equals(true))).watch();
  }

  Future<Habit?> getHabit(String id) {
    return (_db.select(_db.habits)..where((h) => h.id.equals(id))).getSingleOrNull();
  }

  /// Sparse monthly/yearly schedules need history beyond a 60-day window.
  Stream<List<HabitLog>> watchRecentLogs() {
    return _db.select(_db.habitLogs).watch();
  }

  /// Full log history for one habit, newest first.
  Stream<List<HabitLog>> watchLogsForHabit(String habitId) {
    return (_db.select(_db.habitLogs)
          ..where((l) => l.habitId.equals(habitId))
          ..orderBy([(l) => OrderingTerm.desc(l.date)]))
        .watch();
  }

  Future<String> createHabit(
    String name, {
    String? categoryId,
    String? description,
    RepeatSchedule? schedule,
    bool reminderEnabled = false,
    int? reminderHour,
    int? reminderMinute,
    String reminderMode = 'notification',
  }) async {
    if (schedule != null) RepeatSchedule.decode(schedule.encode());
    final row = await _db.into(_db.habits).insertReturning(
      HabitsCompanion.insert(
        name: name,
        categoryId: Value(categoryId),
        description: Value(description),
        schedule: Value(schedule?.encode()),
        frequency: Value(schedule?.frequency ?? 'daily'),
        reminderEnabled: Value(reminderEnabled),
        reminderHour: Value(reminderHour),
        reminderMinute: Value(reminderMinute),
        reminderMode: Value(reminderMode),
      ),
    );
    return row.id;
  }

  Future<void> updateHabit({
    required String id,
    required String name,
    String? categoryId,
    String? description,
    RepeatSchedule? schedule,
    bool reminderEnabled = false,
    int? reminderHour,
    int? reminderMinute,
    String reminderMode = 'notification',
  }) async {
    final old = await getHabit(id);
    if (old == null) return;
    if (schedule != null) {
      RepeatSchedule.decode(schedule.encode());
      if (schedule.encode() != old.repeatSchedule.encode()) {
        schedule = RepeatSchedule(start: schedule.start, frequency: schedule.frequency,
          weekdays: schedule.weekdays, end: schedule.end,
          previous: old.repeatSchedule, effectiveFrom: dateOnly(DateTime.now()));
      }
    } else {
      schedule = old.repeatSchedule;
    }
    await (_db.update(_db.habits)..where((h) => h.id.equals(id))).write(
      HabitsCompanion(
        name: Value(name),
        categoryId: Value(categoryId),
        description: Value(description),
        schedule: Value(schedule.encode()),
        frequency: Value(schedule.frequency),
        reminderEnabled: Value(reminderEnabled),
        reminderHour: Value(reminderHour),
        reminderMinute: Value(reminderMinute),
        reminderMode: Value(reminderMode),
      ),
    );
  }

  /// Soft delete — [watchHabits] already excludes archived rows, so no
  /// other query needs to change.
  Future<void> archiveHabit(String id) {
    return (_db.update(_db.habits)..where((h) => h.id.equals(id))).write(
      const HabitsCompanion(archived: Value(true)),
    );
  }

  Future<void> unarchiveHabit(String id) {
    return (_db.update(_db.habits)..where((h) => h.id.equals(id))).write(
      const HabitsCompanion(archived: Value(false)),
    );
  }

  Stream<List<Category>> watchHabitCategories() {
    return (_db.select(
      _db.categories,
    )..where((c) => c.kind.equals('habit'))).watch();
  }

  /// Returns the created row (rather than just succeeding) so a caller that
  /// created this category inline — from the habit add/edit sheet's
  /// category picker — can select it immediately without waiting on the
  /// `watchHabitCategories()` stream to catch up.
  Future<Category> createHabitCategory({
    required String name,
    required String icon,
    required String colorHex,
  }) {
    return _db.into(_db.categories).insertReturning(
      CategoriesCompanion.insert(
        name: name,
        icon: Value(icon),
        colorHex: colorHex,
        kind: const Value('habit'),
      ),
    );
  }

  Future<void> setCompletedForDate(
    String habitId,
    DateTime date,
    bool completed, {
    String? notes,
  }) async {
    final day = dateOnly(date);
    final habit = await getHabit(habitId);
    if (habit == null || !habit.scheduledOn(day) || day.isAfter(dateOnly(DateTime.now()))) return;
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
          notes: Value(notes),
        ),
      );
    } else {
      await (_db.update(
        _db.habitLogs,
      )..where((l) => l.id.equals(existing.id))).write(
        HabitLogsCompanion(
          completed: Value(completed),
          // Only overwrite notes when a caller actually passed one — the
          // plain today-toggle call site never passes `notes`, and it must
          // not silently null out a note set earlier from the detail screen.
          notes: notes == null ? const Value.absent() : Value(notes),
        ),
      );
    }
  }
}
