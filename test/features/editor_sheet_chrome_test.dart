import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/widgets/compact_editor_sheet.dart';
import 'package:life_manager/features/finance/presentation/widgets/quick_add_account_sheet.dart';
import 'package:life_manager/features/finance/presentation/widgets/quick_add_bill_sheet.dart';
import 'package:life_manager/features/finance/presentation/widgets/quick_add_recurring_transaction_sheet.dart';
import 'package:life_manager/features/goals/presentation/widgets/quick_add_goal_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Every creation sheet needs a way out and has to stay under the status bar.
/// These four opened as bare `showModalBottomSheet`s — no Cancel affordance,
/// and without `useSafeArea` a tall one ran up behind the system chrome.
void main() {
  late AppDatabase db;
  late List<Account> accounts;
  late List<AccountType> accountTypes;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.accounts)
        .insert(AccountsCompanion.insert(name: 'Wallet', type: 'cash'));
    accounts = await db.select(db.accounts).get();
    accountTypes = await db.select(db.accountTypes).get();
  });

  tearDown(() => db.close());

  /// Drift schedules a zero-duration cleanup timer when a watched query's
  /// stream is cancelled, which normally happens at ProviderScope teardown —
  /// after the test body returns, where flutter_test can't pump it away.
  Future<void> disposeCleanly(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// A notch-sized top inset, so a sheet that ignores it is visibly wrong.
  const padding = EdgeInsets.only(top: 47, bottom: 34);

  Future<void> pumpHost(
    WidgetTester tester,
    Future<void> Function(BuildContext) open,
  ) async {
    tester.view.physicalSize = const Size(392, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(padding: padding),
            child: child!,
          ),
          home: Scaffold(
            appBar: AppBar(title: const Text('Host')),
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => open(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  final sheets = <String, Future<void> Function(BuildContext)>{
    'recurring transaction': (context) async =>
        showQuickAddRecurringTransactionSheet(
          context,
          accounts: accounts,
          accountTypes: accountTypes,
          categories: const [],
          currencySymbol: '₹',
        ),
    'bill': (context) async => showQuickAddBillSheet(
      context,
      accounts: accounts,
      accountTypes: accountTypes,
      categories: const [],
      currencySymbol: '₹',
    ),
    'account': (context) async => showQuickAddAccountSheet(
      context,
      accountTypes: accountTypes,
      currencySymbol: '₹',
    ),
    'goal': (context) async => showQuickAddGoalSheet(
      context,
      habits: const [],
      accounts: accounts,
      currencySymbol: '₹',
    ),
  };

  for (final entry in sheets.entries) {
    testWidgets('the ${entry.key} sheet can be cancelled and clears the '
        'status bar', (tester) async {
      await pumpHost(tester, entry.value);

      expect(find.byType(CompactEditorSheet), findsOneWidget);

      // Never starts above the system inset.
      final sheetTop = tester
          .getTopLeft(find.byType(CompactEditorSheet))
          .dy;
      expect(
        sheetTop,
        greaterThanOrEqualTo(padding.top),
        reason: 'sheet ran up behind the status bar',
      );

      final cancel = find.byTooltip('Cancel');
      expect(cancel, findsOneWidget, reason: 'no way to dismiss the sheet');

      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.byType(CompactEditorSheet), findsNothing);

      await disposeCleanly(tester);
    });
  }

  testWidgets('recurring transactions pick expense or income on a visible '
      'rail', (tester) async {
    await pumpHost(tester, sheets['recurring transaction']!);

    // Material's SegmentedButton renders no track in this design, so the
    // choice used to read as two pieces of plain text.
    expect(find.byType(SegmentedButton<bool>), findsNothing);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.byIcon(LucideIcons.arrowDownLeft), findsOneWidget);
    expect(find.byIcon(LucideIcons.arrowUpRight), findsOneWidget);

    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await disposeCleanly(tester);
  });
}
