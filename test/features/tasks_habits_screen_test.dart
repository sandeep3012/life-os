import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/reminders/reminder_mode.dart';
import 'package:life_manager/core/services/notification_service.dart';
import 'package:life_manager/features/habits/data/habits_repository.dart';
import 'package:life_manager/features/habits/presentation/screens/archived_habits_screen.dart';
import 'package:life_manager/features/tasks/presentation/screens/tasks_habits_screen.dart';

class _FakeNotificationService extends NotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required DateTime dueDate,
    ReminderMode mode = ReminderMode.notification,
  }) async {}

  @override
  Future<void> cancelTaskReminder(String taskId) async {}
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Widget buildApp({bool initialHabitsTab = false}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(
          _FakeNotificationService(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: TasksHabitsScreen(initialHabitsTab: initialHabitsTab),
      ),
    );
  }

  testWidgets(
    'adding a task shows it in the sectioned list and can be checked off',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('No tasks here.'), findsOneWidget);

      // With the list this short the dashed "Build a new task" row is on
      // screen, so it stands in for the FAB — only one add affordance shows.
      expect(find.text('Build a new task'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      await tester.tap(find.text('Build a new task'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        'Finish Q3 budget review',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Add task'));
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();

      expect(find.text('Finish Q3 budget review'), findsOneWidget);

      await tester.tap(find.byTooltip('Mark complete'));
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text('Finish Q3 budget review'));
      expect(text.style?.decoration, TextDecoration.lineThrough);

      await _disposeCleanly(tester);
    },
  );

  testWidgets(
    'switching to Habits and adding one shows it with a 0-day streak',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Habits'));
      await tester.pumpAndSettle();

      expect(
        find.text('No habits yet — add one to start a streak.'),
        findsOneWidget,
      );

      expect(find.byType(FloatingActionButton), findsNothing);
      await tester.tap(find.text('Build a new habit'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Morning workout');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Add habit'));
      await tester.tap(find.text('Add habit'));
      await tester.pumpAndSettle();

      expect(find.text('Morning workout'), findsOneWidget);

      await _disposeCleanly(tester);
    },
  );

  testWidgets('the Planner can open directly on the Habits tab', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(initialHabitsTab: true));
    await tester.pumpAndSettle();

    expect(find.text('Build a new habit'), findsOneWidget);
    expect(
      find.text('No habits yet — add one to start a streak.'),
      findsOneWidget,
    );

    await _disposeCleanly(tester);
  });

  testWidgets(
    'a long task list shows the FAB until the inline add row scrolls into view',
    (tester) async {
      // Pin a phone-sized surface so 30 rows genuinely overflow the viewport.
      tester.view.physicalSize = const Size(392, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final today = DateTime.now();
      for (var i = 0; i < 30; i++) {
        await db
            .into(db.tasks)
            .insert(
              TasksCompanion.insert(
                title: 'Task $i',
                dueDate: Value(DateTime(today.year, today.month, today.day)),
              ),
            );
      }

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // The dashed row exists at the end of the list but is off screen, so the
      // FAB is the visible affordance.
      expect(find.byType(FloatingActionButton), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Build a new task'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Once the row is on screen the FAB steps aside.
      expect(find.byType(FloatingActionButton), findsNothing);

      await _disposeCleanly(tester);
    },
  );

  testWidgets('archived habits have a titled screen and a Back button', (
    tester,
  ) async {
    final repository = HabitsRepository(db);
    await repository.createHabit('Read daily');
    final habit = (await db.select(db.habits).getSingle());
    await repository.archiveHabit(habit.id);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ArchivedHabitsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Archived habits'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('Read daily'), findsOneWidget);
    expect(find.text('Unarchive'), findsOneWidget);

    await _disposeCleanly(tester);
  });
}

/// Drift schedules a zero-duration cleanup [Timer] when a watched query's
/// stream is cancelled (see `QueryStream._onCancelOrPause`), which normally
/// happens when [ProviderScope] disposes at widget-tree teardown. In
/// `flutter_test` that teardown runs *after* the test body returns, so the
/// timer can't be pumped away from there — swap in an empty tree here to
/// force disposal (and the timer) to happen while still inside the test.
Future<void> _disposeCleanly(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}
