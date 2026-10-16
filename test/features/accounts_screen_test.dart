import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/features/finance/presentation/screens/accounts_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> account(
    String name,
    String type,
    int balance, {
    bool active = true,
  }) => db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          name: name,
          type: type,
          balanceMinor: Value(balance),
          isActive: Value(active),
        ),
      );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(392, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AccountsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> disposeCleanly(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('groups accounts by type with totals and net worth', (
    tester,
  ) async {
    await account('HDFC Savings', 'savings', 8750000);
    await account('SBI Savings', 'savings', 1250000);
    await account('Wallet', 'cash', 300000);
    await account('Rewards card', 'credit card', -1500000);
    await account('Old account', 'savings', 100000, active: false);
    await pump(tester);

    // Net worth: 1,00,000 + 3,000 − 15,000.
    expect(find.text('₹88,000'), findsOneWidget);
    expect(find.text('₹1,03,000'), findsOneWidget); // assets
    expect(find.text('₹15,000'), findsOneWidget); // owed on cards

    expect(find.text('Savings'), findsOneWidget);
    expect(find.text('₹1,00,000'), findsOneWidget); // savings group total
    expect(find.text('HDFC Savings'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);

    // Archived accounts fold away until asked for.
    await tester.scrollUntilVisible(find.text('Archived (1)'), 200);
    expect(find.text('Old account'), findsNothing);
    await tester.tap(find.text('Archived (1)'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Old account'), 200);
    expect(find.text('Old account'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await disposeCleanly(tester);
  });

  testWidgets('hiding balances masks every amount', (tester) async {
    await account('Wallet', 'cash', 250000);
    await pump(tester);
    expect(find.text('₹2,500'), findsWidgets);

    await tester.tap(find.byTooltip('Hide balances'));
    await tester.pumpAndSettle();
    expect(find.text('₹2,500'), findsNothing);
    await disposeCleanly(tester);
  });

  testWidgets('no accounts shows how to add one', (tester) async {
    await pump(tester);
    expect(find.text('Add account'), findsOneWidget);
    await disposeCleanly(tester);
  });
}
