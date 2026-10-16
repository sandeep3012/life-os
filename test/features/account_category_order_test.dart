import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/features/finance/application/finance_providers.dart';
import 'package:life_manager/core/widgets/reorder_card.dart';
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

  test('a new entry starts on the top account that can take a payment',
      () async {
    final repo = container.read(financeRepositoryProvider);
    await repo.createAccount(name: 'Shares', type: 'investment');
    await repo.createAccount(name: 'A', type: 'savings');
    await repo.createAccount(name: 'B', type: 'cash');
    final ids = await accountIds();

    // Shares is on top, but an investment can't pay for anything.
    expect(await settled(preferredAccountIdProvider), ids['A']);

    // Using B doesn't change it — only the order does.
    await repo.createTransaction(
      accountId: ids['B']!,
      merchant: 'Tea',
      amountMinor: -2000,
      date: DateTime(2026, 9, 1),
    );
    expect(await settled(preferredAccountIdProvider), ids['A']);

    await controller().reorderAccounts([ids['B']!, ids['Shares']!, ids['A']!]);
    expect(await settled(preferredAccountIdProvider), ids['B']);
  });

  test('starting values fall back to the first offered', () {
    Account account(String id) => Account(
      id: id,
      name: id,
      type: 'cash',
      balanceMinor: 0,
      openingBalanceMinor: 0,
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
    expect(startingCategoryId(const []), isNull);
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

  testWidgets('dragging an account to the top makes it the default', (
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
    expect(
      find.textContaining('Hold any account and drag it'),
      findsOneWidget,
    );

    String? defaultName() {
      final card = find.ancestor(
        of: find.text('Default'),
        matching: find.byType(ReorderCard),
      );
      return tester.widget<ReorderCard>(card).title;
    }

    expect(defaultName(), 'Wallet');

    // Drag Bank's grip above Wallet.
    final grip = find.byTooltip('Drag to reorder Bank');
    final gesture = await tester.startGesture(tester.getCenter(grip));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(defaultName(), 'Bank');
    final ordered = await (db.select(
      db.accounts,
    )..orderBy([(a) => OrderingTerm.asc(a.position)])).get();
    expect(ordered.map((a) => a.name), ['Bank', 'Wallet']);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
