import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../core/utils/currency_utils.dart';
import 'chart_style.dart';

class WeeklyTrendChart extends StatelessWidget {
  const WeeklyTrendChart({
    super.key,
    required this.weeklyTotalsMinor,
    required this.color,
    required this.currencyCode,
    this.height = 122,
  });

  final List<int> weeklyTotalsMinor;
  final Color color;

  /// For the amount under each week's label.
  final String currencyCode;

  /// The chart's height, or null to fill whatever room its parent gives it.
  final double? height;

  @override
  Widget build(BuildContext context) {
    if (weeklyTotalsMinor.length < 2) {
      return const SizedBox(
        height: 108,
        child: Center(child: Text('Not enough data yet')),
      );
    }

    final spots = [
      for (var i = 0; i < weeklyTotalsMinor.length; i++)
        FlSpot(i.toDouble(), weeklyTotalsMinor[i] / 100),
    ];
    final maxY = weeklyTotalsMinor.reduce((a, b) => a > b ? a : b) / 100;

    return SizedBox(
      // 108 for the plot, plus the 14 the second label row (the amount) takes.
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY <= 0 ? 100 : maxY * 1.15,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY <= 0 ? 100 : maxY * 1.15) / 3,
            // Dashed and light: the lines are a guide to the eye, and solid
            // grey ones competed with the data line.
            getDrawingHorizontalLine: (value) => FlLine(
              color: chartGridColor(Theme.of(context).colorScheme),
              strokeWidth: 1,
              dashArray: const [5, 4],
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                // Two lines: the week, and what was spent in it.
                reservedSize: 34,
                // One label per week. Left to itself the axis steps by 0.5 over
                // a range this small, and truncating 0.5 to 0 and 1.5 to 1 drew
                // every week's label twice (W1 W1 W2 W2 ...).
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (value != index.toDouble() ||
                      index < 0 ||
                      index >= weeklyTotalsMinor.length) {
                    return const SizedBox.shrink();
                  }
                  final scheme = Theme.of(context).colorScheme;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'W${index + 1}',
                          style: TextStyle(
                            fontFamily: AppFonts.numeric,
                            fontFeatures: AppFonts.tabular,
                            fontSize: 9,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          formatCompactMinor(
                            weeklyTotalsMinor[index],
                            currencyCode: currencyCode,
                          ),
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: AppFonts.numeric,
                            fontFeatures: AppFonts.tabular,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: color,
              barWidth: 2.5,
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
                ),
              ),
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) {
                  final isLast = index == spots.length - 1;
                  return FlDotCirclePainter(
                    radius: isLast ? 4.5 : 3,
                    color: isLast ? Theme.of(context).colorScheme.surface : color,
                    strokeWidth: 2.5,
                    strokeColor: color,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
