import '../../../core/utils/currency_utils.dart';
import '../../habits/domain/habit_progress.dart';
import '../../home/application/home_providers.dart';

/// What the Android "Today" home-screen widget shows, worked out in Dart so
/// the native widget only has to lay it out.
///
/// The widget sits on the home screen, outside the app's own protections, so
/// it follows them: with app lock on it shows counts only — no task names,
/// no amount — and with balances hidden the amount is masked.
class TodayWidgetSnapshot {
  const TodayWidgetSnapshot({
    required this.day,
    required this.locked,
    required this.spend,
    required this.tasksLeft,
    required this.tasksTotal,
    required this.taskTitles,
    required this.habitsDone,
    required this.habitsTotal,
  });

  /// The local date this was built for, `yyyy-MM-dd`. The widget compares it
  /// with today and asks to be opened once it's stale, rather than showing
  /// yesterday's list as today's.
  final String day;
  final bool locked;

  /// This month's spend, formatted — masked when balances are hidden, empty
  /// when locked.
  final String spend;
  final int tasksLeft;
  final int tasksTotal;

  /// Up to three of today's open tasks, soonest first; empty when locked.
  final List<String> taskTitles;
  final int habitsDone;
  final int habitsTotal;

  static const maxTasks = 3;

  factory TodayWidgetSnapshot.build({
    required DateTime now,
    required TodayTasks tasks,
    required List<HabitProgress> habits,
    required int monthSpendMinor,
    required String currencyCode,
    required bool balancesVisible,
    required bool appLocked,
  }) {
    final scheduled = habits.where((h) => h.isScheduledToday).toList();
    final open = tasks.tasks.where((t) => t.status != 'done');
    return TodayWidgetSnapshot(
      day: dayKey(now),
      locked: appLocked,
      spend: appLocked
          ? ''
          : formatMinorMasked(
              monthSpendMinor,
              currencyCode: currencyCode,
              visible: balancesVisible,
              showDecimals: false,
            ),
      tasksLeft: tasks.remaining,
      tasksTotal: tasks.total,
      taskTitles: appLocked
          ? const []
          : open.take(maxTasks).map((t) => t.title).toList(),
      habitsDone: scheduled
          .where((h) => h.weekCompletion[now.weekday] ?? false)
          .length,
      habitsTotal: scheduled.length,
    );
  }

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// The values handed to the native widget, by key. Plain strings and ints
  /// only: they go through the platform's shared preferences.
  Map<String, Object> toWidgetData() => {
    'today_day': day,
    'today_locked': locked ? 1 : 0,
    'today_spend': spend,
    'today_tasks_left': tasksLeft,
    'today_tasks_total': tasksTotal,
    'today_task_1': taskTitles.isNotEmpty ? taskTitles[0] : '',
    'today_task_2': taskTitles.length > 1 ? taskTitles[1] : '',
    'today_task_3': taskTitles.length > 2 ? taskTitles[2] : '',
    'today_habits_done': habitsDone,
    'today_habits_total': habitsTotal,
  };
}
