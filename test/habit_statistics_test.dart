import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/scheduling/repeat_schedule.dart';
import 'package:life_manager/features/habits/domain/habit_statistics.dart';

void main() {
  Habit habit(RepeatSchedule schedule) => Habit(id: 'h', name: 'Read',
    frequency: 'daily', targetPerWeek: 7, archived: false,
    reminderEnabled: false, reminderMode: 'notification',
    createdAt: schedule.start, schedule: schedule.encode());
  List<HabitLog> logs(List<int> days) => [for (final day in days)
    HabitLog(id: '$day', habitId: 'h', date: DateTime(2026, 9, day), completed: true)];

  test('counts streak runs and keeps pending today intact', () {
    final h = habit(RepeatSchedule(start: DateTime(2026, 9, 1), frequency: 'daily'));
    final stats = HabitStatistics.calculate(h, logs([1, 2, 4, 5]), DateTime(2026, 9, 6));
    expect(stats.current, 2);
    expect(stats.longest, 2);
    expect(stats.average, 2);
    expect(stats.months.last.completed, 4);
    expect(stats.months.last.scheduled, 6);
    expect(HabitStatistics.calculate(h, logs([1, 2, 4, 5]), DateTime(2026, 9, 7)).current, 0);
  });
  test('unscheduled days and dates after end do not break streaks', () {
    final h = habit(RepeatSchedule(start: DateTime(2026, 9, 1),
      frequency: 'weekly', weekdays: [2, 4], end: DateTime(2026, 9, 3)));
    final stats = HabitStatistics.calculate(h, logs([1, 3, 8]), DateTime(2026, 9, 12));
    expect(stats.current, 2);
    expect(stats.longest, 2);
    expect(stats.months.last.scheduled, 2);
    expect(stats.months.last.completed, 2);
  });
  test('future habits have zero statistics', () {
    final h = habit(RepeatSchedule(start: DateTime(2026, 10, 1), frequency: 'daily'));
    final stats = HabitStatistics.calculate(h, [], DateTime(2026, 9, 12));
    expect(stats.current, 0);
    expect(stats.average, 0);
    expect(stats.months.every((m) => m.scheduled == 0), isTrue);
  });
}
