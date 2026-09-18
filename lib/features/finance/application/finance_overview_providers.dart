import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../spend_analyzer/application/spend_analyzer_providers.dart';
import 'finance_providers.dart';

/// Aggregates for the design's Finance screen headline and stat pills.
///
/// All derived from [transactionsProvider] at read time — nothing here is stored,
/// matching the pattern the rest of the app already uses for budget spend and
/// habit streaks. Amounts stay in integer minor units throughout; only the
/// presentation layer formats them.
///
/// Transfers are excluded from every figure: moving money between your own
/// accounts is not income, spend, or investment, and counting it would inflate
/// all three.
///
/// The month these read is [selectedAnalyzerMonthProvider], so the Finance screen
/// and the Spend Analyser stay on the same month without a second source of
/// truth.
List<Transaction> _spendable(List<Transaction> txns) {
  return txns.where((t) => t.paymentMode != 'transfer').toList();
}

/// Money in: positive amounts. Comp: `Income ₹1,85,000`.
final monthIncomeMinorProvider = Provider<int>((ref) {
  return _spendable(ref.watch(monthTransactionsProvider))
      .where((t) => t.amountMinor > 0)
      .fold<int>(0, (sum, t) => sum + t.amountMinor);
});

/// Money out: negative amounts, as a positive figure. Comp: `Outgoing ₹92,400`.
final monthOutgoingMinorProvider = Provider<int>((ref) {
  return _spendable(ref.watch(monthTransactionsProvider))
      .where((t) => t.amountMinor < 0)
      .fold<int>(0, (sum, t) => sum + t.amountMinor.abs());
});

/// Comp: `NET SAVED · AUGUST` — income less outgoing. May be negative.
final monthNetSavedMinorProvider = Provider<int>((ref) {
  return ref.watch(monthIncomeMinorProvider) -
      ref.watch(monthOutgoingMinorProvider);
});

/// Change in net saved against the previous month, as a signed ratio, or null
/// when the previous month has no baseline to compare against. Comp shows this as
/// an arrow plus `26%` beside the headline.
final netSavedDeltaProvider = Provider<double?>((ref) {
  final all = ref.watch(transactionsProvider).value ?? const [];
  final month = ref.watch(selectedAnalyzerMonthProvider);
  final previous = DateTime(month.year, month.month - 1);

  final prior = _spendable(
    all
        .where((t) => t.date.year == previous.year && t.date.month == previous.month)
        .toList(),
  );
  final priorIn = prior
      .where((t) => t.amountMinor > 0)
      .fold<int>(0, (sum, t) => sum + t.amountMinor);
  final priorOut = prior
      .where((t) => t.amountMinor < 0)
      .fold<int>(0, (sum, t) => sum + t.amountMinor.abs());
  final priorNet = priorIn - priorOut;
  if (priorNet == 0) return null;

  final current = ref.watch(monthNetSavedMinorProvider);
  return (current - priorNet) / priorNet.abs();
});

/// One bar per month for the comp's "Monthly spending · 6 months" chart, oldest
/// first, ending on the selected month.
class MonthSpend {
  const MonthSpend({required this.month, required this.totalMinor});

  final DateTime month;
  final int totalMinor;
}

final monthlySpendTrendProvider = Provider<List<MonthSpend>>((ref) {
  final all = ref.watch(transactionsProvider).value ?? const [];
  final selected = ref.watch(selectedAnalyzerMonthProvider);

  return List.generate(6, (i) {
    final month = DateTime(selected.year, selected.month - (5 - i));
    final total = _spendable(
      all
          .where((t) => t.date.year == month.year && t.date.month == month.month)
          .toList(),
    ).where((t) => t.amountMinor < 0).fold<int>(0, (s, t) => s + t.amountMinor.abs());
    return MonthSpend(month: month, totalMinor: total);
  });
});
