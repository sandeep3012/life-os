import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/habits/domain/habit_statistics.dart';
import 'package:life_manager/features/habits/presentation/widgets/habit_statistics_card.dart';

void main() {
  testWidgets('bars retain exact values on aligned zero-based scales', (
    tester,
  ) async {
    final month = HabitMonthStats(DateTime(2026, 9))
      ..scheduled = 30
      ..completed = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HabitStatisticsCard(
              stats: HabitStatistics(1, 7, 2.5, [month]),
              accent: Colors.purple,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final charts = tester.widgetList<BarChart>(find.byType(BarChart)).toList();
    final streak = charts[0].data;
    expect(streak.minY, 0);
    expect(streak.maxY, 8);
    expect(streak.barGroups.map((g) => g.barRods.single.toY), [7, 1, 2.5]);
    final monthly = charts[1].data;
    expect(monthly.minY, 0);
    expect(monthly.maxY, 100);
    expect(
      monthly.barGroups.single.barRods.single.toY,
      closeTo(100 / 30, 0.0001),
    );
    for (final chart in charts) {
      expect(
        chart.data.gridData.horizontalInterval,
        chart.data.titlesData.leftTitles.sideTitles.interval,
      );
      for (final group in chart.data.barGroups) {
        expect(group.barRods.single.borderRadius, BorderRadius.zero);
        expect(group.barRods.single.backDrawRodData.show, isFalse);
      }
    }
    expect(tester.takeException(), isNull);
  });
}
