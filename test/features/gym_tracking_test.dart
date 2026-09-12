import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/features/health/application/health_providers.dart';
import 'package:life_manager/features/health/data/health_repository.dart';

/// Covers the gym features the plan screen exposes: building a recurring weekly
/// plan, adding exercises, and logging weight and reps per set.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late HealthRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    repo = HealthRepository(db);
  });

  tearDown(() {
    container.dispose();
    return db.close();
  });

  Future<void> pump() => Future<void>.delayed(const Duration(milliseconds: 20));

  void listen() {
    container.listen(workoutDaysProvider, (_, _) {});
    container.listen(exercisesProvider, (_, _) {});
    container.listen(workoutLogsProvider, (_, _) {});
    container.listen(exerciseSetLogsProvider, (_, _) {});
  }

  test('a session can repeat across several weekdays', () async {
    listen();
    await repo.createWeeklyPlan(
      weekdays: [1, 3, 5],
      label: 'Push Day',
      focus: 'Chest & Triceps',
    );
    await pump();

    final plan = container.read(weeklyPlanProvider);
    expect(plan.keys.toList()..sort(), [1, 3, 5]);
    expect(plan[1]!.single.label, 'Push Day');
    // Each weekday gets its own row, so the daily lookup stays an equality check.
    expect(plan[3]!.single.focus, 'Chest & Triceps');
  });

  test('logging sets records weight and reps and derives the session', () async {
    listen();
    final dayId = await repo.createWorkoutDay(
      weekday: DateTime.now().weekday,
      label: 'Push Day',
    );
    await repo.addExercise(workoutDayId: dayId, name: 'Bench press', scheme: '3×8');
    await pump();

    final exercise = container.read(exercisesForDayProvider(dayId)).single;
    var session = container.read(exerciseSessionProvider(exercise.id));
    expect(session.setCount, 0);

    // 60 kg × 8, then 62.5 kg × 6 — the half-plate is why weight is stored in
    // integer grams rather than as a double.
    await repo.logSet(
      exerciseId: exercise.id,
      date: DateTime.now(),
      reps: 8,
      weightGrams: 60000,
    );
    await repo.logSet(
      exerciseId: exercise.id,
      date: DateTime.now(),
      reps: 6,
      weightGrams: 62500,
    );
    await pump();

    session = container.read(exerciseSessionProvider(exercise.id));
    expect(session.setCount, 2);
    expect(session.sets.map((s) => s.setNumber), [1, 2]);
    expect(session.totalReps, 14);
    expect(session.topWeightGrams, 62500);
    expect(session.volumeGrams, 60000 * 8 + 62500 * 6);
    expect(ExerciseSession.formatKg(62500), '62.5 kg');
    expect(ExerciseSession.formatKg(60000), '60 kg');
  });

  test('deleting a set renumbers the rest so they stay 1..n', () async {
    listen();
    final dayId = await repo.createWorkoutDay(weekday: 1, label: 'Pull Day');
    await repo.addExercise(workoutDayId: dayId, name: 'Row');
    await pump();

    final exercise = container.read(exercisesForDayProvider(dayId)).single;
    for (var i = 0; i < 3; i++) {
      await repo.logSet(
        exerciseId: exercise.id,
        date: DateTime.now(),
        reps: 10,
        weightGrams: 40000 + i * 2500,
      );
    }
    await pump();

    final sets = container.read(exerciseSessionProvider(exercise.id)).sets;
    expect(sets.map((s) => s.setNumber), [1, 2, 3]);

    await repo.deleteSet(sets[1].id);
    await pump();

    final after = container.read(exerciseSessionProvider(exercise.id)).sets;
    expect(after.map((s) => s.setNumber), [1, 2]);
    // The survivors keep their numbers — the gap is closed, not left at 1,3.
    expect(after.map((s) => s.weightGrams), [40000, 45000]);
  });

  test('removing an exercise takes its sets and completion with it', () async {
    listen();
    final dayId = await repo.createWorkoutDay(weekday: 1, label: 'Legs');
    await repo.addExercise(workoutDayId: dayId, name: 'Squat');
    await pump();

    final exercise = container.read(exercisesForDayProvider(dayId)).single;
    await repo.logSet(
      exerciseId: exercise.id,
      date: DateTime.now(),
      reps: 5,
      weightGrams: 80000,
    );
    await repo.setExerciseCompleted(exercise.id, DateTime.now(), true);
    await pump();

    await repo.deleteExercise(exercise.id);
    await pump();

    expect(container.read(exercisesForDayProvider(dayId)), isEmpty);
    // No orphan rows pointing at a missing exercise.
    expect(await db.select(db.exerciseSetLogs).get(), isEmpty);
    expect(await db.select(db.workoutLogs).get(), isEmpty);
  });

  test('deleting a session removes its exercises too', () async {
    listen();
    final dayId = await repo.createWorkoutDay(weekday: 2, label: 'Core');
    await repo.addExercise(workoutDayId: dayId, name: 'Plank');
    await pump();

    await repo.deleteWorkoutDay(dayId);
    await pump();

    expect(container.read(weeklyPlanProvider), isEmpty);
    expect(await db.select(db.exercises).get(), isEmpty);
  });

  test('schema is at the version per-set logging was added in', () {
    expect(db.schemaVersion, 16);
  });
}
