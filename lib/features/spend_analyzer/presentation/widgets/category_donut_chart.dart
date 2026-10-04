import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/currency_utils.dart';
import '../../domain/category_spend.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../core/utils/category_color.dart';
import '../../../../app/motion.dart';

/// The chart's box, and the hole inside its ring. The ring is 16 thick (20 for
/// a selected slice), so the box must be at least `_holeRadius + 20` across the
/// half — 62 of the 64 available.
const double _chartSize = 128;
const double _holeRadius = 42;

/// Widest the centre text may be: the hole's diameter less a margin, so it
/// can never reach the ring. A two-line block sits above and below the centre
/// where the hole is a little narrower than its diameter, hence the margin.
const double _centreTextWidth = 70;

class CategoryDonutChart extends StatefulWidget {
  const CategoryDonutChart({
    super.key,
    required this.breakdown,
    required this.totalMinor,
    required this.currencyCode,
    required this.monthLabel,
    this.showAmounts = true,
  });

  final List<CategorySpend> breakdown;
  final int totalMinor;
  final String currencyCode;

  /// The month the breakdown is for, e.g. "Oct 2026". The Spend Analyzer can
  /// browse other months, so a fixed "this month" caption was wrong for all of
  /// them.
  final String monthLabel;
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
    final selected =
        (_selectedIndex != null &&
            _selectedIndex! >= 0 &&
            _selectedIndex! < widget.breakdown.length)
        ? widget.breakdown[_selectedIndex!]
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: _chartSize,
          height: _chartSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: _holeRadius,
                  pieTouchData: PieTouchData(touchCallback: _onTouch),
                  sections: [
                    for (int i = 0; i < widget.breakdown.length; i++)
                      PieChartSectionData(
                        value: widget.breakdown[i].totalMinor.toDouble(),
                        color: _sliceColor(context, widget.breakdown[i])
                            .withValues(
                              alpha:
                                  _selectedIndex == null || _selectedIndex == i
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
                duration: AppMotion.of(
                  context,
                  const Duration(milliseconds: 180),
                ),
                child: selected != null
                    ? SizedBox(
                        key: ValueKey(_selectedIndex),
                        width: _centreTextWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _FitLine(
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
                            _FitLine(
                              '${(selected.share * 100).round()}%',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: _sliceColor(context, selected),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SizedBox(
                        key: const ValueKey('total'),
                        width: _centreTextWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Scales down rather than wrapping or overflowing:
                            // a large total (₹1,09,135 and up) is wider than
                            // the hole, and used to run onto the ring.
                            _FitLine(
                              formatMinor(
                                widget.totalMinor,
                                currencyCode: widget.currencyCode,
                                showDecimals: false,
                              ),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontFamily: AppFonts.serif,
                              ),
                            ),
                            _FitLine(
                              widget.monthLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
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
/// A category the user left on "No color" takes a different neutral, so the
/// two stay tellable apart in the legend.
Color _sliceColor(BuildContext context, CategorySpend entry) {
  final category = entry.category;
  if (category == null) return Theme.of(context).colorScheme.outlineVariant;
  return categoryColor(category.colorHex) ??
      Theme.of(context).colorScheme.onSurfaceVariant;
}

/// One centred line that shrinks to fit its parent's width instead of
/// overflowing it. Never grows past its natural size.
class _FitLine extends StatelessWidget {
  const _FitLine(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(text, style: style, maxLines: 1, softWrap: false),
  );
}
