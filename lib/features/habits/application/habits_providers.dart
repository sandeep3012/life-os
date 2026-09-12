import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/reminders/reminder_mode.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/date_utils.dart';
import '../../settings/application/settings_providers.dart';
import '../../../core/scheduling/repeat_schedule.dart';
import '../data/habits_repository.dart';
import '../domain/habit_progress.dart';
import '../domain/habit_schedule.dart';

final habitsRepositoryProvider = Provider<HabitsRepository>((ref) {
  return HabitsRepository(ref.watch(appDatabaseProvider));
});

final habitsListProvider = StreamProvider<List<Habit>>((ref) {
  return ref.watch(habitsRepositoryProvider).watchHabits();
});

final archivedHabitsProvider = StreamProvider<List<Habit>>((ref) {
  return ref.watch(habitsRepositoryProvider).watchArchivedHabits();
});

final habitLogsProvider = StreamProvider<List<HabitLog>>((ref) {
  return ref.watch(habitsRepositoryProvider).watchRecentLogs();
});

final habitCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(habitsRepositoryProvider).watchHabitCategories();
});

/// All logs for one habit, newest first — feeds the detail screen's history
/// list. A family provider so each habit's history is watched independently.
final habitLogHistoryProvider = StreamProvider.family<List<HabitLog>, String>((ref, habitId) {
  return ref.watch(habitsRepositoryProvider).watchLogsForHabit(habitId);
});

/// A single habit by id, derived from [habitsListProvider]/[archivedHabitsProvider]'s
/// already-loaded values rather than a separate DB read — searches both so an
/// archived habit's detail screen still resolves (rather than reading as
/// "not found") and can offer a restore action. Null only while loading or
/// genuinely missing.
final habitByIdProvider = Provider.family<Habit?, String>((ref, habitId) {
  final active = ref.watch(habitsListProvider).value ?? const [];
  final archived = ref.watch(archivedHabitsProvider).value ?? const [];
  for (final h in [...active, ...archived]) {
    if (h.id == habitId) return h;
  }
  return null;
});

/// Combines the two streams above into the per-habit streak + weekly dot
/// grid the Habits list renders. A plain [Provider] (not a StreamProvider)
/// because it only ever derives from values already held by the two
/// upstream StreamProviders — `ref.watch`ing them is enough to stay reactive.
final habitsWithProgressProvider = Provider<List<HabitProgress>>((ref) {
  final habits = ref.watch(habitsListProvider).value ?? const [];
  final logs = ref.watch(habitLogsProvider).value ?? const [];
  final categories = ref.watch(habitCategoriesProvider).value ?? const [];
  final categoriesById = {for (final c in categories) c.id: c};

  final logsByHabit = <String, List<HabitLog>>{};
  for (final log in logs) {
    logsByHabit.putIfAbsent(log.habitId, () => []).add(log);
  }

  return [
    for (final habit in habits)
      HabitProgress(
        habit: habit,
        streakDays: _computeStreak(habit, logsByHabit[habit.id] ?? const []),
        weekCompletion: _computeWeekCompletion(habit, logsByHabit[habit.id] ?? const []),
        category: habit.categoryId == null ? null : categoriesById[habit.categoryId],
      ),
  ];
});

int _computeStreak(Habit habit, List<HabitLog> logs) {
  final done = logs.where((l) => l.completed).map((l) => dateOnly(l.date)).toSet();
  final today = dateOnly(DateTime.now());
  var cursor = today;
  var streak = 0;
  final start = dateOnly(habit.repeatSchedule.trackingStart);
  while (!cursor.isBefore(start)) {
    if (habit.scheduledOn(cursor)) {
      if (done.contains(cursor)) { streak++; }
      else if (cursor != today) { break; }
    }
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return streak;
}

Map<int, bool> _computeWeekCompletion(Habit habit, List<HabitLog> logs) {
  final completedDates = logs
      .where((l) => l.completed)
      .map((l) => dateOnly(l.date))
      .toSet();
  final monday = startOfWeek(DateTime.now());
  return {
    for (var i = 0; i < 7; i++)
      if (habit.scheduledOn(DateTime(monday.year, monday.month, monday.day + i)))
      monday.add(Duration(days: i)).weekday:
          completedDates.contains(monday.add(Duration(days: i))),
  };
}

class HabitsController {
  HabitsController(this._repo, this._notifications, bool Function() remindersEnabled);

  final HabitsRepository _repo;
  final NotificationService _notifications;

  Future<void> addHabit(
    String name, {
    String? categoryId,
    String? description,
    RepeatSchedule? schedule,
    bool reminderEnabled = false,
    int? reminderHour,
    int? reminderMinute,
    ReminderMode reminderMode = ReminderMode.notification,
  }) async {
    await _repo.createHabit(
      name,
      categoryId: categoryId,
      description: description,
      schedule: schedule,
      reminderEnabled: reminderEnabled,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
      reminderMode: reminderMode.storageValue,
    );
  }

  Future<void> updateHabit({
    required Habit habit,
    required String name,
    String? categoryId,
    String? description,
    RepeatSchedule? schedule,
    bool reminderEnabled = false,
    int? reminderHour,
    int? reminderMinute,
    ReminderMode reminderMode = ReminderMode.notification,
  }) async {
    await _notifications.cancelHabitReminder(habit.id);
    await _repo.updateHabit(
      id: habit.id,
      name: name,
      categoryId: categoryId,
      description: description,
      schedule: schedule,
      reminderEnabled: reminderEnabled,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
      reminderMode: reminderMode.storageValue,
    );
  }

  Future<Category> createHabitCategory({
    required String name,
    required String icon,
    required String colorHex,
  }) {
    return _repo.createHabitCategory(name: name, icon: icon, colorHex: colorHex);
  }

  Future<void> archiveHabit(Habit habit) async {
    await _notifications.cancelHabitReminder(habit.id);
    await _repo.archiveHabit(habit.id);
  }

  /// Restoring the row triggers reminder reconciliation in ScheduleCoordinator.
  Future<void> unarchiveHabit(Habit habit) async {
    await _repo.unarchiveHabit(habit.id);
  }

  Future<void> toggleToday(Habit habit, bool completed) {
    return _repo.setCompletedForDate(habit.id, DateTime.now(), completed);
  }

  /// Passthrough for the detail screen's history list, kept distinct from
  /// [toggleToday] (which stays "today"-only for the list screen's tap).
  Future<void> setCompletedForDate(
    Habit habit,
    DateTime date,
    bool completed, {
    String? notes,
  }) {
    return _repo.setCompletedForDate(habit.id, date, completed, notes: notes);
  }

}

final habitsControllerProvider = Provider<HabitsController>((ref) {
  return HabitsController(
    ref.watch(habitsRepositoryProvider),
    ref.watch(notificationServiceProvider),
    () => ref.read(settingsProvider).habitReminders,
  );
});
