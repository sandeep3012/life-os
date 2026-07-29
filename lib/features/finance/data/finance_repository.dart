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

  /// How many other rows reference this account — the gate for whether it
  /// can be hard-deleted (only when both are zero) or must be deactivated
  /// instead.
  Future<({int transactionCount, int goalLinkCount})> checkAccountUsage(
    String accountId,
  ) async {
    final transactionCount = await (_db.select(
      _db.transactions,
    )..where((t) => t.accountId.equals(accountId))).get().then((r) => r.length);
    final goalLinkCount = await (_db.select(_db.goalLinks)..where(
          (l) => l.linkedType.equals('account') & l.linkedId.equals(accountId),
        ))
        .get()
        .then((r) => r.length);
    return (transactionCount: transactionCount, goalLinkCount: goalLinkCount);
  }

  /// Only safe to call once [checkAccountUsage] confirms nothing references
  /// this account — callers must check first, this doesn't re-verify.
  Future<void> deleteAccount(String accountId) {
    return (_db.delete(_db.accounts)..where((a) => a.id.equals(accountId))).go();
  }

  Future<void> setAccountActive(String accountId, bool active) {
    return (_db.update(_db.accounts)..where((a) => a.id.equals(accountId))).write(
      AccountsCompanion(isActive: Value(active), updatedAt: Value(DateTime.now())),
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

  /// Reverts the transaction's effect on its old account, applies the new
  /// values (including a possible account switch), then re-applies to the
  /// (possibly different) account — keeps both balances correct in one go.
  Future<void> updateTransaction({
    required String id,
    required String accountId,
    String? categoryId,
    required String merchant,
    required int amountMinor,
    required DateTime date,
    String? note,
  }) {
    return _db.transaction(() async {
      final old = await (_db.select(
        _db.transactions,
      )..where((t) => t.id.equals(id))).getSingle();

      final oldAccount = await (_db.select(
        _db.accounts,
      )..where((a) => a.id.equals(old.accountId))).getSingle();
      await (_db.update(_db.accounts)..where((a) => a.id.equals(old.accountId))).write(
        AccountsCompanion(
          balanceMinor: Value(oldAccount.balanceMinor - old.amountMinor),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
        TransactionsCompanion(
          accountId: Value(accountId),
          categoryId: Value(categoryId),
          merchant: Value(merchant),
          amountMinor: Value(amountMinor),
          date: Value(date),
          note: Value(note),
        ),
      );

      final newAccount = await (_db.select(
        _db.accounts,
      )..where((a) => a.id.equals(accountId))).getSingle();
      await (_db.update(_db.accounts)..where((a) => a.id.equals(accountId))).write(
        AccountsCompanion(
          balanceMinor: Value(newAccount.balanceMinor + amountMinor),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> deleteTransaction(String id) {
    return _db.transaction(() async {
      final txn = await (_db.select(
        _db.transactions,
      )..where((t) => t.id.equals(id))).getSingle();
      final account = await (_db.select(
        _db.accounts,
      )..where((a) => a.id.equals(txn.accountId))).getSingle();
      await (_db.update(_db.accounts)..where((a) => a.id.equals(txn.accountId))).write(
        AccountsCompanion(
          balanceMinor: Value(account.balanceMinor - txn.amountMinor),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
    });
  }

  static DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month);

  Future<void> createBudget({
    required String categoryId,
    required int limitMinor,
    String period = 'monthly',
    DateTime? effectiveMonth,
  }) {
    final month = _startOfMonth(effectiveMonth ?? DateTime.now());
    return _db.into(_db.budgets).insert(
      BudgetsCompanion.insert(
        categoryId: categoryId,
        limitMinor: limitMinor,
        period: Value(period),
        startDate: month,
        effectiveMonth: Value(month),
      ),
    );
  }

  /// Upserts the version of [categoryId]'s budget effective from
  /// [targetMonth]: updates the row already covering that month if one
  /// exists (e.g. two edits within the same month), otherwise inserts a new
  /// version — leaving every earlier version untouched so past months keep
  /// showing what was true for them at the time.
  Future<void> _upsertBudgetVersion({
    required String categoryId,
    required DateTime targetMonth,
    required int limitMinor,
    required String period,
    required bool active,
  }) async {
    final month = _startOfMonth(targetMonth);
    final existing = await (_db.select(_db.budgets)..where(
          (b) => b.categoryId.equals(categoryId) & b.effectiveMonth.equals(month),
        ))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.budgets)..where((b) => b.id.equals(existing.id))).write(
        BudgetsCompanion(
          limitMinor: Value(limitMinor),
          period: Value(period),
          active: Value(active),
        ),
      );
    } else {
      await _db.into(_db.budgets).insert(
        BudgetsCompanion.insert(
          categoryId: categoryId,
          limitMinor: limitMinor,
          period: Value(period),
          startDate: month,
          effectiveMonth: Value(month),
          active: Value(active),
        ),
      );
    }
  }

  /// [id] identifies the budget version currently shown in the UI being
  /// edited — used only to look up which category it belongs to (and detect
  /// a category change). The edit itself always lands as a new/updated
  /// version effective [effectiveMonth] (default: the current real month),
  /// never as a mutation of a past version.
  Future<void> updateBudget({
    required String id,
    required String categoryId,
    required int limitMinor,
    required String period,
    DateTime? effectiveMonth,
  }) async {
    final original = await (_db.select(
      _db.budgets,
    )..where((b) => b.id.equals(id))).getSingleOrNull();
    final target = effectiveMonth ?? DateTime.now();

    if (original != null && original.categoryId != categoryId) {
      // Category changed: stop the old category's budget from this month
      // forward, then start a fresh version under the new category.
      await _upsertBudgetVersion(
        categoryId: original.categoryId,
        targetMonth: target,
        limitMinor: original.limitMinor,
        period: original.period,
        active: false,
      );
    }

    await _upsertBudgetVersion(
      categoryId: categoryId,
      targetMonth: target,
      limitMinor: limitMinor,
      period: period,
      active: true,
    );
  }

  /// Tombstones the budget (no more spend tracking for this category from
  /// this month forward) rather than erasing it, unless this version has no
  /// history before it — in that case there's nothing to preserve, so it's
  /// removed outright.
  Future<void> deleteBudget(String id) async {
    final budget = await (_db.select(
      _db.budgets,
    )..where((b) => b.id.equals(id))).getSingle();

    final hasEarlierHistory =
        await (_db.select(_db.budgets)..where(
              (b) =>
                  b.categoryId.equals(budget.categoryId) &
                  b.effectiveMonth.isSmallerThanValue(budget.effectiveMonth!),
            ))
            .get()
            .then((rows) => rows.isNotEmpty);

    if (!hasEarlierHistory) {
      await (_db.delete(
        _db.budgets,
      )..where((b) => b.categoryId.equals(budget.categoryId))).go();
      return;
    }

    await _upsertBudgetVersion(
      categoryId: budget.categoryId,
      targetMonth: DateTime.now(),
      limitMinor: budget.limitMinor,
      period: budget.period,
      active: false,
    );
  }
}
