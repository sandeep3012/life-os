import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/features/finance/application/finance_providers.dart';
import 'package:life_manager/features/finance/presentation/screens/account_order_screen.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  FinanceController controller() => container.read(financeControllerProvider);

  Future<Map<String, String>> accountIds() async => {
    for (final a in await db.select(db.accounts).get()) a.name: a.id,
  };

  /// Waits for the stream behind [provider] to settle, then reads it.
  Future<T> settled<T>(Provider<T> provider) async {
    // Held open for the read: an unlistened stream provider is torn down
    // before its first value arrives.
    final subs = [
      container.listen(provider, (_, _) {}),
      container.listen(accountsProvider, (_, _) {}),
      container.listen(transactionsProvider, (_, _) {}),
    ];
    await container.read(accountsProvider.future);
    await container.read(transactionsProvider.future);
    // Let a write made just before this reach the streams.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final value = container.read(provider);
    for (final sub in subs) {
      sub.close();
    }
    return value;
  }

  test('new accounts and categories go to the end, and reorder sticks', () async {
    final repo = container.read(financeRepositoryProvider);
    await repo.createAccount(name: 'A', type: 'savings');
    await repo.createAccount(name: 'B', type: 'cash');
    await repo.createAccount(name: 'C', type: 'savings');
    var accounts = await repo.watchAccounts().first;
    expect(accounts.map((a) => a.name), ['A', 'B', 'C']);

    final ids = await accountIds();
    await controller().reorderAccounts([ids['C']!, ids['A']!, ids['B']!]);
    accounts = await repo.watchAccounts().first;
    expect(accounts.map((a) => a.name), ['C', 'A', 'B']);

    final before = (await repo.watchCategories().first).length;
    final food = await repo.createCategory(
      name: 'Zz food',
      icon: 'utensils',
      colorHex: '#E0475A',
    );
    final categories = await repo.watchCategories().first;
    expect(categories.last.id, food.id);
    expect(categories.length, before + 1);

    final moved = [food.id, ...categories.take(before).map((c) => c.id)];
    await controller().reorderCategories(moved);
    expect((await repo.watchCategories().first).first.id, food.id);
  });

  test('only one account is ever the default', () async {
    final repo = container.read(financeRepositoryProvider);
    await repo.createAccount(name: 'A', type: 'savings');
    await repo.createAccount(name: 'B', type: 'cash');
    final ids = await accountIds();

    await controller().setDefaultAccount(ids['A']);
    await controller().setDefaultAccount(ids['B']);
    var accounts = await repo.watchAccounts().first;
    expect({for (final a in accounts) a.name: a.isDefault}, {
      'A': false,
      'B': true,
    });

    await controller().setDefaultAccount(null);
    accounts = await repo.watchAccounts().first;
    expect(accounts.any((a) => a.isDefault), isFalse);
  });

  test('a new entry starts on the default, else the last used, else the first',
      () async {
    final repo = container.read(financeRepositoryProvider);
    await repo.createAccount(name: 'A', type: 'savings');
    await repo.createAccount(name: 'B', type: 'cash');
    final ids = await accountIds();

    expect(await settled(preferredAccountIdProvider), ids['A']);

    await repo.createTransaction(
      accountId: ids['B']!,
      merchant: 'Tea',
      amountMinor: -2000,
      date: DateTime(2026, 9, 1),
    );
    expect(await settled(preferredAccountIdProvider), ids['B']);

    await controller().setDefaultAccount(ids['A']);
    expect(await settled(preferredAccountIdProvider), ids['A']);
  });

  test('the category starts on the last one used for that kind', () async {
    final repo = container.read(financeRepositoryProvider);
    await repo.createAccount(name: 'A', type: 'savings');
    final account = (await accountIds())['A']!;
    final food = await repo.createCategory(
      name: 'Food',
      icon: 'utensils',
      colorHex: '#E0475A',
    );
    final salary = await repo.createCategory(
      name: 'Pay',
      icon: 'wallet',
      colorHex: '#2E9E63',
      kind: 'income',
    );

    expect(await settled(lastUsedCategoryIdProvider(true)), isNull);

    await repo.createTransaction(
      accountId: account,
      categoryId: food.id,
      merchant: 'Lunch',
      amountMinor: -15000,
      date: DateTime(2026, 9, 2),
    );
    await repo.createTransaction(
      accountId: account,
      categoryId: salary.id,
      merchant: 'Salary',
      amountMinor: 5000000,
      date: DateTime(2026, 8, 1), // back-dated, but still the latest entry
    );
    expect(await settled(lastUsedCategoryIdProvider(true)), food.id);
    expect(await settled(lastUsedCategoryIdProvider(false)), salary.id);
  });

  test('starting values fall back when the remembered one is not offered', () {
    Account account(String id) => Account(
      id: id,
      name: id,
      type: 'cash',
      balanceMinor: 0,
      currencyCode: 'INR',
      isActive: true,
      position: 0,
      isDefault: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final accounts = [account('x'), account('y')];
    expect(startingAccountId(accounts, 'y'), 'y');
    expect(startingAccountId(accounts, 'gone'), 'x');
    expect(startingAccountId(accounts, null), 'x');
    expect(startingCategoryId(const [], 'gone'), isNull);
  });

  test('upgrading to v33 numbers existing rows in their old order', () async {
    final dir = await Directory.systemTemp.createTemp('lifeos_order_');
    final file = File('${dir.path}/order.sqlite');
    var fileDb = AppDatabase.forTesting(NativeDatabase(file));
    try {
      for (final name in ['First', 'Second', 'Third']) {
        await fileDb
            .into(fileDb.accounts)
            .insert(AccountsCompanion.insert(name: name, type: 'cash'));
      }
      await fileDb.customStatement('ALTER TABLE accounts DROP COLUMN position');
      await fileDb.customStatement(
        'ALTER TABLE accounts DROP COLUMN is_default',
      );
      await fileDb.customStatement(
        'ALTER TABLE categories DROP COLUMN position',
      );
      await fileDb.customStatement('PRAGMA user_version = 32');
      await fileDb.close();

      fileDb = AppDatabase.forTesting(NativeDatabase(file));
      final rows = await fileDb.select(fileDb.accounts).get();
      expect({for (final a in rows) a.name: a.position}, {
        'First': 0,
        'Second': 1,
        'Third': 2,
      });
      expect(rows.any((a) => a.isDefault), isFalse);
      final categories = await fileDb.select(fileDb.categories).get();
      expect(
        categories.map((c) => c.position).toSet().length,
        categories.length,
      );
    } finally {
      await fileDb.close();
      await dir.delete(recursive: true);
    }
  });

  testWidgets('starring an account in Order & default makes it the default', (
    tester,
  ) async {
    await db
        .into(db.accounts)
        .insert(AccountsCompanion.insert(name: 'Wallet', type: 'cash'));
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            name: 'Bank',
            type: 'savings',
            position: const Value(1),
          ),
        );
    tester.view.physicalSize = const Size(392, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AccountOrderScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Default'), findsNothing);

    await tester.tap(find.byTooltip('Make Bank the default'));
    await tester.pumpAndSettle();
    expect(find.text('Default'), findsOneWidget);
    expect(find.byTooltip('Remove Bank as default'), findsOneWidget);
    final bank = await (db.select(
      db.accounts,
    )..where((a) => a.name.equals('Bank'))).getSingle();
    expect(bank.isDefault, isTrue);
    expect(find.byTooltip('Drag to reorder Wallet'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
