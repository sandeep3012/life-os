import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/currency_utils.dart';
import '../../domain/category_spend.dart';
import '../../../../app/theme/app_fonts.dart';

class CategoryDonutChart extends StatefulWidget {
  const CategoryDonutChart({
    super.key,
    required this.breakdown,
    required this.totalMinor,
    required this.currencyCode,
    this.showAmounts = true,
  });

  final List<CategorySpend> breakdown;
  final int totalMinor;
  final String currencyCode;
  final bool showAmounts;

  @override
  State<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<CategoryDonutChart> {
  int? _selectedIndex;

  void _onTouch(FlTouchEvent event, PieTouchResponse? response) {
    if (event is! FlTapUpEvent) return;
    final idx = response?.touchedSection?.touchedSectionIndex;
    setState(() {
      if (idx == null || idx < 0 || idx == _selectedIndex) {
        _selectedIndex = null;
      } else {
        _selectedIndex = idx;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = (_selectedIndex != null &&
            _selectedIndex! >= 0 &&
            _selectedIndex! < widget.breakdown.length)
        ? widget.breakdown[_selectedIndex!]
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 38,
                  pieTouchData: PieTouchData(touchCallback: _onTouch),
                  sections: [
                    for (int i = 0; i < widget.breakdown.length; i++)
                      PieChartSectionData(
                        value: widget.breakdown[i].totalMinor.toDouble(),
                        color: _sliceColor(context, widget.breakdown[i])
                            .withValues(
                          alpha: _selectedIndex == null || _selectedIndex == i
                              ? 1.0
                              : 0.35,
                        ),
                        radius: _selectedIndex == i ? 20 : 16,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: selected != null
                    ? Column(
                        key: ValueKey(_selectedIndex),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatMinor(
                              selected.totalMinor,
                              currencyCode: widget.currencyCode,
                              showDecimals: false,
                            ),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontFamily: AppFonts.numeric,
                              fontFeatures: AppFonts.tabular,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${(selected.share * 100).round()}%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: _sliceColor(context, selected),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        key: const ValueKey('total'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatMinor(
                              widget.totalMinor,
                              currencyCode: widget.currencyCode,
                              showDecimals: false,
                            ),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontFamily: AppFonts.serif),
                          ),
                          Text(
                            'this month',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in widget.breakdown)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _sliceColor(context, entry),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (widget.showAmounts) ...[
                        Text(
                          formatMinor(
                            entry.totalMinor,
                            currencyCode: widget.currencyCode,
                            showDecimals: false,
                          ),
                          style: TextStyle(
                            fontFamily: AppFonts.numeric,
                            fontFeatures: AppFonts.tabular,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      SizedBox(
                        width: 36,
                        child: Text(
                          '${(entry.share * 100).round()}%',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontFamily: AppFonts.numeric,
                            fontFeatures: AppFonts.tabular,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Uncategorized has no colour of its own, so it takes a neutral from the
/// theme rather than borrowing a category hue and reading as a real category.
Color _sliceColor(BuildContext context, CategorySpend entry) {
  final category = entry.category;
  if (category == null) return Theme.of(context).colorScheme.outlineVariant;
  return Color(int.parse(category.colorHex.replaceFirst('#', '0xFF')));
}
