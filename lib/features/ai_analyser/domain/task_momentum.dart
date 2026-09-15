import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';

/// Compare the same local weekday/time in each week, not a partial week
/// against seven whole days. Calendar construction preserves local time at DST.
({int thisWeek, int lastWeek}) taskMomentumCounts(
  List<Task> tasks,
  DateTime now,
) {
  final start = startOfWeek(now);
  final previousStart = DateTime(start.year, start.month, start.day - 7);
  final previousEnd = DateTime(
    now.year,
    now.month,
    now.day - 7,
    now.hour,
    now.minute,
    now.second,
    now.millisecond,
    now.microsecond,
  );
  int count(DateTime from, DateTime until) => tasks.where((task) {
    final completed = task.completedAt;
    return task.status == 'done' &&
        completed != null &&
        !completed.isBefore(from) &&
        completed.isBefore(until);
  }).length;
  return (
    thisWeek: count(start, now),
    lastWeek: count(previousStart, previousEnd),
  );
}
