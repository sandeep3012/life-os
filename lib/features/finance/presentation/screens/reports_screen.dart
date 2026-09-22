import '../../../../core/widgets/tab_rail.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../../settings/application/settings_providers.dart';
import '../../application/finance_providers.dart';
import '../widgets/account_option_row.dart';
import '../../domain/finance_report.dart';
import '../../domain/finance_report_pdf.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPeriodType _periodType = ReportPeriodType.month;
  DateTime _anchor = DateTime.now();
  final Set<String> _exportingFormats = {};
  DateTimeRange? _customRange;
  String? _accountId;
  String? _categoryId;

  ReportPeriod get _period => _periodType == ReportPeriodType.custom
      ? ReportPeriod.custom(
          _customRange?.start ?? _anchor,
          _customRange?.end ?? _anchor,
        )
      : _periodType == ReportPeriodType.month
      ? ReportPeriod.forMonth(_anchor)
      : ReportPeriod.forYear(_anchor.year);

  void _shiftPeriod(int direction) {
    setState(() {
      _anchor = _periodType == ReportPeriodType.month
          ? DateTime(_anchor.year, _anchor.month + direction)
          : DateTime(_anchor.year + direction);
    });
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
      initialDateRange: _customRange,
    );
    if (range != null && mounted) {
      setState(() {
        _customRange = range;
        _periodType = ReportPeriodType.custom;
      });
    }
  }

  Future<void> _export(
    FinanceReport report,
    Map<String, String> categoryNameById, {
    bool pdf = false,
  }) async {
    final format = pdf ? 'pdf' : 'csv';
    if (_exportingFormats.contains(format)) return;
    setState(() => _exportingFormats.add(format));
    try {
      final bytes = pdf
          ? await reportToPdf(
              report,
              categoryNameById: categoryNameById,
              currencyCode: ref.read(settingsProvider).currencyCode,
            )
          : Uint8List.fromList(
              utf8.encode(
                reportToCsv(report, categoryNameById: categoryNameById),
              ),
            );
      final fileName =
          'lifeos-report-${DateFormat('yyyy-MM-dd').format(report.period.start)}-to-${DateFormat('yyyy-MM-dd').format(report.period.end.subtract(const Duration(days: 1)))}.${pdf ? 'pdf' : 'csv'}';
      final path = await FilePicker.saveFile(
        dialogTitle: 'Save report',
        fileName: fileName,
        bytes: bytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(path == null ? 'Export cancelled.' : 'Report saved.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not export report: $e')));
      }
    } finally {
      if (mounted) setState(() => _exportingFormats.remove(format));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final transactionState = ref.watch(transactionsProvider);
    final categoryState = ref.watch(categoriesProvider);
    final transactions = transactionState.value ?? const [];
    final categories = categoryState.value ?? const [];
    final exportReady =
        transactionState.hasValue &&
        !transactionState.hasError &&
        categoryState.hasValue &&
        !categoryState.hasError;
    final categoryNameById = {for (final c in categories) c.id: c.name};
    final currencyCode = ref.watch(settingsProvider).currencyCode;
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final accountTypes = ref.watch(accountTypesProvider).value ?? const [];
    final scope =
        '${_accountId == null ? 'All accounts' : accounts.where((a) => a.id == _accountId).firstOrNull?.name ?? 'Selected account'} · ${_categoryId == null
            ? 'All categories'
            : _categoryId == ''
            ? 'Uncategorized'
            : categoryNameById[_categoryId] ?? 'Selected category'}';
    final report = buildFinanceReport(
      period: _period,
      allTransactions: transactions,
      categories: categories,
      accountId: _accountId,
      categoryId: _categoryId,
      scopeLabel: scope,
      comparePrevious: true,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AppTabRail<ReportPeriodType>(
              value: _periodType,
              labels: const {
                ReportPeriodType.month: 'Monthly',
                ReportPeriodType.year: 'Yearly',
                ReportPeriodType.custom: 'Custom',
              },
              icons: const {
                ReportPeriodType.month: LucideIcons.calendarDays,
                ReportPeriodType.year: LucideIcons.calendarRange,
                ReportPeriodType.custom: LucideIcons.calendarSearch,
              },
              onChanged: (value) {
                if (value == ReportPeriodType.custom) {
                  _pickRange();
                } else {
                  setState(() => _periodType = value);
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.chevronLeft),
                  onPressed: _periodType == ReportPeriodType.custom
                      ? null
                      : () => _shiftPeriod(-1),
                ),
                Expanded(
                  child: Text(
                    _period.label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.chevronRight),
                  onPressed: _periodType == ReportPeriodType.custom
                      ? null
                      : () => _shiftPeriod(1),
                ),
              ],
            ),
            if (_periodType == ReportPeriodType.custom)
              TextButton(
                onPressed: _pickRange,
                child: const Text('Change dates'),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _accountId ?? 'all',
              decoration: const InputDecoration(labelText: 'Account'),
              isExpanded: true,
              items: [
                const DropdownMenuItem(
                  value: 'all',
                  child: _CategoryOption(
                    icon: Icon(LucideIcons.layers, size: 16),
                    label: 'All accounts',
                  ),
                ),
                if (_accountId != null &&
                    !accounts.any((a) => a.id == _accountId))
                  const DropdownMenuItem(
                    value: null,
                    child: _CategoryOption(
                      icon: Icon(LucideIcons.landmark, size: 16),
                      label: 'Unavailable account',
                    ),
                  ),
                for (final a in accounts)
                  DropdownMenuItem(
                    value: a.id,
                    child: OptionRow.account(a, accountTypes),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _accountId = value == 'all' ? null : value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categoryId ?? 'all',
              decoration: const InputDecoration(labelText: 'Category'),
              isExpanded: true,
              items: [
                const DropdownMenuItem(
                  value: 'all',
                  child: _CategoryOption(
                    icon: Icon(LucideIcons.layers, size: 16),
                    label: 'All categories',
                  ),
                ),
                const DropdownMenuItem(
                  value: '',
                  child: _CategoryOption(
                    icon: IconOrEmoji(value: null, size: 16),
                    label: 'Uncategorized',
                  ),
                ),
                if (_categoryId != null &&
                    _categoryId != '' &&
                    !categories.any((c) => c.id == _categoryId))
                  DropdownMenuItem(
                    value: _categoryId,
                    child: const _CategoryOption(
                      icon: IconOrEmoji(value: null, size: 16),
                      label: 'Unavailable category',
                    ),
                  ),
                for (final c in categories)
                  DropdownMenuItem(
                    value: c.id,
                    child: _CategoryOption(
                      icon: IconOrEmoji(value: c.icon, size: 16),
                      label: c.name,
                    ),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _categoryId = value == 'all' ? null : value),
            ),
            const SizedBox(height: 16),
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
                  child: Text(
                    'No expenses in this period',
                    style: theme.textTheme.bodyMedium,
                  ),
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
                        formatMinor(
                          line.spentMinor,
                          currencyCode: currencyCode,
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _exportingFormats.contains('pdf') || !exportReady
                    ? null
                    : () => _export(report, categoryNameById, pdf: true),
                icon: _exportingFormats.contains('pdf')
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.fileText),
                label: Text(
                  _exportingFormats.contains('pdf')
                      ? 'Exporting PDF…'
                      : 'Export as PDF',
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _exportingFormats.contains('csv') || !exportReady
                    ? null
                    : () => _export(report, categoryNameById),
                icon: _exportingFormats.contains('csv')
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.download),
                label: Text(
                  _exportingFormats.contains('csv')
                      ? 'Exporting CSV…'
                      : 'Export as CSV',
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (report.previous case final previous?)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compared with ${previous.period.label}',
                        style: theme.textTheme.titleSmall,
                      ),
                      const Text(
                        'Full selected periods; the current period may be incomplete.',
                      ),
                      for (final row in [
                        (
                          'Income',
                          report.totalIncomeMinor - previous.totalIncomeMinor,
                        ),
                        (
                          'Expense',
                          report.totalExpenseMinor - previous.totalExpenseMinor,
                        ),
                        ('Net', report.netMinor - previous.netMinor),
                      ])
                        Text(
                          '${row.$1} change: ${formatMinor(row.$2, currencyCode: currencyCode, showSign: true)}',
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One row of the category filter: glyph, then name. Kept in one place so the
/// real categories and the "all"/"uncategorized" rows align identically.
class _CategoryOption extends StatelessWidget {
  const _CategoryOption({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: dropdownIconGap),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
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
                  Expanded(
                    child: Text(label, style: theme.textTheme.labelMedium),
                  ),
                  Text(
                    formatMinor(
                      valueMinor,
                      currencyCode: currencyCode,
                      showSign: true,
                    ),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
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
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
