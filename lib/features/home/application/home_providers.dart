import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_utils.dart';
import '../../calendar/application/calendar_providers.dart';
import '../../calendar/domain/calendar_item.dart';
import '../../finance/application/finance_providers.dart';
import '../../goals/application/goals_providers.dart';
import '../../habits/application/habits_providers.dart';
import '../../habits/domain/habit_progress.dart';
import '../../tasks/application/tasks_providers.dart';

/// Total expense (positive figure) logged since Monday this week.
final weekSpendMinorProvider = Provider<int>((ref) {
  final transactions = ref.watch(transactionsProvider).value ?? const [];
  final weekStart = startOfWeek(DateTime.now());
  return transactions
      .where((t) => t.amountMinor < 0 && !t.date.isBefore(weekStart))
      .fold<int>(0, (sum, t) => sum + t.amountMinor.abs());
});

/// Same window a week earlier, so the dashboard can show a week-over-week
/// delta rather than a bare number with no reference point.
final lastWeekSpendMinorProvider = Provider<int>((ref) {
  final transactions = ref.watch(transactionsProvider).value ?? const [];
  final thisWeekStart = startOfWeek(DateTime.now());
  final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
  return transactions
      .where(
        (t) =>
            t.amountMinor < 0 &&
            !t.date.isBefore(lastWeekStart) &&
            t.date.isBefore(thisWeekStart),
      )
      .fold<int>(0, (sum, t) => sum + t.amountMinor.abs());
});

class TodayTasks {
  const TodayTasks({required this.tasks, required this.doneCount});

  final List<Task> tasks;
  final int doneCount;

  int get total => tasks.length;
  int get remaining => total - doneCount;
}

/// Tasks due today plus undated open tasks — the same set the Tasks screen's
/// "Today" filter shows, so the two views can't disagree.
final todayTasksProvider = Provider<TodayTasks>((ref) {
  final all = ref.watch(allTasksProvider).value ?? const [];
  final now = DateTime.now();
  final tasks =
      all
          .where((t) => t.dueDate == null || isSameDay(t.dueDate!, now))
          .where((t) => t.dueDate != null || t.status == 'open')
          .toList()
        ..sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
  return TodayTasks(
    tasks: tasks,
    doneCount: tasks.where((t) => t.status == 'done').length,
  );
});

/// Habits with a live streak, worst-first so anything at risk of breaking
/// surfaces before the healthy ones.
final habitCheckInProvider = Provider<List<HabitProgress>>((ref) {
  final progress = [...ref.watch(habitsWithProgressProvider)]
    ..sort((a, b) {
      if (a.isAtRisk != b.isAtRisk) return a.isAtRisk ? -1 : 1;
      return b.streakDays.compareTo(a.streakDays);
    });
  return progress;
});

final averageStreakDaysProvider = Provider<int>((ref) {
  final progress = ref.watch(habitsWithProgressProvider);
  if (progress.isEmpty) return 0;
  final total = progress.fold<int>(0, (sum, p) => sum + p.streakDays);
  return (total / progress.length).round();
});

final activeGoalCountProvider = Provider<int>((ref) {
  final goals = ref.watch(goalsListProvider).value ?? const [];
  return goals.where((g) => g.status == 'active').length;
});

/// The next few calendar items over the coming week. Starts from *tomorrow*:
/// today's items already have their own dashboard section, and showing them
/// twice on one screen reads as duplication rather than emphasis.
final upcomingItemsProvider = Provider<List<CalendarItem>>((ref) {
  final tomorrow = dateOnly(DateTime.now()).add(const Duration(days: 1));
  final weekEnd = tomorrow.add(const Duration(days: 7));
  final items =
      ref
          .watch(allCalendarItemsProvider)
          .where((i) => !i.date.isBefore(tomorrow) && i.date.isBefore(weekEnd))
          .where((i) => i.type != CalendarItemType.habit)
          .toList()
        ..sort((a, b) {
          final dateCompare = a.date.compareTo(b.date);
          if (dateCompare != 0) return dateCompare;
          if (a.time == null && b.time == null) return 0;
          if (a.time == null) return 1;
          if (b.time == null) return -1;
          return a.time!.compareTo(b.time!);
        });
  return items.take(4).toList();
});
