import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../settings/application/settings_providers.dart';
import '../../application/finance_providers.dart';
import '../../domain/finance_report.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPeriodType _periodType = ReportPeriodType.month;
  DateTime _anchor = DateTime.now();
  bool _exporting = false;

  ReportPeriod get _period => _periodType == ReportPeriodType.month
      ? ReportPeriod.forMonth(_anchor)
      : ReportPeriod.forYear(_anchor.year);

  void _shiftPeriod(int direction) {
    setState(() {
      _anchor = _periodType == ReportPeriodType.month
          ? DateTime(_anchor.year, _anchor.month + direction)
          : DateTime(_anchor.year + direction);
    });
  }

  Future<void> _export(FinanceReport report, Map<String, String> categoryNameById) async {
    setState(() => _exporting = true);
    try {
      final csv = reportToCsv(report, categoryNameById: categoryNameById);
      final fileName =
          'lifeos-report-${_periodType == ReportPeriodType.month ? DateFormat('yyyy-MM').format(_period.start) : _period.start.year}.csv';
      final path = await FilePicker.saveFile(
        dialogTitle: 'Save report',
        fileName: fileName,
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(path == null ? 'Export cancelled.' : 'Report saved.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not export report: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final transactions = ref.watch(transactionsProvider).value ?? const [];
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final categoryNameById = {for (final c in categories) c.id: c.name};
    final currencyCode = ref.watch(settingsProvider).currencyCode;
    final report = buildFinanceReport(
      period: _period,
      allTransactions: transactions,
      categories: categories,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SegmentedButton<ReportPeriodType>(
              segments: const [
                ButtonSegment(value: ReportPeriodType.month, label: Text('Monthly')),
                ButtonSegment(value: ReportPeriodType.year, label: Text('Yearly')),
              ],
              selected: {_periodType},
              onSelectionChanged: (s) => setState(() => _periodType = s.first),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => _shiftPeriod(-1),
                ),
                Text(_period.label, style: theme.textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => _shiftPeriod(1),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'Income',
                    valueMinor: report.totalIncomeMinor,
                    color: colors.good,
                    currencyCode: currencyCode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: 'Expense',
                    valueMinor: report.totalExpenseMinor,
                    color: colors.spend,
                    currencyCode: currencyCode,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SummaryCard(
              label: 'Net',
              valueMinor: report.netMinor,
              color: colors.finance,
              currencyCode: currencyCode,
              wide: true,
            ),
            const SizedBox(height: 20),
            if (report.categoryLines.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No expenses in this period', style: theme.textTheme.bodyMedium),
                ),
              )
            else ...[
              Text('By category', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final line in report.categoryLines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(line.categoryName)),
                      Text(
                        '${(line.share * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        formatMinor(line.spentMinor, currencyCode: currencyCode),
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _exporting || report.transactions.isEmpty
                    ? null
                    : () => _export(report, categoryNameById),
                icon: const Icon(Icons.download_rounded),
                label: Text(_exporting ? 'Exporting…' : 'Export as CSV'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.valueMinor,
    required this.color,
    required this.currencyCode,
    this.wide = false,
  });

  final String label;
  final int valueMinor;
  final Color color;
  final String currencyCode;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: wide
            ? Row(
                children: [
                  Expanded(child: Text(label, style: theme.textTheme.labelMedium)),
                  Text(
                    formatMinor(valueMinor, currencyCode: currencyCode, showSign: true),
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: color),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    formatMinor(valueMinor, currencyCode: currencyCode),
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: color),
                  ),
                ],
              ),
      ),
    );
  }
}
