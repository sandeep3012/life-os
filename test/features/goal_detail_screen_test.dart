import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/reminders/reminder_mode.dart';
import 'package:life_manager/core/services/notification_service.dart';
import 'package:life_manager/features/goals/data/goals_repository.dart';
import 'package:life_manager/features/goals/presentation/screens/goal_detail_screen.dart';

class _FakeNotificationService extends NotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<void> scheduleGoalReminder({
    required String goalId,
    required String title,
    required DateTime reminderTime,
    ReminderMode mode = ReminderMode.notification,
  }) async {}

  @override
  Future<void> cancelGoalReminder(String goalId) async {}
}

void main() {
  late AppDatabase db;
  late String goalId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = GoalsRepository(db);
    goalId = await repo.createGoal(title: 'Save for trip', targetValue: 1000, currentValue: 200);
  });

  tearDown(() => db.close());

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(_FakeNotificationService()),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: GoalDetailScreen(goalId: goalId)),
    );
  }

  testWidgets('editing via the app-bar button persists changes', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    // The detail screen's own milestone-add row also has a TextField, so
    // target the sheet's title field specifically by its prefilled value
    // rather than relying on tree order.
    final titleField = find.byWidgetPredicate(
      (w) => w is TextField && w.controller?.text == 'Save for trip',
    );
    await tester.enterText(titleField, 'Save for Japan trip');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Save for Japan trip'), findsWidgets);

    await _disposeCleanly(tester);
  });

  testWidgets('adding a milestone via the inline row shows it in the checklist', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Add a milestone'), 'Book flights');
    await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Book flights'), findsOneWidget);

    await _disposeCleanly(tester);
  });

  testWidgets('toggling a milestone checkbox marks it completed', (tester) async {
    final repo = GoalsRepository(db);
    await repo.createMilestone(goalId: goalId, title: 'Book flights');

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final milestones = await repo.watchMilestonesForGoal(goalId).first;
      expect(milestones.single.completed, isTrue);
    });

    await _disposeCleanly(tester);
  });

  testWidgets('deleting a milestone removes it', (tester) async {
    final repo = GoalsRepository(db);
    await repo.createMilestone(goalId: goalId, title: 'Book flights');

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Book flights'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Book flights'), findsNothing);

    await _disposeCleanly(tester);
  });

  testWidgets('reminder summary row shows the correct day-count text', (tester) async {
    final repo = GoalsRepository(db);
    await repo.updateGoal(
      id: goalId,
      title: 'Save for trip',
      type: 'generic',
      targetValue: 1000,
      targetDate: DateTime.now().add(const Duration(days: 30)),
      reminderEnabled: true,
      reminderDaysBefore: 3,
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Reminds you 3 days before the deadline'), findsOneWidget);

    await _disposeCleanly(tester);
  });
}

Future<void> _disposeCleanly(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}
