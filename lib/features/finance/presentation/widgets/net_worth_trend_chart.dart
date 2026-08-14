import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/net_worth_point.dart';

class NetWorthTrendChart extends StatelessWidget {
  const NetWorthTrendChart({
    super.key,
    required this.points,
    required this.assetColor,
    required this.liabilityColor,
  });

  final List<NetWorthPoint> points;
  final Color assetColor;
  final Color liabilityColor;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return const SizedBox(height: 160, child: Center(child: Text('Not enough data yet')));
    }

    final assetSpots = [
      for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].assetsMinor / 100),
    ];
    final liabilitySpots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].liabilitiesMinor / 100),
    ];
    final maxY = [
      ...points.map((p) => p.assetsMinor),
      ...points.map((p) => p.liabilitiesMinor),
    ].reduce((a, b) => a > b ? a : b) / 100;
    final ceiling = maxY <= 0 ? 100.0 : maxY * 1.2;

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: ceiling,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: ceiling / 3,
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
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) return const SizedBox.shrink();
                  final isLast = index == points.length - 1;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      isLast ? 'Now' : DateFormat.MMM().format(points[index].date),
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
            _line(assetSpots, assetColor),
            _line(liabilitySpots, liabilityColor),
          ],
        ),
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: false,
      color: color,
      barWidth: 2.5,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) {
          final isLast = index == spots.length - 1;
          return FlDotCirclePainter(radius: isLast ? 4.5 : 2.5, color: color);
        },
      ),
    );
  }
}
