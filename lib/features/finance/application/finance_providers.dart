import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/utils/date_utils.dart';
import '../data/finance_repository.dart';
import '../domain/budget_progress.dart';

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(ref.watch(appDatabaseProvider));
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

final transactionsProvider = StreamProvider<List<Transaction>>((ref) {
  return ref.watch(financeRepositoryProvider).watchTransactions();
});

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(financeRepositoryProvider).watchCategories();
});

final budgetsProvider = StreamProvider<List<Budget>>((ref) {
  return ref.watch(financeRepositoryProvider).watchBudgets();
});

final totalBalanceMinorProvider = Provider<int>((ref) {
  final accounts = ref.watch(activeAccountsProvider);
  return accounts.fold<int>(0, (sum, a) => sum + a.balanceMinor);
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
      if (latest == null || effective.isAfter(latest.effectiveMonth ?? latest.startDate)) {
        latest = v;
      }
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
  FinanceController(this._repo);

  final FinanceRepository _repo;

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
  }) {
    return _repo.createTransaction(
      accountId: accountId,
      categoryId: categoryId,
      merchant: merchant,
      amountMinor: amountMinor,
      date: date ?? DateTime.now(),
      note: note,
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
  }) {
    return _repo.updateTransaction(
      id: id,
      accountId: accountId,
      categoryId: categoryId,
      merchant: merchant,
      amountMinor: amountMinor,
      date: date ?? DateTime.now(),
      note: note,
    );
  }

  Future<void> deleteTransaction(String id) => _repo.deleteTransaction(id);

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
}

final financeControllerProvider = Provider<FinanceController>((ref) {
  return FinanceController(ref.watch(financeRepositoryProvider));
});
