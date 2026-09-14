import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';
import '../../habits/domain/habit_schedule.dart';

/// Units are determined by goal type; never sum money and completion counts.
/// Account balances use major currency units, matching financial goal targets.
double automaticGoalProgress({
  required Goal goal,
  required List<GoalLink> links,
  required List<Account> accounts,
  required List<Task> tasks,
  required List<Habit> habits,
  required List<HabitLog> logs,
  required String currencyCode,
  required DateTime now,
}) {
  Set<String> ids(String type) => links
      .where((l) => l.goalId == goal.id && l.linkedType == type)
      .map((l) => l.linkedId)
      .toSet();
  if (goal.type == 'financial') {
    final linked = ids('account');
    return accounts
            .where(
              (a) => linked.contains(a.id) && a.currencyCode == currencyCode,
            )
            .fold<int>(0, (sum, a) => sum + a.balanceMinor) /
        100;
  }
  if (goal.type == 'habit') {
    final linked = ids('habit');
    final byId = {for (final h in habits) h.id: h};
    final start = dateOnly(goal.createdAt);
    final end = dateOnly(now);
    return logs
        .where(
          (log) =>
              linked.contains(log.habitId) &&
              log.completed &&
              !dateOnly(log.date).isBefore(start) &&
              !dateOnly(log.date).isAfter(end) &&
              (byId[log.habitId]?.scheduledOn(log.date) ?? false),
        )
        .map((l) => '${l.habitId}:${dateOnly(l.date)}')
        .toSet()
        .length
        .toDouble();
  }
  final linked = ids('task');
  return tasks
      .where((t) => linked.contains(t.id) && t.status == 'done')
      .length
      .toDouble();
}
