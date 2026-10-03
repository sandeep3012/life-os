import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/services/file_storage_service.dart';
import 'package:life_manager/features/finance/data/finance_repository.dart';
import 'package:life_manager/features/finance/presentation/screens/category_management_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The delete dialog used to say "used by 1 transaction/budget" for any
/// reference, including the invisible tombstone a deleted budget leaves behind.
void main() {
  late AppDatabase db;
  late FinanceRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FinanceRepository(db, FileStorageService());
  });

  tearDown(() => db.close());

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(392, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CategoryManagementScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }


  Future<void> disposeCleanly(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('a category with only a budget deletes, and says the budget goes too',
      (tester) async {
    final c = await repo.createCategory(
      name: 'Mobile/Broadband Recharge',
      icon: 'wifi',
      colorHex: '#0E9488',
    );
    await repo.createBudget(categoryId: c.id, limitMinor: 250000);
    await pumpScreen(tester);

    await tester.tap(find.byIcon(LucideIcons.trash2));
    await tester.pumpAndSettle();

    expect(find.text('Delete this category?'), findsOneWidget);
    // Says what is actually attached: a budget, not a transaction.
    expect(
      find.textContaining('has no transactions, but it has a monthly budget of'),
      findsOneWidget,
    );
    expect(find.textContaining('2,500'), findsOneWidget);
    expect(
      find.textContaining('Deleting the category will remove that budget too.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Mobile/Broadband Recharge'), findsNothing);
    expect(await db.select(db.categories).get(), isEmpty);
    expect(await db.select(db.budgets).get(), isEmpty);
    await disposeCleanly(tester);
  });

  testWidgets('a category with no budget just says it will be removed', (
    tester,
  ) async {
    await repo.createCategory(name: 'Shopping', icon: 'label', colorHex: '#E0475A');
    await pumpScreen(tester);

    await tester.tap(find.byIcon(LucideIcons.trash2));
    await tester.pumpAndSettle();

    expect(find.text('"Shopping" will be removed.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await disposeCleanly(tester);
  });

  testWidgets('a category with a transaction is blocked, and names transactions only', (
    tester,
  ) async {
    final c = await repo.createCategory(
      name: 'Groceries',
      icon: 'label',
      colorHex: '#2E9E63',
    );
    await repo.createAccount(name: 'Cash', type: 'Cash');
    final account = (await db.select(db.accounts).get()).single;
    await repo.createTransaction(
      accountId: account.id,
      categoryId: c.id,
      merchant: 'Shop',
      amountMinor: -10000,
      date: DateTime(2026, 10, 1),
    );
    await pumpScreen(tester);

    await tester.tap(find.byIcon(LucideIcons.trash2));
    await tester.pumpAndSettle();

    expect(find.text("Can't delete this category"), findsOneWidget);
    expect(find.textContaining('used by 1 transaction.'), findsOneWidget);
    expect(find.textContaining('budget'), findsNothing);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(await db.select(db.categories).get(), hasLength(1));
    await disposeCleanly(tester);
  });
}
