import 'dart:convert';

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
    return (_db.select(
      _db.habits,
    )..where((h) => h.id.equals(id))).getSingleOrNull();
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
    double? targetAmount,
    String? targetUnit,
  }) async {
    _validateTarget(targetAmount);
    if (schedule != null) RepeatSchedule.decode(schedule.encode());
    final row = await _db
        .into(_db.habits)
        .insertReturning(
          HabitsCompanion.insert(
            name: name,
            categoryId: Value(categoryId),
            description: Value(description),
            schedule: Value(schedule?.encode()),
            frequency: Value(schedule?.frequency ?? 'daily'),
            targetAmount: Value(targetAmount),
            targetUnit: Value(targetUnit),
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
    double? targetAmount,
    String? targetUnit,
    bool clearTarget = false,
  }) async {
    _validateTarget(targetAmount);
    final old = await getHabit(id);
    if (old == null) return;
    if (schedule != null) {
      RepeatSchedule.decode(schedule.encode());
      if (schedule.encode() != old.repeatSchedule.encode()) {
        schedule = RepeatSchedule(
          start: schedule.start,
          frequency: schedule.frequency,
          weekdays: schedule.weekdays,
          end: schedule.end,
          previous: old.repeatSchedule,
          effectiveFrom: dateOnly(DateTime.now()),
        );
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
        targetAmount: clearTarget || targetAmount != null
            ? Value(clearTarget ? null : targetAmount)
            : const Value.absent(),
        targetUnit: clearTarget || targetAmount != null
            ? Value(clearTarget ? null : targetUnit)
            : const Value.absent(),
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

  Future<void> pauseHabit(String id, DateTime until, {DateTime? now}) async {
    var start = dateOnly(now ?? DateTime.now());
    final end = dateOnly(until);
    if (end.isBefore(start)) throw ArgumentError('Pause end is in the past');
    final habit = await getHabit(id);
    if (habit == null) return;
    final history = habit.pastPauses;
    if (habit.pauseStartedAt != null && habit.pausedUntil != null) {
      final yesterday = DateTime(start.year, start.month, start.day - 1);
      final previousEnd = habit.pausedUntil!.isBefore(yesterday)
          ? habit.pausedUntil!
          : yesterday;
      if (!previousEnd.isBefore(habit.pauseStartedAt!)) {
        history.add([habit.pauseStartedAt!, previousEnd]);
      }
    }
    final log =
        await (_db.select(_db.habitLogs)
              ..where((l) => l.habitId.equals(id) & l.date.equals(start)))
            .getSingleOrNull();
    // Do not hide progress already recorded today by pausing afterward.
    if (log != null && (log.completed || (log.amount ?? 0) > 0)) {
      start = DateTime(start.year, start.month, start.day + 1);
    }
    await (_db.update(_db.habits)..where((h) => h.id.equals(id))).write(
      HabitsCompanion(
        pauseStartedAt: Value(start.isAfter(end) ? null : start),
        pausedUntil: Value(start.isAfter(end) ? null : end),
        pauseHistory: Value(_encodePauses(history)),
      ),
    );
  }

  Future<void> resumeHabit(String id, {DateTime? now}) async {
    final habit = await getHabit(id);
    if (habit == null) return;
    final today = dateOnly(now ?? DateTime.now());
    final history = habit.pastPauses;
    if (habit.pauseStartedAt != null && habit.pausedUntil != null) {
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      final end = habit.pausedUntil!.isBefore(yesterday)
          ? habit.pausedUntil!
          : yesterday;
      if (!end.isBefore(habit.pauseStartedAt!)) {
        history.add([habit.pauseStartedAt!, end]);
      }
    }
    await (_db.update(_db.habits)..where((h) => h.id.equals(id))).write(
      HabitsCompanion(
        pauseStartedAt: const Value(null),
        pausedUntil: const Value(null),
        pauseHistory: Value(_encodePauses(history)),
      ),
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
    return _db
        .into(_db.categories)
        .insertReturning(
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
    double? amount,
  }) async {
    if (amount != null && (!amount.isFinite || amount < 0)) {
      throw ArgumentError('Amount must be finite and non-negative');
    }
    final day = dateOnly(date);
    final habit = await getHabit(habitId);
    if (habit == null ||
        !habit.scheduledOn(day) ||
        day.isAfter(dateOnly(DateTime.now()))) {
      return;
    }
    final measured = habit.targetAmount == null
        ? null
        : amount ?? (completed ? habit.targetAmount : 0);
    final isComplete = habit.targetAmount == null
        ? completed
        : (measured ?? 0) >= habit.targetAmount!;
    final existing =
        await (_db.select(_db.habitLogs)
              ..where((l) => l.habitId.equals(habitId) & l.date.equals(day)))
            .getSingleOrNull();

    // A note edit must not reset partial/above-target amounts or reinterpret
    // historical completion against a subsequently changed target.
    if (existing != null &&
        notes != null &&
        amount == null &&
        completed == existing.completed) {
      await (_db.update(_db.habitLogs)..where((l) => l.id.equals(existing.id)))
          .write(HabitLogsCompanion(notes: Value(notes)));
      return;
    }

    if (existing == null) {
      await _db
          .into(_db.habitLogs)
          .insert(
            HabitLogsCompanion.insert(
              habitId: habitId,
              date: day,
              completed: Value(isComplete),
              amount: Value(measured),
              targetAmountSnapshot: Value(habit.targetAmount),
              targetUnitSnapshot: Value(habit.targetUnit),
              notes: Value(notes),
            ),
          );
    } else {
      await (_db.update(
        _db.habitLogs,
      )..where((l) => l.id.equals(existing.id))).write(
        HabitLogsCompanion(
          completed: Value(isComplete),
          amount: Value(measured),
          targetAmountSnapshot: Value(habit.targetAmount),
          targetUnitSnapshot: Value(habit.targetUnit),
          // Only overwrite notes when a caller actually passed one — the
          // plain today-toggle call site never passes `notes`, and it must
          // not silently null out a note set earlier from the detail screen.
          notes: notes == null ? const Value.absent() : Value(notes),
        ),
      );
    }
  }
}

void _validateTarget(double? target) {
  if (target != null && (!target.isFinite || target <= 0)) {
    throw ArgumentError('Target must be a finite positive number');
  }
}

String _encodePauses(List<List<DateTime>> ranges) => jsonEncode(
  ranges
      .map((range) => range.map((date) => date.toIso8601String()).toList())
      .toList(),
);
