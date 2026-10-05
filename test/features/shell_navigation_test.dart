import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app.dart';
import 'package:life_manager/app/router/app_shell.dart';
import 'package:life_manager/app/router/app_sidebar.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/reminders/reminder_mode.dart';
import 'package:life_manager/core/services/notification_service.dart';
import 'package:life_manager/features/home/presentation/widgets/add_menu_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class _FakeNotificationService extends NotificationService {
  @override
  Future<void> init() async {}

  /// The app schedules this on its first frame. The real implementation reads
  /// `tz.local`, which throws a LateInitializationError unless the timezone
  /// database has been initialised — so any test that pumps the whole app has to
  /// stub it out.
  @override
  Future<void> scheduleDailyHabitReminder({
    int hour = 20,
    int minute = 0,
  }) async {}

  @override
  Future<void> cancelDailyHabitReminder() async {}

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

/// Covers the two chrome affordances the redesign introduced, both of which are
/// easy to break silently: the hamburger has to find the Scaffold that actually
/// owns the drawer, and the centre FAB has to present the add menu.
///
/// These are regression tests for two real bugs: `Tappable` used to await its
/// haptic before invoking `onTap`, so a throwing platform channel swallowed
/// every tap in the app; and the button theme's `minimumSize` used
/// `Size.fromHeight`, which demands infinite width and crashed any button
/// outside a width-bounded parent.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(
          _FakeNotificationService(),
        ),
      ],
      child: const LifeOSApp(),
    );
  }

  Future<void> disposeCleanly(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('the hamburger opens the sidebar drawer', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(AppSidebar), findsNothing);

    await tester.tap(find.byIcon(LucideIcons.menu));
    await tester.pumpAndSettle();

    expect(find.byType(AppSidebar), findsOneWidget);
    // Scoped to the drawer — 'Finance' also labels a nav-bar destination. Only
    // the first few rows are asserted: the drawer's ListView builds lazily, so
    // later destinations aren't in the tree at this viewport size.
    expect(
      find.descendant(
        of: find.byType(AppSidebar),
        matching: find.text('Finance home'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppSidebar),
        matching: find.text('Spend analyser'),
      ),
      findsOneWidget,
    );

    await disposeCleanly(tester);
  });

  testWidgets('the centre add button opens the add menu sheet', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(AddMenuSheet), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(AppFloatingNavBar),
        matching: find.byIcon(LucideIcons.plus),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AddMenuSheet), findsOneWidget);
    expect(find.text('What are we adding?'), findsOneWidget);
    // All six creation flows the build actually has.
    for (final label in [
      'Expense',
      'Income',
      'Habit',
      'Task',
      'Goal',
      'Account',
    ]) {
      expect(find.text(label), findsOneWidget, reason: '$label tile missing');
    }
    expect(find.text('Recurring'), findsNothing);

    await disposeCleanly(tester);
  });

  // Each tile has to reach its module's own sheet and save through that
  // module's controller — a tile that opens nothing is the failure mode this
  // guards against.
  for (final flow
      in <
        ({
          String tile,
          String submit,
          String name,
          Future<int> Function(AppDatabase) count,
        })
      >[
        (
          tile: 'Habit',
          submit: 'Add habit',
          name: 'Morning walk',
          count: (db) async => (await db.select(db.habits).get()).length,
        ),
        (
          tile: 'Task',
          submit: 'Add task',
          name: 'File taxes',
          count: (db) async => (await db.select(db.tasks).get()).length,
        ),
        (
          tile: 'Goal',
          submit: 'Add goal',
          name: 'Run a 10k',
          count: (db) async => (await db.select(db.goals).get()).length,
        ),
        (
          tile: 'Account',
          submit: 'Add account',
          name: 'Everyday card',
          count: (db) async => (await db.select(db.accounts).get()).length,
        ),
      ]) {
    testWidgets('the add menu creates a ${flow.tile.toLowerCase()}', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AppFloatingNavBar),
          matching: find.byIcon(LucideIcons.plus),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(flow.tile));
      // The menu waits for its own dismissal before opening the next sheet.
      await tester.pumpAndSettle();

      expect(
        find.text(flow.submit),
        findsOneWidget,
        reason: '${flow.tile} tile did not open its sheet',
      );
      await tester.enterText(find.byType(TextField).first, flow.name);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text(flow.submit));
      await tester.tap(find.text(flow.submit));
      await tester.pumpAndSettle();

      expect(find.text(flow.submit), findsNothing);
      expect(
        await flow.count(db),
        1,
        reason: '${flow.tile} sheet did not persist through its controller',
      );

      await disposeCleanly(tester);
    });
  }

  testWidgets('the sidebar opens the transfer dialog and the transfer lands', (
    tester,
  ) async {
    // The confirmation card, rather than the default save ripple, so the
    // acknowledgement can be asserted.
    await db
        .into(db.appSettings)
        .insert(
          const AppSettingsCompanion(
            id: Value(0),
            saveAnimationsEnabled: Value(false),
            saveConfirmationsEnabled: Value(true),
          ),
        );
    final from = await db
        .into(db.accounts)
        .insertReturning(
          AccountsCompanion.insert(
            name: 'Wallet',
            type: 'cash',
            balanceMinor: const Value(50000),
          ),
        );
    final to = await db
        .into(db.accounts)
        .insertReturning(
          AccountsCompanion.insert(
            name: 'Savings',
            type: 'savings',
            balanceMinor: const Value(10000),
          ),
        );
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.menu));
    await tester.pumpAndSettle();
    final item = find.descendant(
      of: find.byType(AppSidebar),
      matching: find.text('Transfer money'),
    );
    await tester.scrollUntilVisible(
      item,
      200,
      scrollable: find
          .descendant(
            of: find.byType(AppSidebar),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(item);
    await tester.pumpAndSettle();

    // The drawer has closed — and taken the sidebar with it — before the
    // dialog opens; that used to break the dialog's provider reads.
    expect(find.byType(AppSidebar), findsNothing);
    expect(find.widgetWithText(AlertDialog, 'Transfer money'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '150');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Transfer'));
    await tester.pumpAndSettle();

    // The dialog closing is acknowledged, not silent.
    expect(find.text('Transfer complete'), findsOneWidget);
    expect(
      find.text('₹150.00 moved from Wallet to Savings.'),
      findsOneWidget,
    );
    // Let the card dismiss itself before the test ends.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    Future<int> balance(String id) async => (await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(id))).getSingle()).balanceMinor;
    // ₹150 leaves Wallet and arrives in Savings.
    expect(await balance(from.id), 50000 - 15000);
    expect(await balance(to.id), 10000 + 15000);

    await disposeCleanly(tester);
  });
}
