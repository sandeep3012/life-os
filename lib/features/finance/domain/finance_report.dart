import '../../../core/database/app_database.dart';

/// aggregate over a calendar month, or a whole calendar year.
enum ReportPeriodType { month, year, custom }

/// [start] inclusive, [end] exclusive.
class ReportPeriod {
  const ReportPeriod({
    required this.type,
    required this.start,
    required this.end,
    required this.label,
  });

  final ReportPeriodType type;
  final DateTime start;
  final DateTime end;
  final String label;

  static ReportPeriod custom(DateTime first, DateTime last) {
    final start = DateTime(first.year, first.month, first.day);
    final end = DateTime(last.year, last.month, last.day + 1);
    if (!end.isAfter(start)) {
      throw ArgumentError('End date must not precede start date');
    }
    return ReportPeriod(
      type: ReportPeriodType.custom,
      start: start,
      end: end,
      label:
          '${start.toIso8601String().substring(0, 10)} – ${last.toIso8601String().substring(0, 10)}',
    );
  }

  ReportPeriod get previous {
    if (type == ReportPeriodType.month) {
      return forMonth(DateTime(start.year, start.month - 1));
    }
    if (type == ReportPeriodType.year) return forYear(start.year - 1);
    final days = DateTime.utc(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
    return custom(
      DateTime(start.year, start.month, start.day - days),
      DateTime(start.year, start.month, start.day - 1),
    );
  }

  static ReportPeriod forMonth(DateTime anyDayInMonth) {
    final start = DateTime(anyDayInMonth.year, anyDayInMonth.month);
    final end = DateTime(anyDayInMonth.year, anyDayInMonth.month + 1);
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return ReportPeriod(
      type: ReportPeriodType.month,
      start: start,
      end: end,
      label: '${months[start.month - 1]} ${start.year}',
    );
  }

  static ReportPeriod forYear(int year) {
    return ReportPeriod(
      type: ReportPeriodType.year,
      start: DateTime(year),
      end: DateTime(year + 1),
      label: '$year',
    );
  }
}

class CategoryReportLine {
  const CategoryReportLine({
    required this.categoryName,
    required this.spentMinor,
    required this.share,
  });

  final String categoryName;
  final int spentMinor;

  /// 0..1 fraction of total expense this category accounts for.
  final double share;
}

/// Everything a report screen or CSV export needs for one period — pure
/// data, computed once and reused by both the on-screen preview and the
/// exported file so they can never disagree.
class FinanceReport {
  const FinanceReport({
    required this.period,
    required this.totalIncomeMinor,
    required this.totalExpenseMinor,
    required this.categoryLines,
    required this.transactions,
    this.scopeLabel = 'All accounts · All categories',
    this.previous,
  });

  final ReportPeriod period;
  final int totalIncomeMinor;
  final int totalExpenseMinor;
  final List<CategoryReportLine> categoryLines;
  final List<Transaction> transactions;
  final String scopeLabel;
  final FinanceReport? previous;

  int get netMinor => totalIncomeMinor - totalExpenseMinor;
}

/// Pure aggregation — no DB/Riverpod access, same seam-for-testability
/// pattern as `computeInsights` in the AI Analyser.
FinanceReport buildFinanceReport({
  required ReportPeriod period,
  required List<Transaction> allTransactions,
  required List<Category> categories,
  String? accountId,
  String? categoryId,
  String scopeLabel = 'All accounts · All categories',
  bool comparePrevious = false,
}) {
  final inPeriod =
      allTransactions
          .where(
            (t) =>
                t.paymentMode != 'transfer' &&
                (accountId == null || t.accountId == accountId) &&
                (categoryId == null ||
                    (categoryId.isEmpty
                        ? t.categoryId == null
                        : t.categoryId == categoryId)) &&
                !t.date.isBefore(period.start) &&
                t.date.isBefore(period.end),
          )
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  final income = inPeriod
      .where((t) => t.amountMinor > 0)
      .fold<int>(0, (sum, t) => sum + t.amountMinor);
  final expense = inPeriod
      .where((t) => t.amountMinor < 0)
      .fold<int>(0, (sum, t) => sum + t.amountMinor.abs());

  final categoryById = {for (final c in categories) c.id: c};
  final spentByCategory = <String, int>{};
  for (final t in inPeriod.where((t) => t.amountMinor < 0)) {
    final name = categoryById[t.categoryId]?.name ?? 'Uncategorized';
    spentByCategory[name] = (spentByCategory[name] ?? 0) + t.amountMinor.abs();
  }
  final categoryLines = [
    for (final entry in spentByCategory.entries)
      CategoryReportLine(
        categoryName: entry.key,
        spentMinor: entry.value,
        share: expense == 0 ? 0 : entry.value / expense,
      ),
  ]..sort((a, b) => b.spentMinor.compareTo(a.spentMinor));

  return FinanceReport(
    period: period,
    totalIncomeMinor: income,
    totalExpenseMinor: expense,
    categoryLines: categoryLines,
    transactions: inPeriod,
    scopeLabel: scopeLabel,
    previous: comparePrevious
        ? buildFinanceReport(
            period: period.previous,
            allTransactions: allTransactions,
            categories: categories,
            accountId: accountId,
            categoryId: categoryId,
            scopeLabel: scopeLabel,
          )
        : null,
  );
}

String _csvField(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

String _csvRow(List<String> fields) => fields.map(_csvField).join(',');

String _rupees(int minor) => (minor / 100).toStringAsFixed(2);

/// Two sections in one file — a summary block, then the full transaction
/// list — separated by a blank line, a common lightweight convention for
/// multi-table CSVs that keeps this a single downloadable file instead of a
/// zip of several.
String reportToCsv(
  FinanceReport report, {
  required Map<String, String> categoryNameById,
}) {
  final buffer = StringBuffer();

  buffer.writeln('LifeOS Finance Report');
  buffer.writeln(_csvRow(['Period', report.period.label]));
  buffer.writeln(_csvRow(['Filters', report.scopeLabel]));
  buffer.writeln(_csvRow(['Total income', _rupees(report.totalIncomeMinor)]));
  buffer.writeln(_csvRow(['Total expense', _rupees(report.totalExpenseMinor)]));
  buffer.writeln(_csvRow(['Net', _rupees(report.netMinor)]));
  if (report.previous case final previous?) {
    buffer.writeln(_csvRow(['Compared with', previous.period.label]));
    buffer.writeln(_csvRow(['Metric', 'Previous', 'Change']));
    for (final row in [
      ('Income', previous.totalIncomeMinor, report.totalIncomeMinor),
      ('Expense', previous.totalExpenseMinor, report.totalExpenseMinor),
      ('Net', previous.netMinor, report.netMinor),
    ]) {
      buffer.writeln(
        _csvRow([row.$1, _rupees(row.$2), _rupees(row.$3 - row.$2)]),
      );
    }
  }
  buffer.writeln();

  buffer.writeln(_csvRow(['Category', 'Spent', 'Share of expense']));
  for (final line in report.categoryLines) {
    buffer.writeln(
      _csvRow([
        line.categoryName,
        _rupees(line.spentMinor),
        '${(line.share * 100).toStringAsFixed(1)}%',
      ]),
    );
  }
  buffer.writeln();

  buffer.writeln(
    _csvRow(['Date', 'Merchant', 'Category', 'Payment mode', 'Amount']),
  );
  for (final t in report.transactions) {
    buffer.writeln(
      _csvRow([
        t.date.toIso8601String().substring(0, 10),
        t.merchant,
        categoryNameById[t.categoryId] ?? 'Uncategorized',
        t.paymentMode ?? '',
        _rupees(t.amountMinor),
      ]),
    );
  }

  return buffer.toString();
}
