import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/reminders/reminder_mode.dart';
import '../../../core/services/file_storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/date_utils.dart';
import '../../settings/application/settings_providers.dart';
import '../data/finance_repository.dart';
import '../domain/budget_progress.dart';
import '../domain/net_worth_point.dart';

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(ref.watch(appDatabaseProvider), ref.watch(fileStorageServiceProvider));
});

/// All accounts, active and deactivated — kept around (rather than filtered)
/// because label lookups (e.g. a goal linked to an account that's since been
/// deactivated) still need to resolve a name for it.
final accountsProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(financeRepositoryProvider).watchAccounts();
});

/// The set anywhere a *new* transaction/goal-link should pick from, and what
/// the balance total and account row on the Finance screen show.
final activeAccountsProvider = Provider<List<Account>>((ref) {
  return (ref.watch(accountsProvider).value ?? const []).where((a) => a.isActive).toList();
});

final archivedAccountsProvider = Provider<List<Account>>((ref) {
  return (ref.watch(accountsProvider).value ?? const []).where((a) => !a.isActive).toList();
});

/// Active accounts a transaction can be recorded against — investment
/// accounts are excluded because their balance is meant to move via
/// valuation changes, not everyday transactions.
final transactableAccountsProvider = Provider<List<Account>>((ref) {
  return ref
      .watch(activeAccountsProvider)
      .where((a) => normalizeAccountTypeKey(a.type) != 'investment')
      .toList();
});

final accountTypesProvider = StreamProvider<List<AccountType>>((ref) {
  return ref.watch(financeRepositoryProvider).watchAccountTypes();
});

final transactionsProvider = StreamProvider<List<Transaction>>((ref) {
  return ref.watch(financeRepositoryProvider).watchTransactions();
});

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(financeRepositoryProvider).watchCategories();
});

final budgetsProvider = StreamProvider<List<Budget>>((ref) {
  return ref.watch(financeRepositoryProvider).watchBudgets();
});

final recurringTransactionsProvider = StreamProvider<List<RecurringTransaction>>((ref) {
  return ref.watch(financeRepositoryProvider).watchRecurringTransactions();
});

final billsProvider = StreamProvider<List<Bill>>((ref) {
  return ref.watch(financeRepositoryProvider).watchBills();
});

/// Active bills only, already sorted by due date (the repo query's order),
/// for the Bills screen and any "upcoming" summary.
final upcomingBillsProvider = Provider<List<Bill>>((ref) {
  return (ref.watch(billsProvider).value ?? const []).where((b) => b.active).toList();
});

final totalBalanceMinorProvider = Provider<int>((ref) {
  final accounts = ref.watch(activeAccountsProvider);
  return accounts.fold<int>(0, (sum, a) => sum + a.balanceMinor);
});

/// Account types treated as a liability for the assets/liabilities split —
/// everything else (checking, savings, cash, investment, ...) counts as an
/// asset, same type-based special-casing `transactableAccountsProvider`
/// already does for investment accounts.
bool _isLiabilityAccountType(String type) => normalizeAccountTypeKey(type) == 'credit card';

/// Reconstructs each account's balance as of [asOfDates] by walking back
/// from its *current* [Accounts.balanceMinor] — subtracting every
/// transaction dated after that point — rather than storing periodic
/// snapshots. Same derive-don't-store approach as habit streaks and budget
/// spend-vs-actual: it can never drift out of sync with the transaction
/// history because there's nothing cached to go stale.
///
/// A credit-card-type account contributes to liabilities only while its
/// balance is negative (money owed); a paid-off or in-credit balance folds
/// into assets like any other account. Either way `assetsMinor -
/// liabilitiesMinor` always equals the plain sum of balances, so this never
/// disagrees with [totalBalanceMinorProvider].
List<NetWorthPoint> computeNetWorthTrend({
  required List<Account> accounts,
  required List<Transaction> transactions,
  required List<DateTime> asOfDates,
}) {
  final transactionsByAccount = <String, List<Transaction>>{};
  for (final t in transactions) {
    transactionsByAccount.putIfAbsent(t.accountId, () => []).add(t);
  }

  return [
    for (final asOf in asOfDates)
      _pointAsOf(accounts: accounts, transactionsByAccount: transactionsByAccount, asOf: asOf),
  ];
}

NetWorthPoint _pointAsOf({
  required List<Account> accounts,
  required Map<String, List<Transaction>> transactionsByAccount,
  required DateTime asOf,
}) {
  var assets = 0;
  var liabilities = 0;
  for (final account in accounts) {
    final reversal = (transactionsByAccount[account.id] ?? const [])
        .where((t) => t.date.isAfter(asOf))
        .fold<int>(0, (sum, t) => sum + t.amountMinor);
    final balanceAsOf = account.balanceMinor - reversal;

    if (_isLiabilityAccountType(account.type) && balanceAsOf < 0) {
      liabilities += -balanceAsOf;
    } else {
      assets += balanceAsOf;
    }
  }
  return NetWorthPoint(date: asOf, assetsMinor: assets, liabilitiesMinor: liabilities);
}

/// The 1st of each of the last [count] months (oldest first), for the
/// trend's checkpoint dates.
List<DateTime> _lastMonthStarts(int count, DateTime now) {
  return [for (var i = count - 1; i >= 0; i--) DateTime(now.year, now.month - i)];
}

/// Six trailing month-start checkpoints plus "right now" as the final,
/// always-current point.
final netWorthTrendProvider = Provider<List<NetWorthPoint>>((ref) {
  final accounts = ref.watch(activeAccountsProvider);
  final transactions = ref.watch(transactionsProvider).value ?? const [];
  final now = DateTime.now();
  return computeNetWorthTrend(
    accounts: accounts,
    transactions: transactions,
    asOfDates: [..._lastMonthStarts(6, now), now],
  );
});

/// For each category, the single version of its budget in effect for
/// [month] — the latest row with `effectiveMonth <= month`, skipping
/// categories whose latest applicable version is a tombstone (`active`
/// false) or that had no budget yet as of that month. This is what makes
/// budget history month-specific: editing a limit inserts a new version
/// rather than mutating the old one, so resolving "for month X" here always
/// picks whichever version was true back then.
List<Budget> budgetsEffectiveFor(List<Budget> allVersions, DateTime month) {
  final monthStart = DateTime(month.year, month.month);
  final byCategory = <String, List<Budget>>{};
  for (final b in allVersions) {
    byCategory.putIfAbsent(b.categoryId, () => []).add(b);
  }

  final result = <Budget>[];
  for (final versions in byCategory.values) {
    Budget? latest;
    for (final v in versions) {
      final effective = v.effectiveMonth ?? v.startDate;
      if (effective.isAfter(monthStart)) continue;
      if (latest == null) {
        latest = v;
        continue;
      }
      final latestEffective = latest.effectiveMonth ?? latest.startDate;
      // Strictly later month always wins. A tie (two versions both
      // resolving to the same calendar month — possible if an edit landed
      // as a fresh row instead of updating one in place) falls back to
      // whichever was written most recently, so the intended latest edit
      // is never shadowed by iteration order.
      final isLater = effective.year != latestEffective.year || effective.month != latestEffective.month
          ? effective.isAfter(latestEffective)
          : v.createdAt.isAfter(latest.createdAt);
      if (isLater) latest = v;
    }
    if (latest != null && latest.active) result.add(latest);
  }
  return result;
}

List<BudgetProgress> progressFor({
  required List<Budget> allBudgetVersions,
  required List<Category> categories,
  required List<Transaction> transactions,
  required DateTime month,
}) {
  final categoryById = {for (final c in categories) c.id: c};
  final effective = budgetsEffectiveFor(allBudgetVersions, month);

  final monthStart = DateTime(month.year, month.month);
  final monthEnd = DateTime(month.year, month.month + 1);
  final weekStart = startOfWeek(monthEnd.subtract(const Duration(days: 1)));

  return [
    for (final budget in effective)
      if (categoryById[budget.categoryId] case final category?)
        BudgetProgress(
          budget: budget,
          category: category,
          spentMinor: transactions
              .where((t) => t.categoryId == budget.categoryId)
              .where((t) => t.amountMinor < 0)
              .where(
                (t) => budget.period == 'weekly'
                    ? !t.date.isBefore(weekStart) && t.date.isBefore(monthEnd)
                    : !t.date.isBefore(monthStart) && t.date.isBefore(monthEnd),
              )
              .fold<int>(0, (sum, t) => sum + t.amountMinor.abs()),
        ),
  ];
}

/// Budgets paired with actual spend for the current real month, derived the
/// same way habit streaks are — never stored, always recomputed from
/// transactions.
final budgetsWithProgressProvider = Provider<List<BudgetProgress>>((ref) {
  return progressFor(
    allBudgetVersions: ref.watch(budgetsProvider).value ?? const [],
    categories: ref.watch(categoriesProvider).value ?? const [],
    transactions: ref.watch(transactionsProvider).value ?? const [],
    month: DateTime.now(),
  );
});

class FinanceController {
  FinanceController(this._repo, this._notifications, this._remindersEnabled);

  final FinanceRepository _repo;
  final NotificationService _notifications;

  /// Read at call time rather than captured — same pattern as
  /// `TasksController`/`HabitsController` — so toggling the "Task
  /// reminders" setting (reused here as bills' master switch, since a bill
  /// reminder is conceptually a due-date nudge like a task's) takes effect
  /// for the next bill without rebuilding this controller.
  final bool Function() _remindersEnabled;

  Future<void> addAccount({required String name, required String type, int balanceMinor = 0}) {
    return _repo.createAccount(name: name, type: type, balanceMinor: balanceMinor);
  }

  Future<({int transactionCount, int goalLinkCount})> checkAccountUsage(String accountId) {
    return _repo.checkAccountUsage(accountId);
  }

  /// Callers must call [checkAccountUsage] first and confirm both counts are
  /// zero — this doesn't re-check, so calling it on a referenced account
  /// would silently orphan those rows.
  Future<void> deleteAccount(String accountId) => _repo.deleteAccount(accountId);

  Future<void> deactivateAccount(String accountId) => _repo.setAccountActive(accountId, false);

  Future<void> reactivateAccount(String accountId) => _repo.setAccountActive(accountId, true);

  Future<void> addTransaction({
    required String accountId,
    String? categoryId,
    required String merchant,
    required int amountMinor,
    DateTime? date,
    String? note,
    String? paymentMode,
  }) {
    return _repo.createTransaction(
      accountId: accountId,
      categoryId: categoryId,
      merchant: merchant,
      amountMinor: amountMinor,
      date: date ?? DateTime.now(),
      note: note,
      paymentMode: paymentMode,
    );
  }

  Future<void> updateTransaction({
    required String id,
    required String accountId,
    String? categoryId,
    required String merchant,
    required int amountMinor,
    DateTime? date,
    String? note,
    String? paymentMode,
  }) {
    return _repo.updateTransaction(
      id: id,
      accountId: accountId,
      categoryId: categoryId,
      merchant: merchant,
      amountMinor: amountMinor,
      date: date ?? DateTime.now(),
      note: note,
      paymentMode: paymentMode,
    );
  }

  Future<void> deleteTransaction(String id) => _repo.deleteTransaction(id);

  Future<void> attachReceipt({
    required String transactionId,
    required File source,
    required String originalName,
  }) {
    return _repo.attachReceipt(
      transactionId: transactionId,
      source: source,
      originalName: originalName,
    );
  }

  Future<void> removeReceipt(String transactionId) => _repo.removeReceipt(transactionId);

  Future<Category> addCategory({
    required String name,
    required String icon,
    required String colorHex,
    String kind = 'expense',
  }) {
    return _repo.createCategory(name: name, icon: icon, colorHex: colorHex, kind: kind);
  }

  Future<Category> updateCategory({
    required String id,
    required String name,
    required String icon,
    required String colorHex,
    required String kind,
  }) {
    return _repo.updateCategory(id: id, name: name, icon: icon, colorHex: colorHex, kind: kind);
  }

  Future<int> categoryUsageCount(String categoryId) => _repo.categoryUsageCount(categoryId);

  /// Callers must call [categoryUsageCount] first and confirm it's zero.
  Future<void> deleteCategory(String id) => _repo.deleteCategory(id);

  Future<void> addAccountType({required String name, required String icon}) {
    return _repo.createAccountType(name: name, icon: icon);
  }

  Future<void> updateAccountType({required String id, required String name, required String icon}) {
    return _repo.updateAccountType(id: id, name: name, icon: icon);
  }

  Future<int> accountTypeUsageCount(String typeName) => _repo.accountTypeUsageCount(typeName);

  /// Callers must call [accountTypeUsageCount] first and confirm it's zero.
  Future<void> deleteAccountType(String id) => _repo.deleteAccountType(id);

  Future<void> addBudget({
    required String categoryId,
    required int limitMinor,
    String period = 'monthly',
    DateTime? effectiveMonth,
  }) {
    return _repo.createBudget(
      categoryId: categoryId,
      limitMinor: limitMinor,
      period: period,
      effectiveMonth: effectiveMonth,
    );
  }

  Future<void> updateBudget({
    required String id,
    required String categoryId,
    required int limitMinor,
    required String period,
    DateTime? effectiveMonth,
  }) {
    return _repo.updateBudget(
      id: id,
      categoryId: categoryId,
      limitMinor: limitMinor,
      period: period,
      effectiveMonth: effectiveMonth,
    );
  }

  Future<void> deleteBudget(String id) => _repo.deleteBudget(id);

  Future<void> addRecurringTransaction({
    required String accountId,
    String? categoryId,
    required String merchant,
    required int amountMinor,
    required String frequency,
    required DateTime startDate,
    DateTime? endDate,
    String? note,
    String? paymentMode,
  }) async {
    await _repo.createRecurringTransaction(
      accountId: accountId,
      categoryId: categoryId,
      merchant: merchant,
      amountMinor: amountMinor,
      frequency: frequency,
      startDate: startDate,
      endDate: endDate,
      note: note,
      paymentMode: paymentMode,
    );
    // A schedule whose start date is today or earlier should show up as a
    // real transaction immediately, not wait for the next app-open catch-up.
    await _repo.generateDueRecurringTransactions();
  }

  Future<void> setRecurringTransactionActive(String id, bool active) =>
      _repo.setRecurringTransactionActive(id, active);

  Future<void> deleteRecurringTransaction(String id) => _repo.deleteRecurringTransaction(id);

  Future<void> generateDueRecurringTransactions() => _repo.generateDueRecurringTransactions();

  Future<void> addBill({
    required String name,
    String? accountId,
    String? categoryId,
    required int amountMinor,
    required DateTime dueDate,
    String frequency = 'monthly',
    bool reminderEnabled = true,
    ReminderMode reminderMode = ReminderMode.notification,
    int reminderDaysBefore = 0,
  }) async {
    final bill = await _repo.createBill(
      name: name,
      accountId: accountId,
      categoryId: categoryId,
      amountMinor: amountMinor,
      dueDate: dueDate,
      frequency: frequency,
      reminderEnabled: reminderEnabled,
      reminderMode: reminderMode.storageValue,
      reminderDaysBefore: reminderDaysBefore,
    );
    await _scheduleBillReminder(bill, reminderMode);
  }

  /// Pays the bill from [accountId] and, for a repeating bill, reschedules
  /// its reminder against the rolled-forward due date.
  Future<void> markBillPaid(Bill bill, {required String accountId}) async {
    await _notifications.cancelBillReminder(bill.id);
    final updated = await _repo.markBillPaid(bill.id, accountId: accountId);
    if (updated.active) {
      await _scheduleBillReminder(updated, ReminderMode.fromStorage(updated.reminderMode));
    }
  }

  Future<void> deleteBill(String id) async {
    await _notifications.cancelBillReminder(id);
    await _repo.deleteBill(id);
  }

  Future<void> _scheduleBillReminder(Bill bill, ReminderMode mode) async {
    if (!bill.reminderEnabled || !_remindersEnabled()) return;
    final reminderTime = bill.dueDate.subtract(Duration(days: bill.reminderDaysBefore));
    await _notifications.scheduleBillReminder(
      billId: bill.id,
      title: '${bill.name} due',
      reminderTime: reminderTime,
      mode: mode,
    );
  }
}

final financeControllerProvider = Provider<FinanceController>((ref) {
  return FinanceController(
    ref.watch(financeRepositoryProvider),
    ref.watch(notificationServiceProvider),
    () => ref.read(settingsProvider).taskReminders,
  );
});
