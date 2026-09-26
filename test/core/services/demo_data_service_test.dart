// `isNull`/`isNotNull` are exported by both drift (as a query-builder expression) and
// flutter_test (as a matcher). This file wants the matcher, so drift's is hidden.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/services/demo_data_service.dart';

void main() {
  late AppDatabase db;
  late DemoDataService service;

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (sqlite) => sqlite.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    service = DemoDataService(db);
  });

  tearDown(() => db.close());

  test(
    'recovers UUID logs referencing previously deleted demo habits',
    () async {
      // Reproduce the on-device state left by the old removal implementation.
      await db.customStatement('PRAGMA foreign_keys = OFF');
      await db
          .into(db.habitLogs)
          .insert(
            HabitLogsCompanion.insert(
              id: const Value('abd75e45-6cd5-44b4-b14f-cfcd2cd33394'),
              habitId: 'demo-habit-water',
              date: DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day,
              ),
            ),
          );
      await db.customStatement('PRAGMA foreign_keys = ON');

      expect(await service.hasDemoData, isFalse);
      final summary = await service.generate();
      expect(summary.transactions, 636);
      expect(summary.tasks, 214);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect(
        await (db.select(db.habitLogs)..where(
              (l) => l.id.equals('abd75e45-6cd5-44b4-b14f-cfcd2cd33394'),
            ))
            .get(),
        isEmpty,
      );
    },
  );

  test(
    'removal includes manual demo check-ins and preserves real history',
    () async {
      await db
          .into(db.habits)
          .insert(
            HabitsCompanion.insert(
              id: const Value('real-habit'),
              name: 'My habit',
            ),
          );
      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      await db
          .into(db.habitLogs)
          .insert(
            HabitLogsCompanion.insert(
              id: const Value('real-log'),
              habitId: 'real-habit',
              date: today,
            ),
          );
      await service.generate(months: 1);
      // Replace generated history with a check-in created normally by the UI.
      await (db.delete(db.habitLogs)..where(
            (l) => l.habitId.equals('demo-habit-water') & l.date.equals(today),
          ))
          .go();
      await db
          .into(db.habitLogs)
          .insert(
            HabitLogsCompanion.insert(
              id: const Value('manual-check-in-uuid'),
              habitId: 'demo-habit-water',
              date: today,
            ),
          );
      await service.remove();
      final remaining = await db.select(db.habitLogs).get();
      expect(remaining.map((l) => l.id), ['real-log']);
      await service.generate(months: 1);
      expect(await service.hasDemoData, isTrue);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );

  test('generates and removes only prefixed demo records', () async {
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: const Value('real-account'),
            name: 'Personal account',
            type: 'Savings',
          ),
        );

    final summary = await service.generate(months: 2);

    expect(summary.transactions, 64);
    expect(summary.tasks, 38);
    expect(summary.events, 46);
    expect(summary.habitLogs, greaterThan(0));
    expect(await service.hasDemoData, isTrue);

    final subtasks = await db.select(db.subtasks).get();
    final tasks = await db.select(db.tasks).get();
    expect(subtasks, hasLength(13));
    for (final subtask in subtasks) {
      expect(tasks.any((task) => task.id == subtask.taskId), isTrue);
    }
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);

    await expectLater(service.generate(months: 2), throwsA(isA<StateError>()));

    await service.remove();

    expect(await service.hasDemoData, isFalse);
    expect(
      await (db.select(db.accounts)
            ..where((account) => account.id.equals('real-account')))
          .getSingleOrNull(),
      isNotNull,
    );
    expect(
      await (db.select(
        db.transactions,
      )..where((row) => row.id.like('demo-%'))).get(),
      isEmpty,
    );
  });

  test('rejects an empty date range before inserting records', () async {
    for (final months in [0, -1]) {
      await expectLater(service.generate(months: months), throwsArgumentError);
    }
    expect(await db.select(db.accounts).get(), isEmpty);
    expect(await db.select(db.tasks).get(), isEmpty);
  });

  test(
    'rows the user added under demo parents do not block regeneration',
    () async {
      // The on-device sequence that failed: generate, use the app normally —
      // which files rows with UUIDs under demo parents — remove, generate again.
      await service.generate(months: 1);
      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      // The device had an older generation with no leg-press history, so the
      // user's set was the only one for today. Recreate that state — on a leg
      // day the fresh generation would already hold today's set 1.
      await (db.delete(
        db.exerciseSetLogs,
      )..where((l) => l.exerciseId.equals('demo-ex-legpress'))).go();
      await db
          .into(db.exerciseSetLogs)
          .insert(
            ExerciseSetLogsCompanion.insert(
              id: const Value('user-logged-set-uuid'),
              exerciseId: 'demo-ex-legpress',
              date: today,
              setNumber: 1,
            ),
          );
      await db
          .into(db.workoutLogs)
          .insert(
            WorkoutLogsCompanion.insert(
              id: const Value('user-workout-log-uuid'),
              exerciseId: 'demo-ex-squat',
              date: today.subtract(const Duration(days: 1000)),
            ),
          );
      await db
          .into(db.exercises)
          .insert(
            ExercisesCompanion.insert(
              id: const Value('user-exercise-uuid'),
              workoutDayId: 'demo-wd-push',
              name: 'Added by hand',
            ),
          );
      await db
          .into(db.learnNotes)
          .insert(
            LearnNotesCompanion.insert(
              id: const Value('user-note-uuid'),
              bookId: 'demo-book-flutter',
              title: 'Mine',
            ),
          );
      await db
          .into(db.subtasks)
          .insert(
            SubtasksCompanion.insert(
              id: const Value('user-subtask-uuid'),
              taskId: 'demo-task-edge-checklist',
              title: 'Mine',
            ),
          );

      await service.remove();
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect(
        await (db.select(
          db.exerciseSetLogs,
        )..where((l) => l.exerciseId.like('demo-%'))).get(),
        isEmpty,
      );

      await service.generate(months: 1);
      expect(await service.hasDemoData, isTrue);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );

  test('a real document filed in a demo folder survives removal', () async {
    await service.generate(months: 1);
    await db
        .into(db.documents)
        .insert(
          DocumentsCompanion.insert(
            id: const Value('real-document'),
            title: 'My passport',
            filePath: 'documents/real.pdf',
            mimeType: 'application/pdf',
            folderId: const Value('demo-folder-identity'),
          ),
        );

    await service.remove();

    final doc = await (db.select(
      db.documents,
    )..where((d) => d.id.equals('real-document'))).getSingle();
    // Kept, and moved out of the folder that no longer exists.
    expect(doc.folderId, isNull);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  test('removes stale demo child rows before retrying generation', () async {
    await db
        .into(db.habits)
        .insert(
          HabitsCompanion.insert(
            id: const Value('demo-habit-water'),
            name: 'Stale water habit',
          ),
        );
    await db
        .into(db.habitLogs)
        .insert(
          HabitLogsCompanion.insert(
            id: const Value('demo-habit-log-water-0'),
            habitId: 'demo-habit-water',
            date: DateTime.now(),
          ),
        );

    final summary = await service.generate(months: 1);

    expect(summary.habitLogs, greaterThan(0));
    expect(await service.hasDemoData, isTrue);
    expect(
      await (db.select(
        db.habits,
      )..where((habit) => habit.name.equals('Stale water habit'))).get(),
      isEmpty,
    );
  });
}
