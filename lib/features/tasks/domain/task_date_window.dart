import 'dart:collection';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';

enum TaskPeriod { day, week, month }

/// Local calendar dates with an exclusive end; never add 24-hour durations
/// when calculating calendar boundaries across daylight-saving changes.
typedef TaskDateWindow = ({DateTime start, DateTime end});

TaskDateWindow taskDateWindow(DateTime selected, TaskPeriod period) {
  final day = dateOnly(selected);
  return switch (period) {
    TaskPeriod.day => (
      start: day,
      end: DateTime(day.year, day.month, day.day + 1),
    ),
    TaskPeriod.week => (
      start: day,
      end: DateTime(day.year, day.month, day.day + 7),
    ),
    TaskPeriod.month => (
      start: DateTime(day.year, day.month),
      end: DateTime(day.year, day.month + 1),
    ),
  };
}

TaskDateWindow taskStripWindow(DateTime selected, TaskPeriod period) {
  final start = period == TaskPeriod.week
      ? dateOnly(selected)
      : DateTime(
          selected.year,
          selected.month,
          selected.day - selected.weekday + 1,
        );
  return (start: start, end: DateTime(start.year, start.month, start.day + 7));
}

Map<DateTime, List<Task>> groupTasksByDueDate(List<Task> tasks) {
  final groups = SplayTreeMap<DateTime, List<Task>>();
  for (final task in tasks) {
    if (task.dueDate == null) continue;
    groups.putIfAbsent(dateOnly(task.dueDate!), () => []).add(task);
  }
  for (final group in groups.values) {
    group.sort((a, b) {
      final time = a.dueDate!.compareTo(b.dueDate!);
      if (time != 0) return time;
      final title = a.title.compareTo(b.title);
      return title != 0 ? title : a.id.compareTo(b.id);
    });
  }
  return groups;
}
