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
        streakDays: _computeStreak(logsByHabit[habit.id] ?? const []),
        weekCompletion: _computeWeekCompletion(logsByHabit[habit.id] ?? const []),
        category: habit.categoryId == null ? null : categoriesById[habit.categoryId],
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
    String? categoryId,
    bool reminderEnabled = false,
    int? reminderHour,
    int? reminderMinute,
    ReminderMode reminderMode = ReminderMode.notification,
  }) async {
    final id = await _repo.createHabit(
      name,
      categoryId: categoryId,
      reminderEnabled: reminderEnabled,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
      reminderMode: reminderMode.storageValue,
    );
    await _scheduleReminder(
      habitId: id,
      title: name,
      reminderEnabled: reminderEnabled,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
      reminderMode: reminderMode,
    );
  }

  Future<void> updateHabit({
    required Habit habit,
    required String name,
    String? categoryId,
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
      reminderEnabled: reminderEnabled,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
      reminderMode: reminderMode.storageValue,
    );
    await _scheduleReminder(
      habitId: habit.id,
      title: name,
      reminderEnabled: reminderEnabled,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
      reminderMode: reminderMode,
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

  /// Reschedules the habit's reminder (if it had one enabled) so it doesn't
  /// silently stay reminder-less after coming back — mirrors [addHabit]/
  /// [updateHabit]'s scheduling.
  Future<void> unarchiveHabit(Habit habit) async {
    await _repo.unarchiveHabit(habit.id);
    await _scheduleReminder(
      habitId: habit.id,
      title: habit.name,
      reminderEnabled: habit.reminderEnabled,
      reminderHour: habit.reminderHour,
      reminderMinute: habit.reminderMinute,
      reminderMode: ReminderMode.fromStorage(habit.reminderMode),
    );
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

  Future<void> _scheduleReminder({
    required String habitId,
    required String title,
    required bool reminderEnabled,
    required int? reminderHour,
    required int? reminderMinute,
    required ReminderMode reminderMode,
  }) async {
    if (reminderEnabled && reminderHour != null && reminderMinute != null && _remindersEnabled()) {
      await _notifications.scheduleHabitReminder(
        habitId: habitId,
        title: title,
        hour: reminderHour,
        minute: reminderMinute,
        mode: reminderMode,
      );
    }
  }
}

final habitsControllerProvider = Provider<HabitsController>((ref) {
  return HabitsController(
    ref.watch(habitsRepositoryProvider),
    ref.watch(notificationServiceProvider),
    () => ref.read(settingsProvider).habitReminders,
  );
});
