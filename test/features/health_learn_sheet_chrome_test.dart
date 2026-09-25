import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/widgets/compact_editor_sheet.dart';
import 'package:life_manager/features/health/data/health_repository.dart';
import 'package:life_manager/features/health/presentation/widgets/add_exercise_sheet.dart';
import 'package:life_manager/features/health/presentation/widgets/log_set_sheet.dart';
import 'package:life_manager/features/health/presentation/widgets/medication_editor_sheet.dart';
import 'package:life_manager/features/health/presentation/widgets/workout_plan_sheet.dart';
import 'package:life_manager/features/learn/presentation/widgets/note_editor_sheet.dart';

/// Health and Learn originally hand-rolled their own sheet chrome — a drag
/// handle and a bare title, with no way out but the system back gesture or a
/// tap on the barrier. Habits and Tasks use [CompactEditorSheet], which carries
/// a Cancel button. These assert the two modules now go through the same shell,
/// so a new sheet can't quietly reintroduce a dead end.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Widget host(void Function(BuildContext, WidgetRef) onPressed) {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Consumer(
            // A real launcher, so the sheet is pushed onto a live Navigator
            // exactly as the screens push it — and the save acknowledgement
            // the helpers now show needs a WidgetRef from the caller.
            builder: (context, ref, _) => TextButton(
              onPressed: () => onPressed(context, ref),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> disposeCleanly(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// Opens the sheet, checks it went through the shared shell and offers a way
  /// out, then checks that way out actually closes it.
  Future<void> expectCancellableSheet(
    WidgetTester tester, {
    required String title,
  }) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.byType(CompactEditorSheet),
      findsOneWidget,
      reason: '"$title" should use the shared editor shell',
    );
    expect(find.text(title), findsOneWidget);

    final cancel = find.byTooltip('Cancel');
    expect(cancel, findsOneWidget, reason: '"$title" has no Cancel button');

    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(
      find.byType(CompactEditorSheet),
      findsNothing,
      reason: 'Cancel did not dismiss "$title"',
    );
  }

  testWidgets('the medication sheet can be cancelled', (tester) async {
    await tester.pumpWidget(host((c, r) => showMedicationEditorSheet(c, r)));
    await expectCancellableSheet(tester, title: 'New medication');
    await disposeCleanly(tester);
  });

  testWidgets('the training session sheet can be cancelled', (tester) async {
    await tester.pumpWidget(host((c, r) => showWorkoutPlanSheet(c, r)));
    await expectCancellableSheet(tester, title: 'New training session');
    await disposeCleanly(tester);
  });

  testWidgets('the add-exercise sheet can be cancelled', (tester) async {
    final repo = HealthRepository(db);
    final dayId = await repo.createWorkoutDay(
      weekday: DateTime.now().weekday,
      label: 'Push Day',
      focus: 'Chest',
    );
    await tester.pumpWidget(
      host(
        (c, r) => showAddExerciseSheet(c, r, workoutDayId: dayId, position: 0),
      ),
    );
    await expectCancellableSheet(tester, title: 'Add an exercise');
    await disposeCleanly(tester);
  });

  testWidgets('the log-set sheet can be cancelled', (tester) async {
    final repo = HealthRepository(db);
    final dayId = await repo.createWorkoutDay(
      weekday: DateTime.now().weekday,
      label: 'Push Day',
      focus: 'Chest',
    );
    await repo.addExercise(
      workoutDayId: dayId,
      name: 'Bench Press',
      scheme: '4x10',
      position: 0,
    );
    final exercise = await db.select(db.exercises).getSingle();
    await tester.pumpWidget(host((c, r) => showLogSetSheet(c, exercise)));
    await expectCancellableSheet(tester, title: 'Bench Press');
    await disposeCleanly(tester);
  });

  testWidgets('the note sheet can be cancelled', (tester) async {
    await tester.pumpWidget(host((c, r) => showNoteEditorSheet(c, r)));
    await expectCancellableSheet(tester, title: 'New note');
    await disposeCleanly(tester);
  });
}
