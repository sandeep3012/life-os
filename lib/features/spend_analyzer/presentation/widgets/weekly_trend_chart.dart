import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class WeeklyTrendChart extends StatelessWidget {
  const WeeklyTrendChart({super.key, required this.weeklyTotalsMinor, required this.color});

  final List<int> weeklyTotalsMinor;
  final Color color;

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
      height: 108,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY <= 0 ? 100 : maxY * 1.15,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY <= 0 ? 100 : maxY * 1.15) / 3,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= weeklyTotalsMinor.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'W${index + 1}',
                      style: TextStyle(
                        fontFamily: 'PlexMono',
                        fontSize: 9,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
