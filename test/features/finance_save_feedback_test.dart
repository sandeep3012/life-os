import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/reminders/reminder_mode.dart';
import 'package:life_manager/core/services/notification_service.dart';
import 'package:life_manager/core/widgets/success_overlay.dart';
import 'package:life_manager/features/finance/application/finance_providers.dart';
import 'package:life_manager/features/finance/presentation/screens/bills_screen.dart';
import 'package:life_manager/features/finance/presentation/screens/recurring_transactions_screen.dart';
import 'package:life_manager/features/settings/application/settings_providers.dart';

class _FakeNotifications extends NotificationService {
  @override
  Future<void> init() async {}
  @override
  Future<void> scheduleBillReminder({
    required String billId,
    required String title,
    required DateTime reminderTime,
    ReminderMode mode = ReminderMode.notification,
  }) async {}
  @override
  Future<void> cancelBillReminder(String billId) async {}
}

/// Saving a bill or a recurring transaction now acknowledges itself the same
/// way tasks, habits and goals do — these two flows were the ones still
/// finishing silently.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.accounts)
        .insert(AccountsCompanion.insert(name: 'Wallet', type: 'cash'));
  });

  tearDown(() => db.close());

  Future<void> pumpHost(
    WidgetTester tester,
    void Function(BuildContext, WidgetRef) open,
  ) async {
    tester.view.physicalSize = const Size(392, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notificationServiceProvider.overrideWithValue(_FakeNotifications()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                // openSheet reads accounts rather than watching them, and an
                // unlistened StreamProvider is torn down before it emits — the
                // real screens keep it alive by watching it in build.
                ref.watch(accountsProvider);
                // Same reason: showSaveFeedback reads settings, and an
                // unwatched settings stream falls back to defaults, which
                // choose the animation branch instead of the overlay.
                ref.watch(settingsProvider);
                return TextButton(
                  onPressed: () => open(context, ref),
                  child: const Text('open'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Pumps far enough for the save to finish and the overlay to pop in, but
  /// not so far that its 1.9s dwell expires and removes it again.
  Future<void> settleUntilOverlay(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      if (find.byType(SuccessOverlay).evaluate().isNotEmpty) return;
    }
  }

  /// Lets the overlay's dwell timer fire. pumpAndSettle alone stops once the
  /// pop-in animation finishes, leaving the 1.9s Future.delayed pending and
  /// tripping the "Timer is still pending" assertion at teardown.
  Future<void> finishOverlay(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  Future<void> disposeCleanly(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// Confirmation mode is the one with something assertable on screen; the
  /// animation branch paints a transient wave and leaves no widget behind.
  Future<void> useConfirmations(WidgetTester tester) async {
    final context = tester.element(find.text('open'));
    final container = ProviderScope.containerOf(context);
    await container
        .read(settingsControllerProvider)
        .setSaveFeedbackMode(SaveFeedbackMode.confirmation);
    await tester.pumpAndSettle();
  }

  testWidgets('saving a bill acknowledges itself', (tester) async {
    await pumpHost(tester, (context, ref) => BillsScreen.openSheet(context, ref));
    await useConfirmations(tester);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Broadband');
    await tester.enterText(find.byType(TextField).at(1), '700');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Add bill'));
    await tester.tap(find.text('Add bill'));
    await settleUntilOverlay(tester);

    expect(find.byType(SuccessOverlay), findsOneWidget);
    expect(find.text('Bill saved'), findsOneWidget);
    expect((await db.select(db.bills).get()), hasLength(1));

    await finishOverlay(tester);
    await disposeCleanly(tester);
  });

  testWidgets('editing a bill says it updated, not saved', (tester) async {
    final bill = await db
        .into(db.bills)
        .insertReturning(
          BillsCompanion.insert(
            name: 'Broadband',
            amountMinor: 70000,
            dueDate: DateTime.now().add(const Duration(days: 5)),
          ),
        );

    await pumpHost(
      tester,
      (context, ref) => BillsScreen.openSheet(context, ref, existing: bill),
    );
    await useConfirmations(tester);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Edit bill'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Broadband 1Gbps');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await settleUntilOverlay(tester);

    expect(find.byType(SuccessOverlay), findsOneWidget);
    expect(find.text('Bill updated'), findsOneWidget);
    expect(find.text('Bill saved'), findsNothing);
    expect((await db.select(db.bills).getSingle()).name, 'Broadband 1Gbps');

    await finishOverlay(tester);
    await disposeCleanly(tester);
  });

  testWidgets('saving a recurring transaction acknowledges itself', (
    tester,
  ) async {
    await pumpHost(
      tester,
      (context, ref) => RecurringTransactionsScreen.openSheet(context, ref),
    );
    await useConfirmations(tester);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Netflix');
    await tester.enterText(find.byType(TextField).at(1), '499');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Add recurring transaction'));
    await tester.tap(find.text('Add recurring transaction'));
    await settleUntilOverlay(tester);

    expect(find.byType(SuccessOverlay), findsOneWidget);
    expect(find.text('Recurring transaction saved'), findsOneWidget);
    expect((await db.select(db.recurringTransactions).get()), hasLength(1));

    await finishOverlay(tester);
    await disposeCleanly(tester);
  });
}
