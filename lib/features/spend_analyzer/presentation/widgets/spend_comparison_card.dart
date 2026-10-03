import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/motion.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../application/spend_analyzer_providers.dart';
import '../../domain/axis_scale.dart';
import '../../domain/comparison_points.dart';
import '../../../../core/widgets/tappable.dart';
import 'chart_style.dart';

/// Spending against savings over the last weeks, months or years, as paired
/// bars with a scaled axis. Weekly shows spending alone: income arrives in
/// lumps, so a weekly "saved" bar would be a big gain in the pay week and a loss
/// in all the others.
class SpendComparisonCard extends ConsumerStatefulWidget {
  const SpendComparisonCard({super.key, required this.currencyCode});

  final String currencyCode;

  @override
  ConsumerState<SpendComparisonCard> createState() =>
      _SpendComparisonCardState();
}

class _SpendComparisonCardState extends ConsumerState<SpendComparisonCard> {
  ComparisonPeriod _period = ComparisonPeriod.monthly;

  /// The group whose exact figures are shown; the last one until one is tapped.
  int? _selected;

  /// A bubble with the exact figures, shown after a bar is tapped.
  bool _callout = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final points = ref.watch(comparisonPointsProvider(_period));
    final selected = (_selected ?? points.length - 1).clamp(
      0,
      points.length - 1,
    );
    final showsSaved = _period != ComparisonPeriod.weekly;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PeriodTabs(
              value: _period,
              onChanged: (period) => setState(() {
                _period = period;
                _selected = null;
                _callout = false;
              }),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: _AnimatedBarChart(
                points: points,
                period: _period,
                currencyCode: widget.currencyCode,
                selected: selected,
                showCallout: _callout,
                onSelect: (i) => setState(() {
                  // Tapping the group that is already showing its callout
                  // dismisses it.
                  _callout = !(_callout && i == selected);
                  _selected = i;
                }),
              ),
            ),
            const SizedBox(height: 4),
            // Just the key. What the bars span is in the tab above; the exact
            // figures are the amounts on the bars.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: colors.spend, label: 'Spending'),
                if (showsSaved) ...[
                  const SizedBox(width: 16),
                  _LegendDot(color: colors.good, label: 'Savings'),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A rounded track holding Weekly / Monthly / Yearly, the chosen one lifted on a
/// soft accent pill, each with how far back it goes underneath — "Monthly (6M)".
class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.value, required this.onChanged});

  final ComparisonPeriod value;
  final ValueChanged<ComparisonPeriod> onChanged;

  static const _tabs = [
    (ComparisonPeriod.weekly, 'Weekly', '(4W)'),
    (ComparisonPeriod.monthly, 'Monthly', '(6M)'),
    (ComparisonPeriod.yearly, 'Yearly', '(3Y)'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final duration = AppMotion.of(context, AppMotion.navColor);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final (period, label, range) in _tabs)
            Expanded(
              child: Tappable(
                onTap: () => onChanged(period),
                haptic: TapHaptic.selection,
                semanticLabel: '$label $range',
                selected: period == value,
                child: AnimatedContainer(
                  duration: duration,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: period == value
                        ? colors.accentSoft
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$label\n$range',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 11.5,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: period == value
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

String _shortLabel(ComparisonPoint p, ComparisonPeriod period) =>
    switch (period) {
      ComparisonPeriod.weekly => DateFormat('d MMM').format(p.start),
      ComparisonPeriod.monthly => DateFormat.MMM().format(p.start),
      ComparisonPeriod.yearly => '${p.start.year}',
    };

String _fullLabel(
  ComparisonPoint p,
  ComparisonPeriod period,
) => switch (period) {
  ComparisonPeriod.weekly =>
    '${DateFormat('d MMM').format(p.start)} – ${DateFormat('d MMM').format(DateTime(p.start.year, p.start.month, p.start.day + 6))}',
  ComparisonPeriod.monthly => DateFormat.yMMM().format(p.start),
  ComparisonPeriod.yearly => '${p.start.year}',
};

/// Plays the transition when the chart's data changes — switching between
/// weekly, monthly and yearly, or stepping to another month: the old bars shrink
/// back to the baseline while the axis fades out, then the new ones grow up from
/// it one after another, left to right, and the axis fades back in.
///
/// With reduced motion the new chart simply appears.
class _AnimatedBarChart extends StatefulWidget {
  const _AnimatedBarChart({
    required this.points,
    required this.period,
    required this.currencyCode,
    required this.selected,
    required this.onSelect,
    required this.showCallout,
  });

  final List<ComparisonPoint> points;
  final ComparisonPeriod period;
  final String currencyCode;
  final int selected;
  final ValueChanged<int> onSelect;
  final bool showCallout;

  @override
  State<_AnimatedBarChart> createState() => _AnimatedBarChartState();
}

class _AnimatedBarChartState extends State<_AnimatedBarChart>
    with SingleTickerProviderStateMixin {
  /// Where in the 0..1 timeline the old bars are gone and the new ones start.
  static const _exitEnd = 0.28;
  static const _enterStart = 0.18;

  /// How long one group takes to grow, and how much of the timeline is spent
  /// staggering the groups' starts.
  static const _growSpan = 0.5;
  static const _stagger = 0.3;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.chartSwitch,
    value: 1,
  );

  /// What was on screen before the latest change, while it is still leaving.
  ({List<ComparisonPoint> points, ComparisonPeriod period})? _previous;

  @override
  void didUpdateWidget(_AnimatedBarChart old) {
    super.didUpdateWidget(old);
    final changed =
        old.period != widget.period || !_samePoints(old.points, widget.points);
    if (!changed) return;

    if (MediaQuery.of(context).disableAnimations) {
      _previous = null;
      _controller.value = 1;
      return;
    }
    _previous = (points: old.points, period: old.period);
    _controller.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _previous = null);
    });
  }

  static bool _samePoints(List<ComparisonPoint> a, List<ComparisonPoint> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].start != b[i].start ||
          a[i].spentMinor != b[i].spentMinor ||
          a[i].savedMinor != b[i].savedMinor) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = AppMotion.curveOf(context, Curves.easeOutCubic);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final previous = _previous;
        final leaving = previous != null && t < _exitEnd;
        final leave = (t / _exitEnd).clamp(0.0, 1.0);
        final count = widget.points.length;

        // Group i starts a little after group i-1, so the bars ripple in.
        double grow(int i) {
          final start =
              _enterStart + (count <= 1 ? 0 : _stagger * i / (count - 1));
          return curve.transform(((t - start) / _growSpan).clamp(0.0, 1.0));
        }

        return Stack(
          children: [
            if (leaving)
              Positioned.fill(
                child: IgnorePointer(
                  child: _BarChart(
                    points: previous.points,
                    period: previous.period,
                    currencyCode: widget.currencyCode,
                    selected: -1,
                    onSelect: (_) {},
                    showCallout: false,
                    interactive: false,
                    // Back down to the baseline, quickly, as the axis fades.
                    grow: (_) => 1 - Curves.easeIn.transform(leave),
                    fade: 1 - leave,
                  ),
                ),
              ),
            Positioned.fill(
              child: _BarChart(
                points: widget.points,
                period: widget.period,
                currencyCode: widget.currencyCode,
                selected: widget.selected,
                onSelect: widget.onSelect,
                showCallout: widget.showCallout,
                grow: grow,
                // The axis returns while the bars are growing.
                fade: Curves.easeOut.transform(
                  ((t - _enterStart) / 0.4).clamp(0.0, 1.0),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The chart: dashed gridlines, a scaled axis, and a pair of rounded bars per
/// group (one for weekly). Built from plain widgets so every number is real,
/// selectable text — and so it can be tested.
class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.points,
    required this.period,
    required this.currencyCode,
    required this.selected,
    required this.onSelect,
    required this.showCallout,
    this.interactive = true,
    this.grow = _fullyGrown,
    this.fade = 1,
  });

  final List<ComparisonPoint> points;
  final ComparisonPeriod period;
  final String currencyCode;
  final int selected;
  final ValueChanged<int> onSelect;
  final bool showCallout;

  /// False for the layer that is on its way out: it can't be tapped, has no
  /// selection and shows no callout.
  final bool interactive;

  /// How far group [i]'s bars have grown, 0 (flat on the baseline) to 1. Driven
  /// by [_AnimatedBarChart] to grow the bars in and shrink them away.
  final double Function(int i) grow;

  /// The opacity of the axis, gridlines and labels.
  final double fade;

  static double _fullyGrown(int i) => 1;

  static const double _axisWidth = 40;

  /// [formatCompactMinor] drops the sign — it's for totals — but here a value
  /// below zero is the point, so put it back.
  static String _signed(int minor, String currencyCode) =>
      '${minor < 0 ? '-' : ''}${formatCompactMinor(minor, currencyCode: currencyCode)}';
  static const double _labelRow = 18;
  static const double _topRoom = 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;
    final showsSaved = period != ComparisonPeriod.weekly;
    // Amounts above every bar where there's room (weekly, yearly). Six months of
    // paired bars are too tight for that — the labels ran into each other — so
    // the monthly view shows its figures in a callout when a bar is tapped.
    final labelEveryGroup = period != ComparisonPeriod.monthly;

    // Major units: the scale and the pixel maths don't care about paise.
    double major(int minor) => minor / 100;
    var lowest = 0.0;
    var highest = 0.0;
    for (final p in points) {
      highest = [
        highest,
        major(p.spentMinor),
        major(p.savedMinor ?? 0),
      ].reduce((a, b) => a > b ? a : b);
      lowest = [
        lowest,
        major(p.savedMinor ?? 0),
      ].reduce((a, b) => a < b ? a : b);
    }
    final scale = niceAxisScale(lowest: lowest, highest: highest);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final plotLeft = _axisWidth;
        final plotWidth = width - plotLeft;
        final plotTop = labelEveryGroup ? _topRoom : 6.0;
        final plotHeight = constraints.maxHeight - plotTop - _labelRow;
        final groupWidth = plotWidth / points.length;

        double yFor(double value) =>
            plotTop + (scale.max - value) / scale.span * plotHeight;
        final zeroY = yFor(0);

        final rods = showsSaved ? 2 : 1;
        final rodWidth = (groupWidth * (rods == 2 ? 0.27 : 0.42)).clamp(
          8.0,
          26.0,
        );
        const rodGap = 3.0;
        final clusterWidth = rodWidth * rods + rodGap * (rods - 1);

        final labelStyle = TextStyle(
          fontFamily: AppFonts.numeric,
          fontFeatures: AppFonts.tabular,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        );
        final axisStyle = TextStyle(
          fontFamily: AppFonts.numeric,
          fontFeatures: AppFonts.tabular,
          fontSize: 9.5,
          color: scheme.onSurfaceVariant,
        );

        Widget rod({
          required int index,
          required double left,
          required double value,
          required Color color,
        }) {
          final full = (yFor(0) - yFor(value)).abs().clamp(2.0, plotHeight);
          final height = full * grow(index);
          final negative = value < 0;
          return Positioned(
            left: left,
            width: rodWidth,
            top: negative ? zeroY : zeroY - height,
            height: height,
            child: DecoratedBox(
              // Square-ended, like an ordinary bar chart.
              decoration: BoxDecoration(color: color),
            ),
          );
        }

        Widget valueLabel({
          required int index,
          required double centreX,
          required double value,
          required int minor,
        }) {
          final negative = value < 0;
          final g = grow(index);
          final barEnd = yFor(value * g);
          return Positioned(
            left: centreX - 30,
            width: 60,
            top: negative ? barEnd + 2 : barEnd - 14,
            height: 12,
            child: Opacity(
              opacity: ((g - 0.6) / 0.4).clamp(0.0, 1.0),
              child: Center(
                child: Text(
                  _signed(minor, currencyCode),
                  maxLines: 1,
                  softWrap: false,
                  style: labelStyle,
                ),
              ),
            ),
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Dashed gridlines, with the zero line solid.
            Positioned.fill(
              child: Opacity(
                opacity: fade,
                child: CustomPaint(
                  painter: _GridPainter(
                    ticks: scale.ticks.map(yFor).toList(),
                    zeroY: zeroY,
                    left: plotLeft,
                    color: chartGridColor(scheme),
                  ),
                ),
              ),
            ),
            // The axis: a short amount at each gridline.
            for (final tick in scale.ticks)
              Positioned(
                left: 0,
                width: _axisWidth - 6,
                top: yFor(tick) - 7,
                height: 14,
                child: Opacity(
                  opacity: fade,
                  child: Text(
                    _signed((tick * 100).round(), currencyCode),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    softWrap: false,
                    style: axisStyle,
                  ),
                ),
              ),
            for (var i = 0; i < points.length; i++) ...[
              // The selected group sits on a soft pill.
              if (interactive && i == selected)
                Positioned(
                  left: plotLeft + i * groupWidth + 2,
                  width: groupWidth - 4,
                  top: 0,
                  bottom: 0,
                  // Fades in with the axis, so it doesn't sit there at full
                  // strength while the previous chart is still leaving.
                  child: Opacity(
                    opacity: fade,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        // Light enough to read as a hint, not a block.
                        color: scheme.surfaceContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              rod(
                index: i,
                left:
                    plotLeft + i * groupWidth + (groupWidth - clusterWidth) / 2,
                value: major(points[i].spentMinor),
                color: colors.spend,
              ),
              if (showsSaved)
                rod(
                  index: i,
                  left:
                      plotLeft +
                      i * groupWidth +
                      (groupWidth - clusterWidth) / 2 +
                      rodWidth +
                      rodGap,
                  value: major(points[i].savedMinor ?? 0),
                  color: (points[i].savedMinor ?? 0) < 0
                      ? colors.critical
                      : colors.good,
                ),
              if (labelEveryGroup) ...[
                valueLabel(
                  index: i,
                  centreX:
                      plotLeft +
                      i * groupWidth +
                      (groupWidth - clusterWidth) / 2 +
                      rodWidth / 2,
                  value: major(points[i].spentMinor),
                  minor: points[i].spentMinor,
                ),
                if (showsSaved)
                  valueLabel(
                    index: i,
                    centreX:
                        plotLeft +
                        i * groupWidth +
                        (groupWidth - clusterWidth) / 2 +
                        rodWidth * 1.5 +
                        rodGap,
                    value: major(points[i].savedMinor ?? 0),
                    minor: points[i].savedMinor ?? 0,
                  ),
              ],
              // The group's name, under the baseline.
              Positioned(
                left: plotLeft + i * groupWidth,
                width: groupWidth,
                bottom: 0,
                height: _labelRow,
                child: Opacity(
                  opacity: fade,
                  child: Center(
                    child: Text(
                      _shortLabel(points[i], period),
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontFamily: AppFonts.numeric,
                        fontFeatures: AppFonts.tabular,
                        fontSize: 10.5,
                        fontWeight: interactive && i == selected
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: interactive && i == selected
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              // The whole column is tappable, not just the thin bars.
              if (interactive)
                Positioned(
                  left: plotLeft + i * groupWidth,
                  width: groupWidth,
                  top: 0,
                  bottom: 0,
                  child: Semantics(
                    button: true,
                    selected: i == selected,
                    label:
                        '${_fullLabel(points[i], period)}, '
                        'spent ${formatMinor(points[i].spentMinor, currencyCode: currencyCode, showDecimals: false)}'
                        '${points[i].savedMinor == null ? '' : ', saved ${formatMinor(points[i].savedMinor!, currencyCode: currencyCode, showDecimals: false)}'}',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelect(i),
                    ),
                  ),
                ),
            ],
            if (interactive && showCallout)
              () {
                const calloutWidth = 156.0;
                // Beside the tapped group, not over it, so the bar you pressed
                // stays in view: to its right in the left half of the chart, to
                // its left in the right half. Level with the top of the plot.
                final groupLeft = plotLeft + selected * groupWidth;
                final inLeftHalf = selected < points.length / 2;
                final left =
                    (inLeftHalf
                            ? groupLeft + groupWidth + 4
                            : groupLeft - calloutWidth - 4)
                        .clamp(0.0, width - calloutWidth);
                return Positioned(
                  left: left,
                  top: 0,
                  width: calloutWidth,
                  child: IgnorePointer(
                    child: _Callout(
                      point: points[selected],
                      period: period,
                      currencyCode: currencyCode,
                    ),
                  ),
                );
              }(),
          ],
        );
      },
    );
  }
}

/// The bubble shown when a bar is tapped: which period, and the exact spent and
/// saved (or overspent) figures, large enough to read at a glance.
class _Callout extends StatelessWidget {
  const _Callout({
    required this.point,
    required this.period,
    required this.currencyCode,
  });

  final ComparisonPoint point;
  final ComparisonPeriod period;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    String money(int minor) => formatMinor(
      minor.abs(),
      currencyCode: currencyCode,
      showDecimals: false,
    );

    Widget line(Color dot, String label, String amount, {Color? amountColor}) =>
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                amount,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: AppFonts.numeric,
                  fontFeatures: AppFonts.tabular,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: amountColor ?? scheme.onSurface,
                ),
              ),
            ],
          ),
        );

    final saved = point.savedMinor;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _fullLabel(point, period),
              maxLines: 1,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            line(colors.spend, 'Spent', money(point.spentMinor)),
            if (saved != null)
              line(
                saved < 0 ? colors.critical : colors.good,
                saved < 0 ? 'Overspent' : 'Saved',
                money(saved),
                amountColor: saved < 0 ? colors.critical : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({
    required this.ticks,
    required this.zeroY,
    required this.left,
    required this.color,
  });

  final List<double> ticks;
  final double zeroY;
  final double left;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (final y in ticks) {
      if ((y - zeroY).abs() < 0.5) {
        canvas.drawLine(Offset(left, y), Offset(size.width, y), paint);
        continue;
      }
      // Dashed: 5 on, 4 off.
      for (var x = left; x < size.width; x += 9) {
        canvas.drawLine(
          Offset(x, y),
          Offset((x + 5).clamp(left, size.width), y),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.ticks != ticks || old.zeroY != zeroY || old.color != color;
}
