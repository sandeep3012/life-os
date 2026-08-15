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

  Stream<List<Habit>> watchArchivedHabits() {
    return (_db.select(
      _db.habits,
    )..where((h) => h.archived.equals(true))).watch();
  }

  Future<Habit?> getHabit(String id) {
    return (_db.select(_db.habits)..where((h) => h.id.equals(id))).getSingleOrNull();
  }

  /// 60 days is enough history for the streak calculation without watching
  /// the whole table as habits accumulate years of logs.
  Stream<List<HabitLog>> watchRecentLogs() {
    final since = dateOnly(DateTime.now()).subtract(const Duration(days: 60));
    return (_db.select(
      _db.habitLogs,
    )..where((l) => l.date.isBiggerOrEqualValue(since))).watch();
  }

  /// Full log history for one habit, newest first — unwindowed (unlike
  /// [watchRecentLogs]'s 60-day cap) since it's scoped to a single habit's
  /// detail screen rather than every habit's streak calculation.
  Stream<List<HabitLog>> watchLogsForHabit(String habitId) {
    return (_db.select(_db.habitLogs)
          ..where((l) => l.habitId.equals(habitId))
          ..orderBy([(l) => OrderingTerm.desc(l.date)]))
        .watch();
  }

  Future<String> createHabit(
    String name, {
    String? categoryId,
    bool reminderEnabled = false,
    int? reminderHour,
    int? reminderMinute,
    String reminderMode = 'notification',
  }) async {
    final row = await _db.into(_db.habits).insertReturning(
      HabitsCompanion.insert(
        name: name,
        categoryId: Value(categoryId),
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
    bool reminderEnabled = false,
    int? reminderHour,
    int? reminderMinute,
    String reminderMode = 'notification',
  }) {
    return (_db.update(_db.habits)..where((h) => h.id.equals(id))).write(
      HabitsCompanion(
        name: Value(name),
        categoryId: Value(categoryId),
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
