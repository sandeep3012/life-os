import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/finance/domain/finance_report.dart';
import 'package:life_manager/features/finance/domain/finance_report_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('PDF generation supports zero expenses and a full-circle category', () async {
    for (final expense in [0, 10000]) {
      final report = FinanceReport(
        period: ReportPeriod.forMonth(DateTime(2026, 9)),
        totalIncomeMinor: 20000,
        totalExpenseMinor: expense,
        categoryLines: expense == 0 ? [] : [CategoryReportLine(categoryName: 'Food', spentMinor: expense, share: 1)],
        transactions: [],
      );
      final bytes = await reportToPdf(report, categoryNameById: {}, currencyCode: 'INR');
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    }
  });
}
