import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';

/// DB-only access for medications and the weekly workout plan.
///
/// Nothing here computes "taken today" or "workout progress" — those are
/// derived at the application layer from the log tables, matching how habit
/// streaks and budget spend work elsewhere in this app.
class HealthRepository {
  HealthRepository(this._db);

  final AppDatabase _db;

  // ---- medications ----

  Stream<List<Medication>> watchMedications() {
    return (_db.select(_db.medications)
          ..where((m) => m.active.equals(true))
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
        .watch();
  }

  /// 60 days is plenty for the "doses today" figure and a short adherence
  /// history, and bounds what the stream has to re-emit — same cap as
  /// `HabitsRepository.watchRecentLogs`.
  Stream<List<MedicationLog>> watchRecentMedicationLogs() {
    final since = dateOnly(DateTime.now()).subtract(const Duration(days: 60));
    return (_db.select(_db.medicationLogs)
          ..where((l) => l.date.isBiggerOrEqualValue(since)))
        .watch();
  }

  Future<String> createMedication({
    required String name,
    String dosageNote = '',
    String slot = 'am',
    String colorHex = '#4B7BA6',
    int? stockLeft,
    String frequency = 'daily',
    String daysCsv = '1,2,3,4,5,6,7',
    String timesCsv = '08:00',
    bool reminderEnabled = false,
  }) async {
    final row = await _db.into(_db.medications).insertReturning(
      MedicationsCompanion.insert(
        name: name,
        dosageNote: Value(dosageNote),
        slot: Value(slot),
        colorHex: Value(colorHex),
        stockLeft: Value(stockLeft),
        frequency: Value(frequency),
        daysCsv: Value(daysCsv),
        timesCsv: Value(timesCsv),
        reminderEnabled: Value(reminderEnabled),
      ),
    );
    return row.id;
  }

  Future<void> updateMedication({
    required String id,
    required String name,
    required String dosageNote,
    required String slot,
    required String frequency,
    required String daysCsv,
    required String timesCsv,
    required bool reminderEnabled,
    int? stockLeft,
  }) {
    return (_db.update(_db.medications)..where((m) => m.id.equals(id))).write(
      MedicationsCompanion(
        name: Value(name),
        dosageNote: Value(dosageNote),
        slot: Value(slot),
        frequency: Value(frequency),
        daysCsv: Value(daysCsv),
        timesCsv: Value(timesCsv),
        reminderEnabled: Value(reminderEnabled),
        stockLeft: Value(stockLeft),
      ),
    );
  }

  Future<void> archiveMedication(String id) {
    return (_db.update(_db.medications)..where((m) => m.id.equals(id)))
        .write(const MedicationsCompanion(active: Value(false)));
  }

  /// Records or clears today's dose. Taking a dose decrements [stockLeft] and
  /// un-taking restores it, so the refill warning tracks reality.
  Future<void> setTaken(String medicationId, DateTime date, bool taken) async {
    final day = dateOnly(date);
    final existing = await (_db.select(_db.medicationLogs)
          ..where((l) => l.medicationId.equals(medicationId) & l.date.equals(day)))
        .getSingleOrNull();

    if (taken) {
      if (existing != null) return;
      await _db.into(_db.medicationLogs).insert(
        MedicationLogsCompanion.insert(medicationId: medicationId, date: day),
      );
      await _adjustStock(medicationId, -1);
    } else {
      if (existing == null) return;
      await (_db.delete(_db.medicationLogs)..where((l) => l.id.equals(existing.id)))
          .go();
      await _adjustStock(medicationId, 1);
    }
  }

  /// Deliberately uses the typed update API rather than a `customStatement`.
  ///
  /// Raw SQL bypasses Drift's update tracking, so `watchMedications()` never
  /// re-emits and the screen keeps showing a stale "N left" until something else
  /// touches the table.
  Future<void> _adjustStock(String medicationId, int delta) async {
    final med = await (_db.select(_db.medications)
          ..where((m) => m.id.equals(medicationId)))
        .getSingleOrNull();
    final current = med?.stockLeft;
    if (current == null) return;

    final next = (current + delta).clamp(0, 100000);
    if (next == current) return;

    await (_db.update(_db.medications)..where((m) => m.id.equals(medicationId)))
        .write(MedicationsCompanion(stockLeft: Value(next)));
  }

  // ---- workout plan ----

  Stream<List<WorkoutDay>> watchWorkoutDays() {
    return (_db.select(_db.workoutDays)
          ..where((d) => d.active.equals(true))
          ..orderBy([(d) => OrderingTerm.asc(d.weekday)]))
        .watch();
  }

  Stream<List<Exercise>> watchExercises() {
    return (_db.select(_db.exercises)
          ..orderBy([(e) => OrderingTerm.asc(e.position)]))
        .watch();
  }

  Stream<List<WorkoutLog>> watchRecentWorkoutLogs() {
    final since = dateOnly(DateTime.now()).subtract(const Duration(days: 60));
    return (_db.select(_db.workoutLogs)
          ..where((l) => l.date.isBiggerOrEqualValue(since)))
        .watch();
  }

  Future<String> createWorkoutDay({
    required int weekday,
    required String label,
    String focus = '',
    int startMinute = 420,
    int endMinute = 480,
  }) async {
    final row = await _db.into(_db.workoutDays).insertReturning(
      WorkoutDaysCompanion.insert(
        weekday: weekday,
        label: label,
        focus: Value(focus),
        startMinute: Value(startMinute),
        endMinute: Value(endMinute),
      ),
    );
    return row.id;
  }

  Future<void> addExercise({
    required String workoutDayId,
    required String name,
    String scheme = '',
    int position = 0,
  }) {
    return _db.into(_db.exercises).insert(
      ExercisesCompanion.insert(
        workoutDayId: workoutDayId,
        name: name,
        scheme: Value(scheme),
        position: Value(position),
      ),
    );
  }

  /// Creates the same session on several weekdays at once — the plan's
  /// "repeats on" option. One row per weekday keeps the daily lookup a simple
  /// equality check instead of parsing a mask on every read.
  Future<List<String>> createWeeklyPlan({
    required List<int> weekdays,
    required String label,
    String focus = '',
    int startMinute = 420,
    int endMinute = 480,
  }) async {
    final ids = <String>[];
    for (final weekday in weekdays) {
      ids.add(await createWorkoutDay(
        weekday: weekday,
        label: label,
        focus: focus,
        startMinute: startMinute,
        endMinute: endMinute,
      ));
    }
    return ids;
  }

  Future<void> updateWorkoutDay({
    required String id,
    required String label,
    required String focus,
    required int startMinute,
    required int endMinute,
  }) {
    return (_db.update(_db.workoutDays)..where((d) => d.id.equals(id))).write(
      WorkoutDaysCompanion(
        label: Value(label),
        focus: Value(focus),
        startMinute: Value(startMinute),
        endMinute: Value(endMinute),
      ),
    );
  }

  /// Removes a training day and everything logged against its exercises.
  Future<void> deleteWorkoutDay(String id) async {
    final own = await (_db.select(_db.exercises)
          ..where((e) => e.workoutDayId.equals(id)))
        .get();
    for (final exercise in own) {
      await deleteExercise(exercise.id);
    }
    await (_db.delete(_db.workoutDays)..where((d) => d.id.equals(id))).go();
  }

  /// Removes an exercise plus its completion and set history, so no orphan rows
  /// are left pointing at a missing parent.
  Future<void> deleteExercise(String id) async {
    await (_db.delete(_db.exerciseSetLogs)..where((l) => l.exerciseId.equals(id)))
        .go();
    await (_db.delete(_db.workoutLogs)..where((l) => l.exerciseId.equals(id)))
        .go();
    await (_db.delete(_db.exercises)..where((e) => e.id.equals(id))).go();
  }

  // ---- per-set logging ----

  Stream<List<ExerciseSetLog>> watchRecentSetLogs() {
    final since = dateOnly(DateTime.now()).subtract(const Duration(days: 60));
    return (_db.select(_db.exerciseSetLogs)
          ..where((l) => l.date.isBiggerOrEqualValue(since))
          ..orderBy([(l) => OrderingTerm.asc(l.setNumber)]))
        .watch();
  }

  /// Appends a set, numbering it after whatever is already logged that day.
  Future<void> logSet({
    required String exerciseId,
    required DateTime date,
    required int reps,
    required int weightGrams,
  }) async {
    final day = dateOnly(date);
    final existing = await (_db.select(_db.exerciseSetLogs)
          ..where((l) => l.exerciseId.equals(exerciseId) & l.date.equals(day)))
        .get();
    final next = existing.fold<int>(0, (m, l) => l.setNumber > m ? l.setNumber : m) + 1;

    await _db.into(_db.exerciseSetLogs).insert(
      ExerciseSetLogsCompanion.insert(
        exerciseId: exerciseId,
        date: day,
        setNumber: next,
        reps: Value(reps),
        weightGrams: Value(weightGrams),
      ),
    );
  }

  /// Deletes a set and closes the gap, so set numbers stay 1..n.
  Future<void> deleteSet(String id) async {
    final row = await (_db.select(_db.exerciseSetLogs)..where((l) => l.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;

    await (_db.delete(_db.exerciseSetLogs)..where((l) => l.id.equals(id))).go();

    final rest = await (_db.select(_db.exerciseSetLogs)
          ..where((l) =>
              l.exerciseId.equals(row.exerciseId) & l.date.equals(row.date))
          ..orderBy([(l) => OrderingTerm.asc(l.setNumber)]))
        .get();
    for (var i = 0; i < rest.length; i++) {
      if (rest[i].setNumber == i + 1) continue;
      await (_db.update(_db.exerciseSetLogs)..where((l) => l.id.equals(rest[i].id)))
          .write(ExerciseSetLogsCompanion(setNumber: Value(i + 1)));
    }
  }

  Future<void> setExerciseCompleted(
    String exerciseId,
    DateTime date,
    bool completed,
  ) async {
    final day = dateOnly(date);
    final existing = await (_db.select(_db.workoutLogs)
          ..where((l) => l.exerciseId.equals(exerciseId) & l.date.equals(day)))
        .getSingleOrNull();

    if (completed) {
      if (existing != null) return;
      await _db.into(_db.workoutLogs).insert(
        WorkoutLogsCompanion.insert(exerciseId: exerciseId, date: day),
      );
    } else if (existing != null) {
      await (_db.delete(_db.workoutLogs)..where((l) => l.id.equals(existing.id)))
          .go();
    }
  }
}
