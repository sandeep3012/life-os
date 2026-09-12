import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/utils/date_utils.dart';
import '../data/health_repository.dart';

final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  return HealthRepository(ref.watch(appDatabaseProvider));
});

final medicationsProvider = StreamProvider<List<Medication>>((ref) {
  return ref.watch(healthRepositoryProvider).watchMedications();
});

final medicationLogsProvider = StreamProvider<List<MedicationLog>>((ref) {
  return ref.watch(healthRepositoryProvider).watchRecentMedicationLogs();
});

/// A medication paired with whether today's dose is logged.
class MedicationDose {
  const MedicationDose({required this.medication, required this.taken});

  final Medication medication;
  final bool taken;

  /// Comp: the small uppercase pill beside the name — `DAILY`, `WEEKLY`, `ALT`.
  String get frequencyLabel => switch (medication.frequency) {
    'weekly' => 'WEEKLY',
    'alt' => 'ALT DAYS',
    _ => 'DAILY',
  };

  /// Whether this medication is scheduled for [day] at all. `daily` is every
  /// day; `weekly`/`alt` follow the stored weekday list.
  bool scheduledOn(DateTime day) {
    if (medication.frequency == 'daily') return true;
    final days = medication.daysCsv
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toSet();
    return days.contains(day.weekday);
  }
}

/// Today's doses, in the comp's three groups. Only medications actually
/// scheduled for today appear.
final todayDosesProvider = Provider<List<MedicationDose>>((ref) {
  final meds = ref.watch(medicationsProvider).value ?? const [];
  final logs = ref.watch(medicationLogsProvider).value ?? const [];
  final today = dateOnly(DateTime.now());

  final takenIds = logs
      .where((l) => l.taken && dateOnly(l.date) == today)
      .map((l) => l.medicationId)
      .toSet();

  return meds
      .map((m) => MedicationDose(medication: m, taken: takenIds.contains(m.id)))
      .where((d) => d.scheduledOn(today))
      .toList();
});

/// Comp's slot grouping: `am` → Morning, `pm` → Afternoon, `night` → Night.
final dosesBySlotProvider = Provider<Map<String, List<MedicationDose>>>((ref) {
  final doses = ref.watch(todayDosesProvider);
  final grouped = <String, List<MedicationDose>>{'am': [], 'pm': [], 'night': []};
  for (final dose in doses) {
    (grouped[dose.medication.slot] ??= []).add(dose);
  }
  grouped.removeWhere((_, v) => v.isEmpty);
  return grouped;
});

/// The medication running out soonest, if any is low enough to warrant the
/// comp's amber refill banner.
final lowStockMedicationProvider = Provider<Medication?>((ref) {
  final meds = ref.watch(medicationsProvider).value ?? const [];
  final low = meds
      .where((m) => m.stockLeft != null && m.stockLeft! <= 7)
      .toList()
    ..sort((a, b) => a.stockLeft!.compareTo(b.stockLeft!));
  return low.isEmpty ? null : low.first;
});

// ---- workout plan ----

final workoutDaysProvider = StreamProvider<List<WorkoutDay>>((ref) {
  return ref.watch(healthRepositoryProvider).watchWorkoutDays();
});

final exercisesProvider = StreamProvider<List<Exercise>>((ref) {
  return ref.watch(healthRepositoryProvider).watchExercises();
});

final workoutLogsProvider = StreamProvider<List<WorkoutLog>>((ref) {
  return ref.watch(healthRepositoryProvider).watchRecentWorkoutLogs();
});

final exerciseSetLogsProvider = StreamProvider<List<ExerciseSetLog>>((ref) {
  return ref.watch(healthRepositoryProvider).watchRecentSetLogs();
});

/// What was lifted for one exercise today: the sets themselves plus the figures
/// the row shows. All derived — nothing here is stored on the exercise.
class ExerciseSession {
  const ExerciseSession({required this.sets});

  final List<ExerciseSetLog> sets;

  int get setCount => sets.length;

  int get totalReps => sets.fold(0, (sum, s) => sum + s.reps);

  /// Heaviest single set, in grams.
  int get topWeightGrams =>
      sets.fold(0, (m, s) => s.weightGrams > m ? s.weightGrams : m);

  /// Weight × reps summed across the session, in grams.
  int get volumeGrams =>
      sets.fold(0, (sum, s) => sum + s.weightGrams * s.reps);

  /// Kilograms for display, e.g. `62.5`.
  static double kg(int grams) => grams / 1000;

  /// Trims a trailing `.0` so whole numbers read as "60 kg" not "60.0 kg".
  static String formatKg(int grams) {
    final value = kg(grams);
    final text = value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);
    return '$text kg';
  }
}

/// Today's sets for a given exercise.
final exerciseSessionProvider =
    Provider.family<ExerciseSession, String>((ref, exerciseId) {
  final today = dateOnly(DateTime.now());
  final sets = (ref.watch(exerciseSetLogsProvider).value ?? const [])
      .where((l) => l.exerciseId == exerciseId && dateOnly(l.date) == today)
      .toList()
    ..sort((a, b) => a.setNumber.compareTo(b.setNumber));
  return ExerciseSession(sets: sets);
});

/// Every training day in the plan, grouped by weekday, for the plan editor.
final weeklyPlanProvider = Provider<Map<int, List<WorkoutDay>>>((ref) {
  final days = ref.watch(workoutDaysProvider).value ?? const [];
  final grouped = <int, List<WorkoutDay>>{};
  for (final day in days) {
    (grouped[day.weekday] ??= []).add(day);
  }
  return grouped;
});

/// Exercises belonging to one training day, in order.
final exercisesForDayProvider =
    Provider.family<List<Exercise>, String>((ref, workoutDayId) {
  return (ref.watch(exercisesProvider).value ?? const [])
      .where((e) => e.workoutDayId == workoutDayId)
      .toList()
    ..sort((a, b) => a.position.compareTo(b.position));
});

/// Today's training block with its exercises and completion — what the
/// dashboard hero and the Health screen's gym tab both read.
class TodayWorkout {
  const TodayWorkout({
    required this.day,
    required this.exercises,
    required this.completedIds,
  });

  final WorkoutDay day;
  final List<Exercise> exercises;
  final Set<String> completedIds;

  int get doneCount => exercises.where((e) => completedIds.contains(e.id)).length;

  double get progress =>
      exercises.isEmpty ? 0 : doneCount / exercises.length;

  /// The first exercise not yet ticked off — the hero's "Up next".
  Exercise? get nextExercise {
    for (final e in exercises) {
      if (!completedIds.contains(e.id)) return e;
    }
    return null;
  }

  DateTime get start {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .add(Duration(minutes: day.startMinute));
  }

  DateTime get end {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .add(Duration(minutes: day.endMinute));
  }

  /// True while the current time sits inside the block's window.
  bool get isLive {
    final now = DateTime.now();
    return !now.isBefore(start) && now.isBefore(end);
  }
}

final todayWorkoutProvider = Provider<TodayWorkout?>((ref) {
  final days = ref.watch(workoutDaysProvider).value ?? const [];
  final now = DateTime.now();
  final matches = days.where((d) => d.weekday == now.weekday);
  if (matches.isEmpty) return null;
  final day = matches.first;

  final all = ref.watch(exercisesProvider).value ?? const [];
  final exercises = all.where((e) => e.workoutDayId == day.id).toList();

  final today = dateOnly(now);
  final exerciseIds = exercises.map((e) => e.id).toSet();
  final completed = (ref.watch(workoutLogsProvider).value ?? const [])
      .where((l) =>
          l.completed &&
          dateOnly(l.date) == today &&
          exerciseIds.contains(l.exerciseId))
      .map((l) => l.exerciseId)
      .toSet();

  return TodayWorkout(day: day, exercises: exercises, completedIds: completed);
});

class HealthController {
  const HealthController(this._repo);

  final HealthRepository _repo;

  Future<void> toggleDose(Medication medication, bool taken) =>
      _repo.setTaken(medication.id, DateTime.now(), taken);

  Future<void> toggleExercise(Exercise exercise, bool completed) =>
      _repo.setExerciseCompleted(exercise.id, DateTime.now(), completed);

  /// Creates one session per selected weekday — the plan's "repeats on" option.
  Future<void> addWeeklyPlan({
    required List<int> weekdays,
    required String label,
    required String focus,
    required int startMinute,
    required int endMinute,
  }) {
    return _repo.createWeeklyPlan(
      weekdays: weekdays,
      label: label,
      focus: focus,
      startMinute: startMinute,
      endMinute: endMinute,
    );
  }

  Future<void> updateWorkoutDay({
    required String id,
    required String label,
    required String focus,
    required int startMinute,
    required int endMinute,
  }) {
    return _repo.updateWorkoutDay(
      id: id,
      label: label,
      focus: focus,
      startMinute: startMinute,
      endMinute: endMinute,
    );
  }

  Future<void> deleteWorkoutDay(String id) => _repo.deleteWorkoutDay(id);

  Future<void> addExercise({
    required String workoutDayId,
    required String name,
    required String scheme,
    required int position,
  }) {
    return _repo.addExercise(
      workoutDayId: workoutDayId,
      name: name,
      scheme: scheme,
      position: position,
    );
  }

  Future<void> deleteExercise(String id) => _repo.deleteExercise(id);

  /// Logs one set of an exercise for today. [weightKg] is converted to the
  /// integer grams the table stores.
  Future<void> logSet({
    required String exerciseId,
    required int reps,
    required double weightKg,
  }) {
    return _repo.logSet(
      exerciseId: exerciseId,
      date: DateTime.now(),
      reps: reps,
      weightGrams: (weightKg * 1000).round(),
    );
  }

  Future<void> deleteSet(String id) => _repo.deleteSet(id);

  Future<String> addMedication({
    required String name,
    required String dosageNote,
    required String slot,
    required String frequency,
    required String daysCsv,
    required String timesCsv,
    required bool reminderEnabled,
    int? stockLeft,
    String colorHex = '#4B7BA6',
  }) {
    return _repo.createMedication(
      name: name,
      dosageNote: dosageNote,
      slot: slot,
      frequency: frequency,
      daysCsv: daysCsv,
      timesCsv: timesCsv,
      reminderEnabled: reminderEnabled,
      stockLeft: stockLeft,
      colorHex: colorHex,
    );
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
    return _repo.updateMedication(
      id: id,
      name: name,
      dosageNote: dosageNote,
      slot: slot,
      frequency: frequency,
      daysCsv: daysCsv,
      timesCsv: timesCsv,
      reminderEnabled: reminderEnabled,
      stockLeft: stockLeft,
    );
  }

  Future<void> archiveMedication(String id) => _repo.archiveMedication(id);
}

final healthControllerProvider = Provider<HealthController>((ref) {
  return HealthController(ref.watch(healthRepositoryProvider));
});
