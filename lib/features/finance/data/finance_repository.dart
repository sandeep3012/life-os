import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

/// Default expense categories seeded on first launch, using the same hex
/// values as the prototype's validated spend-category palette
/// (`--cat-dining`, `--cat-groceries`, etc.) so a fresh install's Spend
/// Analyzer donut looks identical to the mock-up without any user setup.
const _defaultCategories = [
  ('Dining', 'restaurant', '#E0475A', 'expense'),
  ('Groceries', 'shopping_cart', '#2E9E63', 'expense'),
  ('Transport', 'directions_car', '#2F6FED', 'expense'),
  ('Rent', 'home', '#A67C00', 'expense'),
  ('Entertainment', 'movie', '#A63FBE', 'expense'),
  ('Subscriptions', 'autorenew', '#A63FBE', 'expense'),
  ('Other', 'category', '#8B84A3', 'expense'),
  ('Income', 'payments', '#1E8F5E', 'income'),
];

class FinanceRepository {
  FinanceRepository(this._db);

  final AppDatabase _db;

  Future<void> ensureDefaultCategories() async {
    final existing = await _db.select(_db.categories).get();
    if (existing.isNotEmpty) return;
    await _db.batch((batch) {
      batch.insertAll(_db.categories, [
        for (final (name, icon, color, kind) in _defaultCategories)
          CategoriesCompanion.insert(
            name: name,
            icon: Value(icon),
            colorHex: color,
            kind: Value(kind),
          ),
      ]);
    });
  }

  Stream<List<Category>> watchCategories() => _db.select(_db.categories).watch();

  Stream<List<Account>> watchAccounts() => _db.select(_db.accounts).watch();

  Stream<List<Transaction>> watchTransactions() {
    return (_db.select(
      _db.transactions,
    )..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();
  }

  Stream<List<Budget>> watchBudgets() => _db.select(_db.budgets).watch();

  Future<void> createAccount({
    required String name,
    required String type,
    int balanceMinor = 0,
  }) {
    return _db.into(_db.accounts).insert(
      AccountsCompanion.insert(
        name: name,
        type: type,
        balanceMinor: Value(balanceMinor),
      ),
    );
  }

  Future<void> createTransaction({
    required String accountId,
    String? categoryId,
    required String merchant,
    required int amountMinor,
    required DateTime date,
    String? note,
  }) {
    return _db.transaction(() async {
      await _db.into(_db.transactions).insert(
        TransactionsCompanion.insert(
          accountId: accountId,
          categoryId: Value(categoryId),
          merchant: merchant,
          amountMinor: amountMinor,
          date: date,
          note: Value(note),
        ),
      );
      final account = await (_db.select(
        _db.accounts,
      )..where((a) => a.id.equals(accountId))).getSingle();
      await (_db.update(_db.accounts)..where((a) => a.id.equals(accountId))).write(
        AccountsCompanion(
          balanceMinor: Value(account.balanceMinor + amountMinor),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> createBudget({
    required String categoryId,
    required int limitMinor,
    String period = 'monthly',
    DateTime? startDate,
  }) {
    return _db.into(_db.budgets).insert(
      BudgetsCompanion.insert(
        categoryId: categoryId,
        limitMinor: limitMinor,
        period: Value(period),
        startDate: startDate ?? DateTime.now(),
      ),
    );
  }
}
