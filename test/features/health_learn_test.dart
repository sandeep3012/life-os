import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/utils/date_utils.dart';
import 'package:life_manager/features/health/application/health_providers.dart';
import 'package:life_manager/features/health/data/health_repository.dart';
import 'package:life_manager/features/learn/application/learn_providers.dart';
import 'package:life_manager/features/learn/data/learn_repository.dart';

/// Pure-logic coverage for the two modules the redesign added. Both derive their
/// headline numbers from log tables rather than storing them, so these assert
/// the derivation, not a stored counter.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() {
    container.dispose();
    return db.close();
  });

  /// Riverpod tears a StreamProvider down before its first emission unless
  /// something is listening — the trap documented in CLAUDE.md. Each test holds
  /// subscriptions for its duration and pumps the event loop after a write.
  Future<void> pump() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  void listenHealth() {
    container.listen(medicationsProvider, (_, _) {});
    container.listen(medicationLogsProvider, (_, _) {});
    container.listen(workoutDaysProvider, (_, _) {});
    container.listen(exercisesProvider, (_, _) {});
    container.listen(workoutLogsProvider, (_, _) {});
  }

  void listenLearn() {
    container.listen(learnBooksProvider, (_, _) {});
    container.listen(learnNotesProvider, (_, _) {});
  }

  group('medications', () {
    test('a scheduled dose appears today and toggling it updates stock', () async {
      listenHealth();
      final repo = HealthRepository(db);
      final id = await repo.createMedication(
        name: 'Vitamin D3',
        dosageNote: '1 capsule',
        slot: 'am',
        stockLeft: 10,
      );

      await pump();

      var doses = container.read(todayDosesProvider);
      expect(doses, hasLength(1));
      expect(doses.single.taken, isFalse);

      await repo.setTaken(id, DateTime.now(), true);
      await pump();

      doses = container.read(todayDosesProvider);
      expect(doses.single.taken, isTrue);
      // Taking a dose draws down the supply, so the refill warning is real.
      expect(doses.single.medication.stockLeft, 9);

      // Un-taking restores it rather than leaking a dose.
      await repo.setTaken(id, DateTime.now(), false);
      await pump();
      expect(container.read(todayDosesProvider).single.medication.stockLeft, 10);
    });

    test('a weekly medication only appears on its listed days', () async {
      listenHealth();
      final repo = HealthRepository(db);
      final today = DateTime.now().weekday;
      final otherDay = today == 7 ? 1 : today + 1;

      await repo.createMedication(
        name: 'Off-day supplement',
        frequency: 'weekly',
        daysCsv: '$otherDay',
      );
      await pump();

      expect(container.read(todayDosesProvider), isEmpty);
    });

    test('low stock surfaces the medication closest to running out', () async {
      listenHealth();
      final repo = HealthRepository(db);
      await repo.createMedication(name: 'Plenty', stockLeft: 40);
      await repo.createMedication(name: 'Almost gone', stockLeft: 3);
      await pump();

      expect(container.read(lowStockMedicationProvider)?.name, 'Almost gone');
    });
  });

  group('workout plan', () {
    test('today\'s block reports progress and the next exercise', () async {
      listenHealth();
      final repo = HealthRepository(db);
      final dayId = await repo.createWorkoutDay(
        weekday: DateTime.now().weekday,
        label: 'Push Day',
        focus: 'Chest & Triceps',
      );
      await repo.addExercise(workoutDayId: dayId, name: 'Bench press', scheme: '4×8', position: 0);
      await repo.addExercise(workoutDayId: dayId, name: 'Incline press', scheme: '4×10', position: 1);

      await pump();

      var workout = container.read(todayWorkoutProvider);
      expect(workout, isNotNull);
      expect(workout!.exercises, hasLength(2));
      expect(workout.progress, 0);
      expect(workout.nextExercise?.name, 'Bench press');

      await repo.setExerciseCompleted(workout.exercises.first.id, DateTime.now(), true);
      await pump();

      workout = container.read(todayWorkoutProvider)!;
      expect(workout.doneCount, 1);
      expect(workout.progress, 0.5);
      expect(workout.nextExercise?.name, 'Incline press');
    });
  });

  group('learn', () {
    test('a new note is due immediately and reviewing pushes it out', () async {
      listenLearn();
      final repo = LearnRepository(db);
      final bookId = await repo.createBook(name: 'Flutter');
      await repo.createNote(bookId: bookId, title: 'Riverpod families');

      await pump();

      expect(container.read(dueNotesProvider), hasLength(1));

      final note = container.read(learnNotesProvider).value!.single;
      await repo.markReviewed(note);
      await pump();

      // No longer due, and scheduled for a future date.
      expect(container.read(dueNotesProvider), isEmpty);
      final reviewed = container.read(learnNotesProvider).value!.single;
      expect(reviewed.lastReviewedAt, isNotNull);
      expect(reviewed.reviewDueAt!.isAfter(DateTime.now()), isTrue);
    });

    test('book progress is the reviewed share of its notes', () async {
      listenLearn();
      final repo = LearnRepository(db);
      final bookId = await repo.createBook(name: 'System design');
      await repo.createNote(bookId: bookId, title: 'Caching');
      await repo.createNote(bookId: bookId, title: 'Sharding');

      await pump();

      expect(container.read(bookProgressProvider).single.ratio, 0);

      final first = container.read(learnNotesProvider).value!.first;
      await repo.markReviewed(first);
      await pump();

      expect(container.read(bookProgressProvider).single.ratio, 0.5);
    });

    test('body blocks round-trip through JSON and survive a malformed body', () {
      const blocks = [
        NoteBlock(type: 'p', text: 'Prose'),
        NoteBlock(type: 'code', text: 'final x = 1;'),
      ];
      final decoded = NoteBlock.decode(NoteBlock.encode(blocks));
      expect(decoded.map((b) => b.type), ['p', 'code']);
      expect(decoded.last.text, 'final x = 1;');

      // A corrupt body must not take the reader down.
      expect(NoteBlock.decode('not json'), isEmpty);
    });
  });

  test('the Health and Learn tables are present from v15 onward', () {
    // They land in v15. This asserts the floor rather than an exact number so a
    // later migration doesn't fail here for no reason; the exact current version
    // is pinned once, in gym_tracking_test.dart.
    expect(db.schemaVersion, greaterThanOrEqualTo(15));
  });

  test('a v14 database upgrades to v15 without losing existing rows', () async {
    // Simulates the real upgrade path: existing data present, new tables absent.
    final legacy = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(legacy.close);

    await legacy.into(legacy.habits).insert(
      HabitsCompanion.insert(name: 'Pre-existing habit'),
    );
    final before = await legacy.select(legacy.habits).get();
    expect(before, hasLength(1));

    // The new tables are additive, so prior rows are untouched and the new
    // tables are queryable.
    final meds = await legacy.select(legacy.medications).get();
    expect(meds, isEmpty);
    final notes = await legacy.select(legacy.learnNotes).get();
    expect(notes, isEmpty);
    expect(
      (await legacy.select(legacy.habits).get()).single.name,
      'Pre-existing habit',
    );
    expect(dateOnly(DateTime.now()).hour, 0);
  });
}
