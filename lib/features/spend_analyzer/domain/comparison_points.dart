import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';

/// What the comparison card can chart.
enum ComparisonPeriod { weekly, monthly, yearly }

/// One group of bars: a week, a month or a year.
class ComparisonPoint {
  const ComparisonPoint({
    required this.start,
    required this.spentMinor,
    this.savedMinor,
    this.partial = false,
  });

  /// First day of the week, month or year.
  final DateTime start;

  /// Expenses in the period, transfers excluded.
  final int spentMinor;

  /// Income less [spentMinor] — negative when the period was overspent. Null
  /// for weeks: income arrives in lumps (a salary, say), so week by week it
  /// would show a huge saving in the pay week and a loss in every other one.
  final int? savedMinor;

  /// The period isn't over yet (this week, this year), so its totals will
  /// still grow.
  final bool partial;
}

/// Weeks shown, months shown, and the most years shown.
const comparisonWeeks = 4;
const comparisonMonths = 6;
const comparisonYears = 3;

/// Builds the bars for [period], ending at the period containing what the
/// analyzer is showing.
///
/// "Spent" is the same figure as the month total on the screen: expenses only,
/// and a transfer — money moving between your own accounts — is not spending
/// (nor income). [now] is passed in so "this week" and "this year" are testable.
List<ComparisonPoint> computeComparisonPoints({
  required ComparisonPeriod period,
  required List<Transaction> transactions,
  required DateTime selectedMonth,
  required DateTime now,
}) {
  final real = transactions.where((t) => t.paymentMode != 'transfer').toList();

  int spent(Iterable<Transaction> txns) => txns
      .where((t) => t.amountMinor < 0)
      .fold<int>(0, (sum, t) => sum + t.amountMinor.abs());
  int income(Iterable<Transaction> txns) => txns
      .where((t) => t.amountMinor > 0)
      .fold<int>(0, (sum, t) => sum + t.amountMinor);

  Iterable<Transaction> between(DateTime start, DateTime end) =>
      real.where((t) => !t.date.isBefore(start) && t.date.isBefore(end));

  switch (period) {
    case ComparisonPeriod.weekly:
      // The last four calendar weeks (Mon–Sun) up to the one containing today —
      // or, when browsing another month, up to that month's last day.
      final isCurrentMonth =
          selectedMonth.year == now.year && selectedMonth.month == now.month;
      final reference = isCurrentMonth
          ? dateOnly(now)
          : DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
      final lastWeek = startOfWeek(reference);
      return [
        for (var back = comparisonWeeks - 1; back >= 0; back--)
          () {
            final start = DateTime(
              lastWeek.year,
              lastWeek.month,
              lastWeek.day - 7 * back,
            );
            final end = DateTime(start.year, start.month, start.day + 7);
            return ComparisonPoint(
              start: start,
              spentMinor: spent(between(start, end)),
              partial: !end.isBefore(dateOnly(now)) && !start.isAfter(now),
            );
          }(),
      ];

    case ComparisonPeriod.monthly:
      return [
        for (var back = comparisonMonths - 1; back >= 0; back--)
          () {
            final start = DateTime(
              selectedMonth.year,
              selectedMonth.month - back,
            );
            final end = DateTime(start.year, start.month + 1);
            final txns = between(start, end).toList();
            return ComparisonPoint(
              start: start,
              spentMinor: spent(txns),
              savedMinor: income(txns) - spent(txns),
              partial: start.year == now.year && start.month == now.month,
            );
          }(),
      ];

    case ComparisonPeriod.yearly:
      // Up to three years ending at the selected one, but never earlier than the
      // first year anything was recorded: a person with a year of history sees
      // one bar, not three with two empty.
      final selectedYear = selectedMonth.year;
      var firstYear = selectedYear;
      for (final t in real) {
        if (t.date.year < firstYear) firstYear = t.date.year;
      }
      final from = [
        firstYear,
        selectedYear - (comparisonYears - 1),
      ].reduce((a, b) => a > b ? a : b);
      return [
        for (var year = from; year <= selectedYear; year++)
          () {
            final start = DateTime(year);
            final txns = between(start, DateTime(year + 1)).toList();
            return ComparisonPoint(
              start: start,
              spentMinor: spent(txns),
              savedMinor: income(txns) - spent(txns),
              partial: year == now.year,
            );
          }(),
      ];
  }
}
