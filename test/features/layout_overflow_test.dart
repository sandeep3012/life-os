import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_manager/app/router/app_sidebar.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/reminders/reminder_mode.dart';
import 'package:life_manager/core/services/file_storage_service.dart';
import 'package:life_manager/core/services/notification_service.dart';
import 'package:life_manager/core/utils/date_utils.dart';
import 'package:life_manager/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:life_manager/features/finance/data/finance_repository.dart';
import 'package:life_manager/features/finance/presentation/screens/finance_overview_screen.dart';
import 'package:life_manager/features/finance/presentation/screens/net_worth_screen.dart';
import 'package:life_manager/features/health/presentation/screens/health_screen.dart';
import 'package:life_manager/features/habits/presentation/screens/habits_overview_screen.dart';
import 'package:life_manager/features/tasks/presentation/screens/tasks_habits_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class _FakeNotificationService extends NotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<void> scheduleDailyHabitReminder({int hour = 20, int minute = 0}) async {}

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

/// Guards the class of bug that kept reaching the device: a RenderFlex overflow
/// that `flutter analyze` can't see and no assertion notices unless something
/// explicitly fails the test on it.
///
/// `flutter_test` records layout overflows as exceptions but a widget test only
/// fails if they're surfaced, so each case asserts `takeException()` is null
/// after settling.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  /// The comp is drawn at 392x844 (iPhone 14 logical size). The default test
  /// viewport is 800x600 — wider and shorter than any phone — so a few-pixel
  /// horizontal overflow simply wouldn't reproduce there. Every case below runs
  /// at the real target size.
  void usePhoneViewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(392 * 3, 844 * 3);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget host(Widget screen, {String path = '/'}) {
    final router = GoRouter(
      initialLocation: path,
      routes: [
        GoRoute(path: path, builder: (context, state) => screen),
        GoRoute(path: '/other', builder: (context, state) => const SizedBox()),
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

  Future<void> disposeCleanly(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// Seeds enough finance history for the six-month bar chart and the net-worth
  /// line to actually render — an empty chart can't overflow.
  Future<void> seedFinance() async {
    final finance = FinanceRepository(db, FileStorageService());
    await finance.ensureDefaultCategories();
    await finance.createAccount(name: 'Checking', type: 'checking', balanceMinor: 500000);
    final accountId = (await db.select(db.accounts).get()).first.id;

    final today = dateOnly(DateTime.now());
    for (var monthsAgo = 0; monthsAgo < 6; monthsAgo++) {
      final when = DateTime(today.year, today.month - monthsAgo, 12);
      await finance.createTransaction(
        accountId: accountId,
        merchant: 'Rent',
        // Varying amounts so one month is the max and takes the accent bar.
        amountMinor: -(120000 + monthsAgo * 45000),
        date: when,
      );
      await finance.createTransaction(
        accountId: accountId,
        merchant: 'Salary',
        amountMinor: 900000,
        date: when,
      );
    }
  }

  testWidgets('finance overview lays out without overflow', (tester) async {
    usePhoneViewport(tester);
    await seedFinance();
    await tester.pumpWidget(host(const FinanceOverviewScreen()));
    await tester.pumpAndSettle();

    // The monthly-spending card sized its bars against a fixed reserve and
    // overflowed the card by a couple of pixels.
    expect(tester.takeException(), isNull);
    expect(find.text('Monthly spending'), findsOneWidget);

    await disposeCleanly(tester);
  });

  testWidgets('net worth chart stays inside its card', (tester) async {
    usePhoneViewport(tester);
    await seedFinance();
    await tester.pumpWidget(host(const NetWorthScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await disposeCleanly(tester);
  });

  testWidgets('tasks screen renders its rails and opens the sidebar', (tester) async {
    usePhoneViewport(tester);
    await db.into(db.tasks).insert(TasksCompanion.insert(title: 'Write spec'));
    await tester.pumpWidget(host(const TasksHabitsScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Both segmented controls are the comp's rail, which renders a visible
    // track — the Material SegmentedButton was invisible against the page.
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Habits'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);

    expect(find.byType(AppSidebar), findsNothing);
    await tester.tap(find.byIcon(LucideIcons.menu));
    await tester.pumpAndSettle();
    expect(find.byType(AppSidebar), findsOneWidget);

    await disposeCleanly(tester);
  });

  testWidgets('calendar screen opens the sidebar', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(host(const CalendarScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(LucideIcons.menu));
    await tester.pumpAndSettle();
    expect(find.byType(AppSidebar), findsOneWidget);

    await disposeCleanly(tester);
  });

  testWidgets('habits screen renders without overflow', (tester) async {
    usePhoneViewport(tester);
    await db.into(db.habits).insert(
      HabitsCompanion.insert(name: 'Morning workout', targetPerWeek: const Value(5)),
    );
    await tester.pumpWidget(host(const HabitsOverviewScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Habits'), findsOneWidget);

    await disposeCleanly(tester);
  });

  testWidgets('health screen renders both tabs without overflow', (tester) async {
    usePhoneViewport(tester);
    await db.into(db.medications).insert(
      MedicationsCompanion.insert(
        name: 'Vitamin D3',
        dosageNote: const Value('1 capsule · with breakfast'),
        stockLeft: const Value(4),
      ),
    );
    await tester.pumpWidget(host(const HealthScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Vitamin D3'), findsOneWidget);

    await tester.tap(find.text('Gym'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await disposeCleanly(tester);
  });
}
