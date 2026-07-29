import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';
import '../../finance/application/finance_providers.dart';
import '../../finance/domain/budget_progress.dart';
import '../domain/category_spend.dart';

class SelectedAnalyzerMonth extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void shiftBy(int months) {
    state = DateTime(state.year, state.month + months);
  }
}

final selectedAnalyzerMonthProvider =
    NotifierProvider<SelectedAnalyzerMonth, DateTime>(SelectedAnalyzerMonth.new);

List<Transaction> _inMonth(List<Transaction> all, DateTime month) {
  return all
      .where((t) => t.date.year == month.year && t.date.month == month.month)
      .toList();
}

int _expenseTotal(List<Transaction> txns) {
  return txns
      .where((t) => t.amountMinor < 0)
      .fold<int>(0, (sum, t) => sum + t.amountMinor.abs());
}

final monthTransactionsProvider = Provider<List<Transaction>>((ref) {
  final all = ref.watch(transactionsProvider).value ?? const [];
  final month = ref.watch(selectedAnalyzerMonthProvider);
  return _inMonth(all, month);
});

final monthExpenseTotalMinorProvider = Provider<int>((ref) {
  return _expenseTotal(ref.watch(monthTransactionsProvider));
});

final previousMonthExpenseTotalMinorProvider = Provider<int>((ref) {
  final all = ref.watch(transactionsProvider).value ?? const [];
  final month = ref.watch(selectedAnalyzerMonthProvider);
  final previous = DateTime(month.year, month.month - 1);
  return _expenseTotal(_inMonth(all, previous));
});

/// Expense share by category for the selected month, sorted largest first —
/// feeds the donut chart's slices and legend.
final categoryBreakdownProvider = Provider<List<CategorySpend>>((ref) {
  final txns = ref
      .watch(monthTransactionsProvider)
      .where((t) => t.amountMinor < 0)
      .toList();
  final categories = ref.watch(categoriesProvider).value ?? const [];
  final categoryById = {for (final c in categories) c.id: c};

  final totals = <String, int>{};
  for (final t in txns) {
    final id = t.categoryId;
    if (id == null) continue;
    totals[id] = (totals[id] ?? 0) + t.amountMinor.abs();
  }
  final grandTotal = totals.values.fold<int>(0, (a, b) => a + b);
  if (grandTotal == 0) return const [];

  final entries =
      totals.entries.where((e) => categoryById.containsKey(e.key)).map((e) {
        return CategorySpend(
          category: categoryById[e.key]!,
          totalMinor: e.value,
          share: e.value / grandTotal,
        );
      }).toList()
        ..sort((a, b) => b.totalMinor.compareTo(a.totalMinor));
  return entries;
});

/// Expense total per calendar week (Mon-Sun) touching the selected month —
/// feeds the trend line, at most ~5 points for a normal month.
final weeklyTrendProvider = Provider<List<int>>((ref) {
  final txns = ref
      .watch(monthTransactionsProvider)
      .where((t) => t.amountMinor < 0)
      .toList();
  final month = ref.watch(selectedAnalyzerMonthProvider);
  final firstDay = DateTime(month.year, month.month, 1);
  final lastDay = DateTime(month.year, month.month + 1, 0);

  final weekStarts = <DateTime>[];
  var cursor = startOfWeek(firstDay);
  while (!cursor.isAfter(lastDay)) {
    weekStarts.add(cursor);
    cursor = cursor.add(const Duration(days: 7));
  }

  return [
    for (final weekStart in weekStarts)
      txns
          .where(
            (t) =>
                !t.date.isBefore(weekStart) &&
                t.date.isBefore(weekStart.add(const Duration(days: 7))),
          )
          .fold<int>(0, (sum, t) => sum + t.amountMinor.abs()),
  ];
});

/// Same shape as finance's `budgetsWithProgressProvider`, but spend is
/// computed against the analyzer's selected month/week rather than
/// `DateTime.now()` — otherwise navigating to a past or future month left
/// this card showing the current period's spend regardless of which month
/// was on screen.
final monthBudgetsWithProgressProvider = Provider<List<BudgetProgress>>((ref) {
  final budgets = ref.watch(budgetsProvider).value ?? const [];
  final categories = ref.watch(categoriesProvider).value ?? const [];
  final transactions = ref.watch(transactionsProvider).value ?? const [];
  final categoryById = {for (final c in categories) c.id: c};

  final month = ref.watch(selectedAnalyzerMonthProvider);
  final monthStart = DateTime(month.year, month.month);
  final monthEnd = DateTime(month.year, month.month + 1);
  final weekStart = startOfWeek(monthEnd.subtract(const Duration(days: 1)));

  return [
    for (final budget in budgets)
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
});
