import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/utils/date_utils.dart';
import 'package:life_manager/core/widgets/compact_editor_sheet.dart';
import 'package:life_manager/features/health/data/health_repository.dart';
import 'package:life_manager/features/health/presentation/screens/health_screen.dart';
import 'package:life_manager/features/learn/application/learn_providers.dart';
import 'package:life_manager/features/learn/data/learn_repository.dart';

/// Editing existing Learn notes, medications and exercises — none of which
/// was possible before — plus the exercise row's long-press, which used to
/// delete an exercise and all its logged sets with no confirmation.
void main() {
  group('note body round trip', () {
    test('paragraphs, quotes and code survive an edit unchanged', () {
      const blocks = [
        NoteBlock(type: 'p', text: 'First paragraph.'),
        NoteBlock(type: 'quote', text: 'A two-line\nquotation.'),
        NoteBlock(type: 'code', text: 'final a = 1;\n\nfinal b = 2;'),
        NoteBlock(type: 'p', text: 'Closing line.'),
      ];
      final text = NoteBlock.toEditableText(blocks);
      final back = NoteBlock.fromEditableText(text);

      expect(back.map((b) => b.type), ['p', 'quote', 'code', 'p']);
      expect(back.map((b) => b.text), blocks.map((b) => b.text));
    });

    test('a blank line inside a code fence stays inside the code', () {
      final back = NoteBlock.fromEditableText('```\nline one\n\nline two\n```');
      expect(back, hasLength(1));
      expect(back.single.type, 'code');
      expect(back.single.text, 'line one\n\nline two');
    });

    test('an unclosed fence still keeps what was typed', () {
      final back = NoteBlock.fromEditableText('Intro\n\n```\nstill typing');
      expect(back.map((b) => b.type), ['p', 'code']);
      expect(back.last.text, 'still typing');
    });

    test('plain text with no markup is a single paragraph', () {
      final back = NoteBlock.fromEditableText('Just some words.');
      expect(back.single.type, 'p');
      expect(back.single.text, 'Just some words.');
    });
  });

  group('updates', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('editing a note leaves its review schedule and star alone', () async {
      final repo = LearnRepository(db);
      final bookId = await repo.createBook(name: 'Book');
      final id = await repo.createNote(bookId: bookId, title: 'Old title');
      final due = DateTime(2031, 1, 1);
      final reviewed = DateTime(2030, 6, 1);
      await (db.update(db.learnNotes)..where((n) => n.id.equals(id))).write(
        LearnNotesCompanion(
          starred: const Value(true),
          reviewDueAt: Value(due),
          lastReviewedAt: Value(reviewed),
        ),
      );

      await repo.updateNote(
        id: id,
        bookId: bookId,
        title: 'New title',
        excerpt: 'e',
        bodyJson: '[]',
        prompt: 'p',
        tagsCsv: 't',
        minutes: 4,
      );

      final note = await (db.select(
        db.learnNotes,
      )..where((n) => n.id.equals(id))).getSingle();
      expect(note.title, 'New title');
      expect(note.starred, isTrue);
      expect(note.reviewDueAt, due);
      expect(note.lastReviewedAt, reviewed);
    });

    test(
      'editing an exercise keeps its day, position and logged sets',
      () async {
        final repo = HealthRepository(db);
        final dayId = await repo.createWorkoutDay(weekday: 1, label: 'Push');
        await repo.addExercise(
          workoutDayId: dayId,
          name: 'Bench',
          scheme: '3x10',
          position: 2,
        );
        final exercise = await db.select(db.exercises).getSingle();
        await db
            .into(db.exerciseSetLogs)
            .insert(
              ExerciseSetLogsCompanion.insert(
                exerciseId: exercise.id,
                date: dateOnly(DateTime.now()),
                setNumber: 1,
              ),
            );

        await repo.updateExercise(
          id: exercise.id,
          name: 'Incline bench',
          scheme: '4x8',
        );

        final after = await db.select(db.exercises).getSingle();
        expect(after.name, 'Incline bench');
        expect(after.scheme, '4x8');
        expect(after.workoutDayId, dayId);
        expect(after.position, 2);
        expect(await db.select(db.exerciseSetLogs).get(), hasLength(1));
      },
    );
  });

  group('health rows', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Widget host() => ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.light(), home: const HealthScreen()),
    );

    Future<void> disposeCleanly(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    }

    void usePhoneViewport(WidgetTester tester) {
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = const Size(392 * 3, 844 * 3);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('tapping a dose row edits; its checkbox marks it taken', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final semantics = tester.ensureSemantics();
      await HealthRepository(db).createMedication(name: 'Vitamin D3');
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      // The row body opens the editor, prefilled — the same split as a task.
      await tester.tap(find.text('Vitamin D3'));
      await tester.pumpAndSettle();
      expect(find.byType(CompactEditorSheet), findsOneWidget);
      expect(find.text('Edit medication'), findsOneWidget);
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();

      // The checkbox is its own target and records the dose.
      expect(await db.select(db.medicationLogs).get(), isEmpty);
      await tester.tap(find.bySemanticsLabel('Mark Vitamin D3 taken'));
      await tester.pumpAndSettle();
      final logs = await db.select(db.medicationLogs).get();
      expect(logs, hasLength(1));
      expect(logs.single.taken, isTrue);
      expect(find.byType(CompactEditorSheet), findsNothing);

      semantics.dispose();
      await disposeCleanly(tester);
    });

    Future<void> seedTodaysWorkout() async {
      final repo = HealthRepository(db);
      final dayId = await repo.createWorkoutDay(
        weekday: DateTime.now().weekday,
        label: 'Push',
      );
      await repo.addExercise(
        workoutDayId: dayId,
        name: 'Bench Press',
        scheme: '4x10',
        position: 0,
      );
    }

    testWidgets('tapping an exercise row opens its editor', (tester) async {
      usePhoneViewport(tester);
      await seedTodaysWorkout();
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gym'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bench Press'));
      await tester.pumpAndSettle();
      expect(find.text('Edit exercise'), findsOneWidget);
      // Prefilled with what's stored, not the add-sheet defaults.
      expect(find.widgetWithText(TextField, '4x10'), findsOneWidget);

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      await disposeCleanly(tester);
    });

    testWidgets('long-press no longer deletes an exercise without asking', (
      tester,
    ) async {
      usePhoneViewport(tester);
      await seedTodaysWorkout();
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gym'));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Bench Press'));
      await tester.pumpAndSettle();
      // An action sheet, not an immediate delete.
      expect(await db.select(db.exercises).get(), hasLength(1));
      expect(find.text('Delete exercise'), findsOneWidget);

      await tester.tap(find.text('Delete exercise'));
      await tester.pumpAndSettle();
      expect(find.text('Delete exercise?'), findsOneWidget);
      expect(await db.select(db.exercises).get(), hasLength(1));

      // Cancelling keeps it; confirming removes it.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await db.select(db.exercises).get(), hasLength(1));

      await tester.longPress(find.text('Bench Press'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete exercise'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(await db.select(db.exercises).get(), isEmpty);

      await disposeCleanly(tester);
    });
  });
}
