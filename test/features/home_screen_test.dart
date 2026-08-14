import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/services/file_storage_service.dart';
import 'package:life_manager/core/reminders/reminder_mode.dart';
import 'package:life_manager/core/services/notification_service.dart';
import 'package:life_manager/core/utils/date_utils.dart';
import 'package:life_manager/features/finance/data/finance_repository.dart';
import 'package:life_manager/features/habits/data/habits_repository.dart';
import 'package:life_manager/features/home/presentation/screens/home_screen.dart';

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

/// Drift schedules a zero-duration cleanup timer when a watched query's
/// stream is cancelled, which happens at ProviderScope teardown — after the
/// test body returns, where it can't be pumped away. Swapping in an empty
/// tree forces that teardown to happen while still inside the test.
Future<void> _disposeCleanly(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Widget buildApp() {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        GoRoute(path: '/finance', builder: (context, state) => const SizedBox()),
        GoRoute(path: '/tasks-habits', builder: (context, state) => const SizedBox()),
        GoRoute(path: '/calendar', builder: (context, state) => const SizedBox()),
        GoRoute(path: '/more/goals', builder: (context, state) => const SizedBox()),
      ],
    );
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(_FakeNotificationService()),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
  }

  testWidgets('empty install shows the onboarding dashboard state', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Your dashboard fills in as you go'), findsOneWidget);

    await _disposeCleanly(tester);
  });

  testWidgets('dashboard aggregates spend, tasks, habits and goals across modules', (
    tester,
  ) async {
    final today = dateOnly(DateTime.now());

    // Finance: one expense logged this week.
    final finance = FinanceRepository(db, FileStorageService());
    await finance.ensureDefaultCategories();
    await finance.createAccount(name: 'Checking', type: 'checking', balanceMinor: 500000);
    final accountId = (await db.select(db.accounts).get()).first.id;
    await finance.createTransaction(
      accountId: accountId,
      merchant: 'Swiggy',
      amountMinor: -64000,
      date: today,
    );

    // Tasks: one due today, still open.
    await db.into(db.tasks).insert(
      TasksCompanion.insert(
        title: 'Finish Q3 budget review',
        dueDate: Value(today.add(const Duration(hours: 17))),
      ),
    );

    // Habits: logged yesterday but not today, so it reads as at risk.
    final habits = HabitsRepository(db);
    await habits.createHabit('Morning workout');
    final habit = (await db.select(db.habits).get()).first;
    await habits.setCompletedForDate(
      habit.id,
      today.subtract(const Duration(days: 1)),
      true,
    );

    // Goals: one active.
    await db.into(db.goals).insert(GoalsCompanion.insert(title: 'Emergency Fund'));

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Your dashboard fills in as you go'), findsNothing);

    // Stat tiles pull from four different modules.
    expect(find.textContaining('₹640'), findsWidgets);
    expect(find.text('0 / 1'), findsOneWidget);
    expect(find.text('Active goals'), findsOneWidget);

    // Today's task and the at-risk habit both surface.
    expect(find.text('Finish Q3 budget review'), findsOneWidget);
    expect(find.text('Morning workout'), findsOneWidget);
    expect(find.textContaining('at risk'), findsOneWidget);

    await _disposeCleanly(tester);
  });

  testWidgets('checking off a task from the dashboard updates the tasks tile', (
    tester,
  ) async {
    final today = dateOnly(DateTime.now());
    await db.into(db.tasks).insert(
      TasksCompanion.insert(
        title: 'Call plumber',
        dueDate: Value(today.add(const Duration(hours: 11))),
      ),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('0 / 1'), findsOneWidget);

    await tester.tap(find.text('Call plumber'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('all done'), findsOneWidget);

    await _disposeCleanly(tester);
  });
}
