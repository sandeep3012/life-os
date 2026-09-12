import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'finance_report.dart';

Future<Uint8List> reportToPdf(
  FinanceReport report, {
  required Map<String, String> categoryNameById,
  required String currencyCode,
}) async {
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Figtree-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Figtree-Bold.ttf'),
  );
  final document = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: bold),
  );
  String amount(int minor) =>
      '$currencyCode ${(minor / 100).toStringAsFixed(2)}';
  const palette = [
    '#6750E7',
    '#E87956',
    '#38A478',
    '#E8B14A',
    '#5096D0',
    '#B56AC6',
  ];
  // Keep small categories legible by grouping the tail in the chart only.
  final slices = report.categoryLines.take(5).toList();
  if (report.categoryLines.length > 5) {
    final tail = report.categoryLines
        .skip(5)
        .fold<int>(0, (sum, c) => sum + c.spentMinor);
    slices.add(
      CategoryReportLine(
        categoryName: 'Other categories',
        spentMinor: tail,
        share: tail / report.totalExpenseMinor,
      ),
    );
  }
  var angle = -math.pi / 2;
  final paths = StringBuffer();
  for (var i = 0; i < slices.length; i++) {
    final sweep = slices[i].share * 2 * math.pi;
    if (sweep >= 2 * math.pi - 0.00001) {
      paths.write('<circle cx="110" cy="110" r="95" fill="${palette[i]}"/>');
    } else {
      final x1 = 110 + 95 * math.cos(angle);
      final y1 = 110 + 95 * math.sin(angle);
      final x2 = 110 + 95 * math.cos(angle + sweep);
      final y2 = 110 + 95 * math.sin(angle + sweep);
      paths.write(
        '<path d="M110 110 L$x1 $y1 A95 95 0 ${sweep > math.pi ? 1 : 0} 1 $x2 $y2 Z" fill="${palette[i]}"/>',
      );
    }
    angle += sweep;
  }
  final peak = math.max(
    1,
    math.max(report.totalIncomeMinor, report.totalExpenseMinor),
  );
  final incomeHeight = 130 * report.totalIncomeMinor / peak;
  final expenseHeight = 130 * report.totalExpenseMinor / peak;
  final bars =
      '<svg xmlns="http://www.w3.org/2000/svg" width="220" height="160">'
      '<path d="M10 150 H210" stroke="#CCCCCC"/>'
      '<rect x="35" y="${150 - incomeHeight}" width="55" height="$incomeHeight" fill="#38A478"/>'
      '<rect x="130" y="${150 - expenseHeight}" width="55" height="$expenseHeight" fill="#E87956"/>'
      '</svg>';
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      maxPages: 1000,
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'LifeOS | ${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ),
      build: (context) => [
        pw.Text(
          'LifeOS Finance Report',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text('${report.period.label} | Currency: $currencyCode'),
        pw.SizedBox(height: 18),
        pw.Text(
          'Income: ${amount(report.totalIncomeMinor)}    Expense: ${amount(report.totalExpenseMinor)}',
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Net: ${amount(report.netMinor)}',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 24),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Text('Expenses by category'),
                  pw.SizedBox(height: 10),
                  if (slices.isEmpty)
                    pw.SizedBox(
                      height: 180,
                      child: pw.Center(child: pw.Text('No expenses')),
                    )
                  else
                    pw.SvgImage(
                      svg:
                          '<svg xmlns="http://www.w3.org/2000/svg" width="220" height="220">$paths</svg>',
                      width: 180,
                      height: 180,
                    ),
                  for (var i = 0; i < slices.length; i++)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 5),
                      child: pw.Row(
                        children: [
                          pw.Container(
                            width: 8,
                            height: 8,
                            color: PdfColor.fromHex(palette[i]),
                          ),
                          pw.SizedBox(width: 6),
                          pw.Expanded(
                            child: pw.Text(
                              '${slices[i].categoryName}: ${(slices[i].share * 100).toStringAsFixed(1)}%',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            pw.SizedBox(width: 24),
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Text('Income vs expense'),
                  pw.SizedBox(height: 20),
                  pw.SvgImage(svg: bars, width: 220, height: 160),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Green: Income    Orange: Expense',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    '${amount(report.totalIncomeMinor)} / ${amount(report.totalExpenseMinor)}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 24),
        pw.Text(
          'Category breakdown',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: ['Category', 'Spent ($currencyCode)', 'Share'],
          data: [
            for (final c in report.categoryLines)
              [
                c.categoryName,
                (c.spentMinor / 100).toStringAsFixed(2),
                '${(c.share * 100).toStringAsFixed(1)}%',
              ],
          ],
        ),
        pw.NewPage(),
        pw.Text(
          'Transactions - ${report.period.label}',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          cellStyle: const pw.TextStyle(fontSize: 9),
          headers: [
            'Date',
            'Merchant',
            'Category',
            'Payment',
            'Amount ($currencyCode)',
          ],
          data: [
            for (final t in report.transactions)
              [
                t.date.toIso8601String().substring(0, 10),
                t.merchant,
                categoryNameById[t.categoryId] ?? 'Uncategorized',
                t.paymentMode ?? '',
                (t.amountMinor / 100).toStringAsFixed(2),
              ],
          ],
        ),
      ],
    ),
  );
  return document.save();
}
