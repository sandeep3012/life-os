import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/reminders/reminder_mode.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/date_utils.dart';
import '../../settings/application/settings_providers.dart';
import '../data/habits_repository.dart';
import '../domain/habit_progress.dart';

final habitsRepositoryProvider = Provider<HabitsRepository>((ref) {
  return HabitsRepository(ref.watch(appDatabaseProvider));
});

final habitsListProvider = StreamProvider<List<Habit>>((ref) {
  return ref.watch(habitsRepositoryProvider).watchHabits();
});

final habitLogsProvider = StreamProvider<List<HabitLog>>((ref) {
  return ref.watch(habitsRepositoryProvider).watchRecentLogs();
});

/// Combines the two streams above into the per-habit streak + weekly dot
/// grid the Habits list renders. A plain [Provider] (not a StreamProvider)
/// because it only ever derives from values already held by the two
/// upstream StreamProviders — `ref.watch`ing them is enough to stay reactive.
final habitsWithProgressProvider = Provider<List<HabitProgress>>((ref) {
  final habits = ref.watch(habitsListProvider).value ?? const [];
  final logs = ref.watch(habitLogsProvider).value ?? const [];

  final logsByHabit = <String, List<HabitLog>>{};
  for (final log in logs) {
    logsByHabit.putIfAbsent(log.habitId, () => []).add(log);
  }

  return [
    for (final habit in habits)
      HabitProgress(
        habit: habit,
        streakDays: _computeStreak(logsByHabit[habit.id] ?? const []),
        weekCompletion: _computeWeekCompletion(logsByHabit[habit.id] ?? const []),
      ),
  ];
});

int _computeStreak(List<HabitLog> logs) {
  final completedDates = logs
      .where((l) => l.completed)
      .map((l) => dateOnly(l.date))
      .toSet();

  var cursor = dateOnly(DateTime.now());
  // If today isn't logged yet, the streak is still "alive" through
  // yesterday — don't zero it out just because today hasn't happened yet.
  if (!completedDates.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
  }

  var streak = 0;
  while (completedDates.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

Map<int, bool> _computeWeekCompletion(List<HabitLog> logs) {
  final completedDates = logs
      .where((l) => l.completed)
      .map((l) => dateOnly(l.date))
      .toSet();
  final monday = startOfWeek(DateTime.now());
  return {
    for (var i = 0; i < 7; i++)
      monday.add(Duration(days: i)).weekday:
          completedDates.contains(monday.add(Duration(days: i))),
  };
}

class HabitsController {
  HabitsController(this._repo, this._notifications, this._remindersEnabled);

  final HabitsRepository _repo;
  final NotificationService _notifications;

  /// Read at call time, same as `TasksController` — the app-wide "Habit
  /// reminders" setting acts as a master switch over every per-habit one.
  final bool Function() _remindersEnabled;

  Future<void> addHabit(
    String name, {
    bool reminderEnabled = false,
    int? reminderHour,
    int? reminderMinute,
    ReminderMode reminderMode = ReminderMode.notification,
  }) async {
    final id = await _repo.createHabit(
      name,
      reminderEnabled: reminderEnabled,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
      reminderMode: reminderMode.storageValue,
    );
    if (reminderEnabled && reminderHour != null && reminderMinute != null && _remindersEnabled()) {
      await _notifications.scheduleHabitReminder(
        habitId: id,
        title: name,
        hour: reminderHour,
        minute: reminderMinute,
        mode: reminderMode,
      );
    }
  }

  Future<void> toggleToday(Habit habit, bool completed) {
    return _repo.setCompletedForDate(habit.id, DateTime.now(), completed);
  }
}

final habitsControllerProvider = Provider<HabitsController>((ref) {
  return HabitsController(
    ref.watch(habitsRepositoryProvider),
    ref.watch(notificationServiceProvider),
    () => ref.read(settingsProvider).habitReminders,
  );
});
