import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/services/file_storage_service.dart';
import 'package:life_manager/features/finance/data/finance_repository.dart';

void main() {
  late AppDatabase db;
  late FinanceRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FinanceRepository(db, FileStorageService());
  });

  tearDown(() => db.close());

  test('watchCategories excludes non-finance kinds like habit', () async {
    await repo.createCategory(name: 'Groceries', icon: 'shopping_cart', colorHex: '#2E9E63');
    await repo.createCategory(
      name: 'Salary',
      icon: 'payments',
      colorHex: '#1E8F5E',
      kind: 'income',
    );
    // Not created through FinanceRepository — simulates a habit category
    // row existing in the same shared Categories table.
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: 'Fitness',
            colorHex: '#2E9E63',
            kind: const Value('habit'),
          ),
        );

    final categories = await repo.watchCategories().first;
    expect(categories, hasLength(2));
    expect(categories.map((c) => c.kind), everyElement(isIn(['expense', 'income'])));
    expect(categories.map((c) => c.name), isNot(contains('Fitness')));
  });

  group('deleting a category', () {
    Future<String> category(String name) async =>
        (await repo.createCategory(
          name: name,
          icon: 'wifi',
          colorHex: '#0E9488',
        )).id;

    Future<List<Budget>> budgetsOf(String categoryId) => (db.select(
      db.budgets,
    )..where((b) => b.categoryId.equals(categoryId))).get();

    test('is not blocked by a budget the user already deleted', () async {
      // Regression: deleting a budget that has earlier history leaves an
      // `active = false` tombstone row. Those were counted as "in use", so the
      // category refused to delete with nothing visible attached to it.
      final id = await category('Mobile/Broadband Recharge');
      final lastMonth = DateTime(DateTime.now().year, DateTime.now().month - 1);
      await repo.createBudget(
        categoryId: id,
        limitMinor: 250000,
        effectiveMonth: lastMonth,
      );
      await repo.createBudget(categoryId: id, limitMinor: 250000);
      final thisMonth = (await budgetsOf(id)).firstWhere(
        (b) => b.effectiveMonth!.month == DateTime.now().month,
      );
      await repo.deleteBudget(thisMonth.id);

      // The tombstone really is there, and invisible as an active budget.
      expect(await budgetsOf(id), hasLength(2));
      expect(await repo.categoryActiveBudget(id), isNull);
      expect(await repo.categoryTransactionCount(id), 0);

      await repo.deleteCategory(id);

      expect(await budgetsOf(id), isEmpty);
      expect(
        await (db.select(db.categories)..where((c) => c.id.equals(id))).get(),
        isEmpty,
      );
    });

    test('removes a live budget along with the category', () async {
      final id = await category('Mobile/Broadband Recharge');
      await repo.createBudget(categoryId: id, limitMinor: 250000);

      expect((await repo.categoryActiveBudget(id))?.limitMinor, 250000);
      expect(await repo.categoryTransactionCount(id), 0);

      await repo.deleteCategory(id);

      expect(await budgetsOf(id), isEmpty);
    });

    test('is still blocked by a real transaction', () async {
      final id = await category('Groceries');
      await repo.createAccount(name: 'Cash', type: 'Cash');
      final account = (await db.select(db.accounts).get()).single;
      await repo.createTransaction(
        accountId: account.id,
        categoryId: id,
        merchant: 'Shop',
        amountMinor: -10000,
        date: DateTime(2026, 10, 1),
      );

      expect(await repo.categoryTransactionCount(id), 1);
      await expectLater(repo.deleteCategory(id), throwsStateError);
      expect(
        await (db.select(db.categories)..where((c) => c.id.equals(id))).get(),
        hasLength(1),
      );
    });

    test('clears the category from bills, recurring items, habits and tasks',
        () async {
      final id = await category('Mobile/Broadband Recharge');
      await repo.createAccount(name: 'Cash', type: 'Cash');
      final account = (await db.select(db.accounts).get()).single;
      final bill = await repo.createBill(
        name: 'Broadband',
        accountId: account.id,
        categoryId: id,
        amountMinor: 79900,
        dueDate: DateTime(2026, 10, 10),
      );
      await repo.createRecurringTransaction(
        accountId: account.id,
        categoryId: id,
        merchant: 'Recharge',
        amountMinor: -29900,
        frequency: 'monthly',
        startDate: DateTime(2026, 10, 1),
      );
      await db.into(db.tasks).insert(
        TasksCompanion.insert(title: 'Pay', categoryId: Value(id)),
      );
      await db.into(db.habits).insert(
        HabitsCompanion.insert(name: 'Habit', categoryId: Value(id)),
      );

      await repo.deleteCategory(id);

      final billAfter = await (db.select(db.bills)
            ..where((b) => b.id.equals(bill.id)))
          .getSingle();
      expect(billAfter.categoryId, isNull);
      expect((await db.select(db.recurringTransactions).get()).single.categoryId,
          isNull);
      expect((await db.select(db.tasks).get()).single.categoryId, isNull);
      expect((await db.select(db.habits).get()).single.categoryId, isNull);
    });
  });
}
