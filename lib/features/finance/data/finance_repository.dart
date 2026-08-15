import 'dart:io';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/file_storage_service.dart';
import '../../../core/utils/date_utils.dart';

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

/// The app's original fixed account kinds, now just the seed data for the
/// user-manageable `AccountTypes` table. Names are Title Case because — like
/// `Categories.name` — this is both the identifier stored on
/// `Accounts.type` for accounts created from now on *and* the display text;
/// [normalizeAccountTypeKey] bridges the old lowercase/underscored values
/// (`checking`, `credit_card`, ...) already on pre-existing accounts so
/// icon/label lookup still matches them.
const _defaultAccountTypes = [
  ('Checking', 'account_balance_wallet'),
  ('Savings', 'savings'),
  ('Credit Card', 'credit_card'),
  ('Cash', 'payments'),
  ('Investment', 'trending_up'),
];

/// Matches an `Accounts.type`/`AccountTypes.name` value regardless of case
/// or whether it uses spaces or underscores, so pre-existing accounts
/// (stored as `checking`, `credit_card`, ...) still resolve against the
/// newly-seeded Title Case `AccountTypes` rows (`Checking`, `Credit Card`).
String normalizeAccountTypeKey(String s) => s.toLowerCase().replaceAll('_', ' ').trim();

class FinanceRepository {
  FinanceRepository(this._db, this._storage);

  final AppDatabase _db;
  final FileStorageService _storage;

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

  Future<void> ensureDefaultAccountTypes() async {
    final existing = await _db.select(_db.accountTypes).get();
    if (existing.isNotEmpty) return;
    await _db.batch((batch) {
      batch.insertAll(_db.accountTypes, [
        for (final (name, icon) in _defaultAccountTypes)
          AccountTypesCompanion.insert(name: name, icon: Value(icon)),
      ]);
    });
  }

  /// Excludes non-finance kinds (e.g. `habit`) that share this table —
  /// see `Categories.kind`'s doc comment for the full list of kinds.
  Stream<List<Category>> watchCategories() {
    return (_db.select(
      _db.categories,
    )..where((c) => c.kind.isIn(const ['expense', 'income']))).watch();
  }

  Stream<List<AccountType>> watchAccountTypes() => _db.select(_db.accountTypes).watch();

  /// Returns the created row (rather than just succeeding) so a caller that
  /// created this category inline — e.g. from the transaction/budget
  /// category picker — can select it immediately without waiting on the
  /// `watchCategories()` stream to catch up.
  Future<Category> createCategory({
    required String name,
    required String icon,
    required String colorHex,
    String kind = 'expense',
  }) {
    return _db.into(_db.categories).insertReturning(
      CategoriesCompanion.insert(
        name: name,
        icon: Value(icon),
        colorHex: colorHex,
        kind: Value(kind),
      ),
    );
  }

  Future<Category> updateCategory({
    required String id,
    required String name,
    required String icon,
    required String colorHex,
    required String kind,
  }) async {
    await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        name: Value(name),
        icon: Value(icon),
        colorHex: Value(colorHex),
        kind: Value(kind),
      ),
    );
    return (_db.select(
      _db.categories,
    )..where((c) => c.id.equals(id))).getSingle();
  }

  /// Rows referencing this category (transactions, budget versions) — the
  /// gate for whether it can be deleted.
  Future<int> categoryUsageCount(String categoryId) async {
    final txnCount = await (_db.select(
      _db.transactions,
    )..where((t) => t.categoryId.equals(categoryId))).get().then((r) => r.length);
    final budgetCount = await (_db.select(
      _db.budgets,
    )..where((b) => b.categoryId.equals(categoryId))).get().then((r) => r.length);
    return txnCount + budgetCount;
  }

  /// Only safe once [categoryUsageCount] is confirmed zero.
  Future<void> deleteCategory(String id) {
    return (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
  }

  Future<void> createAccountType({required String name, required String icon}) {
    return _db.into(_db.accountTypes).insert(
      AccountTypesCompanion.insert(name: name, icon: Value(icon)),
    );
  }

  Future<void> updateAccountType({
    required String id,
    required String name,
    required String icon,
  }) {
    return (_db.update(_db.accountTypes)..where((t) => t.id.equals(id))).write(
      AccountTypesCompanion(name: Value(name), icon: Value(icon)),
    );
  }

  /// Accounts currently using this type's name (case/underscore-insensitive,
  /// since older accounts may still hold the old lowercase key) — the gate
  /// for whether it can be deleted.
  Future<int> accountTypeUsageCount(String typeName) async {
    final accounts = await _db.select(_db.accounts).get();
    final key = normalizeAccountTypeKey(typeName);
    return accounts.where((a) => normalizeAccountTypeKey(a.type) == key).length;
  }

  /// Only safe once [accountTypeUsageCount] is confirmed zero.
  Future<void> deleteAccountType(String id) {
    return (_db.delete(_db.accountTypes)..where((t) => t.id.equals(id))).go();
  }

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
    String? paymentMode,
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
          paymentMode: Value(paymentMode),
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
    String? paymentMode,
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
          paymentMode: Value(paymentMode),
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

  static const _receiptsFolderName = 'Receipts';

  /// Files receipts under a "Receipts" folder in the shared Documents
  /// module (created on first use, same lazy-seed pattern as default
  /// categories/account types) so they're browsable there too, not just
  /// reachable from the transaction that owns them.
  Future<String> _ensureReceiptsFolder() async {
    final existing = await (_db.select(_db.folders)..where(
      (f) => f.scope.equals('documents') & f.name.equals(_receiptsFolderName),
    )).getSingleOrNull();
    if (existing != null) return existing.id;

    final created = await _db.into(_db.folders).insertReturning(
      FoldersCompanion.insert(name: _receiptsFolderName, scope: 'documents'),
    );
    return created.id;
  }

  /// Imports [source] as a Document filed under the Receipts folder and
  /// links it to [transactionId], replacing (and deleting the file for) any
  /// receipt already attached.
  Future<void> attachReceipt({
    required String transactionId,
    required File source,
    required String originalName,
  }) async {
    await removeReceipt(transactionId);
    final folderId = await _ensureReceiptsFolder();
    final stored = await _storage.importFile(source, originalName: originalName);
    final document = await _db.into(_db.documents).insertReturning(
      DocumentsCompanion.insert(
        title: originalName,
        filePath: stored.relativePath,
        thumbnailPath: Value(stored.thumbnailRelativePath),
        mimeType: stored.mimeType,
        sizeBytes: Value(stored.sizeBytes),
        folderId: Value(folderId),
      ),
    );
    await (_db.update(_db.transactions)..where((t) => t.id.equals(transactionId))).write(
      TransactionsCompanion(receiptDocumentId: Value(document.id)),
    );
  }

  /// No-op if the transaction has no receipt attached.
  Future<void> removeReceipt(String transactionId) async {
    final txn = await (_db.select(
      _db.transactions,
    )..where((t) => t.id.equals(transactionId))).getSingle();
    final documentId = txn.receiptDocumentId;
    if (documentId == null) return;

    await (_db.update(_db.transactions)..where((t) => t.id.equals(transactionId))).write(
      const TransactionsCompanion(receiptDocumentId: Value(null)),
    );
    final document = await (_db.select(
      _db.documents,
    )..where((d) => d.id.equals(documentId))).getSingleOrNull();
    if (document == null) return;
    await _storage.deleteFile(document.filePath, thumbnailRelativePath: document.thumbnailPath);
    await (_db.delete(_db.documents)..where((d) => d.id.equals(documentId))).go();
  }

  Stream<List<RecurringTransaction>> watchRecurringTransactions() {
    return (_db.select(_db.recurringTransactions)
          ..orderBy([(r) => OrderingTerm.asc(r.nextDueDate)]))
        .watch();
  }

  Future<void> createRecurringTransaction({
    required String accountId,
    String? categoryId,
    required String merchant,
    required int amountMinor,
    required String frequency,
    required DateTime startDate,
    DateTime? endDate,
    String? note,
    String? paymentMode,
  }) {
    return _db.into(_db.recurringTransactions).insert(
      RecurringTransactionsCompanion.insert(
        accountId: accountId,
        categoryId: Value(categoryId),
        merchant: merchant,
        amountMinor: amountMinor,
        frequency: Value(frequency),
        nextDueDate: startDate,
        endDate: Value(endDate),
        note: Value(note),
        paymentMode: Value(paymentMode),
      ),
    );
  }

  Future<void> setRecurringTransactionActive(String id, bool active) {
    return (_db.update(
      _db.recurringTransactions,
    )..where((r) => r.id.equals(id))).write(RecurringTransactionsCompanion(active: Value(active)));
  }

  Future<void> deleteRecurringTransaction(String id) {
    return (_db.delete(_db.recurringTransactions)..where((r) => r.id.equals(id))).go();
  }

  /// Generates a real [Transaction] row for every occurrence of every active
  /// recurring transaction whose [RecurringTransactions.nextDueDate] has
  /// passed, advancing the schedule as it goes. Comparing against "now"
  /// rather than a stored list of future dates means this naturally
  /// catches up on everything missed while the app was closed — e.g. a
  /// monthly rent entry left un-opened for 3 months backfills all 3 — capped
  /// at 500 occurrences per schedule so a corrupt/ancient `nextDueDate`
  /// can't spin this into an unbounded loop.
  Future<void> generateDueRecurringTransactions() async {
    final due = await (_db.select(
      _db.recurringTransactions,
    )..where((r) => r.active.equals(true) & r.nextDueDate.isSmallerOrEqualValue(DateTime.now()))).get();

    for (final schedule in due) {
      var next = schedule.nextDueDate;
      var iterations = 0;
      while (!next.isAfter(DateTime.now()) &&
          (schedule.endDate == null || !next.isAfter(schedule.endDate!)) &&
          iterations < 500) {
        await createTransaction(
          accountId: schedule.accountId,
          categoryId: schedule.categoryId,
          merchant: schedule.merchant,
          amountMinor: schedule.amountMinor,
          date: next,
          note: schedule.note,
          paymentMode: schedule.paymentMode,
        );
        next = addRecurrenceInterval(next, schedule.frequency);
        iterations++;
      }

      final pastEnd = schedule.endDate != null && next.isAfter(schedule.endDate!);
      await (_db.update(_db.recurringTransactions)..where((r) => r.id.equals(schedule.id))).write(
        RecurringTransactionsCompanion(
          nextDueDate: Value(next),
          active: Value(!pastEnd),
        ),
      );
    }
  }

  Stream<List<Bill>> watchBills() {
    return (_db.select(_db.bills)..orderBy([(b) => OrderingTerm.asc(b.dueDate)])).watch();
  }

  Future<Bill> createBill({
    required String name,
    String? accountId,
    String? categoryId,
    required int amountMinor,
    required DateTime dueDate,
    String frequency = 'monthly',
    bool reminderEnabled = true,
    String reminderMode = 'notification',
    int reminderDaysBefore = 0,
  }) {
    return _db.into(_db.bills).insertReturning(
      BillsCompanion.insert(
        name: name,
        accountId: Value(accountId),
        categoryId: Value(categoryId),
        amountMinor: amountMinor,
        dueDate: dueDate,
        frequency: Value(frequency),
        reminderEnabled: Value(reminderEnabled),
        reminderMode: Value(reminderMode),
        reminderDaysBefore: Value(reminderDaysBefore),
      ),
    );
  }

  Future<void> deleteBill(String id) {
    return (_db.delete(_db.bills)..where((b) => b.id.equals(id))).go();
  }

  /// Records the payment as a real expense transaction against [accountId]
  /// (falling back to the bill's own default account, since the payer can
  /// choose a different one at pay-time) and either archives a one-time
  /// bill or rolls a repeating one forward to its next due date.
  Future<Bill> markBillPaid(String billId, {required String accountId}) async {
    return _db.transaction(() async {
      final bill = await (_db.select(
        _db.bills,
      )..where((b) => b.id.equals(billId))).getSingle();

      await createTransaction(
        accountId: accountId,
        categoryId: bill.categoryId,
        merchant: bill.name,
        amountMinor: -bill.amountMinor,
        date: DateTime.now(),
      );

      final isOneOff = bill.frequency == 'once';
      final updated = BillsCompanion(
        lastPaidDate: Value(DateTime.now()),
        dueDate: isOneOff ? const Value.absent() : Value(addRecurrenceInterval(bill.dueDate, bill.frequency)),
        active: Value(!isOneOff),
      );
      await (_db.update(_db.bills)..where((b) => b.id.equals(billId))).write(updated);
      return (_db.select(_db.bills)..where((b) => b.id.equals(billId))).getSingle();
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
    // Compared in Dart rather than via a SQL `.equals(month)` filter: SQLite
    // stores DateTime as an epoch value, and a round-trip comparison there
    // is one more place a timezone/precision mismatch could make two
    // "same month" values compare unequal — matching on year+month here
    // keeps this genuinely upsert (never duplicates a version for a month
    // that already has one).
    final candidates = await (_db.select(
      _db.budgets,
    )..where((b) => b.categoryId.equals(categoryId))).get();
    final existing = candidates.cast<Budget?>().firstWhere((b) {
      final effective = b!.effectiveMonth ?? b.startDate;
      return effective.year == month.year && effective.month == month.month;
    }, orElse: () => null);

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

    final siblings = await (_db.select(
      _db.budgets,
    )..where((b) => b.categoryId.equals(budget.categoryId))).get();
    final thisMonth = budget.effectiveMonth ?? budget.startDate;
    final hasEarlierHistory = siblings.any((b) {
      final effective = b.effectiveMonth ?? b.startDate;
      return effective.isBefore(thisMonth);
    });

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
