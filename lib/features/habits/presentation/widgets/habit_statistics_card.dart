import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../domain/habit_statistics.dart';

class HabitStatisticsCard extends StatelessWidget {
  const HabitStatisticsCard({
    super.key,
    required this.stats,
    required this.accent,
  });
  final HabitStatistics stats;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Streak insights', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            _chart(
              context,
              values: [
                stats.longest.toDouble(),
                stats.current.toDouble(),
                stats.average,
              ],
              labels: const ['Longest', 'Current', 'Average'],
              maximum: stats.longest == 0 ? 1 : stats.longest.toDouble(),
              tooltip: (index) =>
                  '${['Longest', 'Current', 'Average'][index]}: ${[stats.longest.toDouble(), stats.current.toDouble(), stats.average][index].toStringAsFixed(index == 2 ? 1 : 0)}',
            ),
            const SizedBox(height: 16),
            for (final item in <(String, double)>[
              ('Longest streak', stats.longest.toDouble()),
              ('Current streak', stats.current.toDouble()),
              ('Average streak', stats.average),
            ]) ...[
              Text(
                '${item.$1}: ${item.$1 == 'Average streak' ? item.$2.toStringAsFixed(1) : item.$2.toInt()} scheduled completions',
              ),
              const SizedBox(height: 6),
            ],
            Text(
              'Unscheduled days do not break streaks. Average includes the ongoing streak.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            Text('Monthly completion', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Last six months; current month through today.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _chart(
              context,
              values: [for (final month in stats.months) month.rate * 100],
              labels: [
                for (final month in stats.months)
                  DateFormat('MMM').format(month.month),
              ],
              maximum: 100,
              percent: true,
              tooltip: (index) {
                final month = stats.months[index];
                return month.scheduled == 0
                    ? 'Not scheduled'
                    : '${month.completed}/${month.scheduled} completed';
              },
            ),
            const SizedBox(height: 16),
            for (final month in stats.months) ...[
              Text(
                '${DateFormat('MMM yyyy').format(month.month)} · ${month.scheduled == 0 ? 'Not scheduled' : '${month.completed}/${month.scheduled} completed (${(month.rate * 100).round()}%)'}',
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chart(
    BuildContext context, {
    required List<double> values,
    required List<String> labels,
    required double maximum,
    required String Function(int) tooltip,
    bool percent = false,
  }) {
    final theme = Theme.of(context);
    final interval = percent ? 25.0 : (maximum / 4).ceilToDouble();
    final axisMaximum = (maximum / interval).ceil() * interval;
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: axisMaximum,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: interval,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    '${value.toInt()}${percent ? '%' : ''}',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      labels[index],
                      style: theme.textTheme.labelSmall,
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                  BarTooltipItem(
                    tooltip(group.x),
                    const TextStyle(color: Colors.white),
                  ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i],
                    width: percent ? 22 : 36,
                    color: accent,
                    // Rounded corners impose a minimum pixel height in fl_chart.
                    // Square ends keep even small values proportional to the axis.
                    borderRadius: BorderRadius.zero,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
