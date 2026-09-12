import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';
import 'habit_schedule.dart';

class HabitMonthStats {
  HabitMonthStats(this.month);
  final DateTime month;
  int scheduled = 0;
  int completed = 0;
  double get rate => scheduled == 0 ? 0 : completed / scheduled;
}

class HabitStatistics {
  const HabitStatistics(this.current, this.longest, this.average, this.months);
  final int current;
  final int longest;
  final double average;
  final List<HabitMonthStats> months;

  factory HabitStatistics.calculate(
    Habit habit,
    List<HabitLog> logs,
    DateTime now,
  ) {
    final today = dateOnly(now);
    final done = logs
        .where((log) => log.habitId == habit.id && log.completed)
        .map((log) => dateOnly(log.date))
        .toSet();
    final months = [
      for (var i = 5; i >= 0; i--)
        HabitMonthStats(DateTime(today.year, today.month - i)),
    ];
    final runs = <int>[];
    var current = 0;
    for (
      var day = dateOnly(habit.repeatSchedule.trackingStart);
      !day.isAfter(today);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      if (!habit.scheduledOn(day)) continue;
      final month = months
          .where((m) => m.month.year == day.year && m.month.month == day.month)
          .firstOrNull;
      if (month != null) {
        month.scheduled++;
        if (done.contains(day)) month.completed++;
      }
      if (done.contains(day)) {
        current++;
      } else if (day != today) {
        if (current > 0) runs.add(current);
        current = 0;
      }
    }
    if (current > 0) runs.add(current);
    return HabitStatistics(
      current,
      runs.fold(0, (a, b) => a > b ? a : b),
      runs.isEmpty ? 0 : runs.reduce((a, b) => a + b) / runs.length,
      months,
    );
  }
}
