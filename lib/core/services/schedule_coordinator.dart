import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/app_database_provider.dart';
import '../reminders/reminder_mode.dart';
import '../reminders/scheduled_reminder.dart';
import '../scheduling/repeat_schedule.dart';
import '../../features/tasks/data/tasks_repository.dart';
import '../../features/calendar/data/calendar_repository.dart';
import '../../features/habits/domain/habit_schedule.dart';
import 'notification_service.dart';

/// Reconciles a bounded rolling queue after writes, on resume and at midnight.
/// Occurrences are generated independently of whether previous ones are done.
class ScheduleCoordinator {
  ScheduleCoordinator(this.db, this.notifications);
  final AppDatabase db;
  final NotificationService notifications;
  StreamSubscription<dynamic>? _changes;
  Timer? _debounce;
  Timer? _clock;
  bool _running = false;
  bool _again = false;
  bool _disposed = false;
  DateTime? _generatedDay;

  void start() {
    _changes = db.customSelect('SELECT 1', readsFrom: {
      db.tasks, db.habits, db.habitLogs, db.events, db.appSettings, db.bills, db.goals,
    }).watch().listen((_) => requestRefresh(), onError: (Object e) => debugPrint('Schedule watch: $e'));
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_generatedDay != RepeatSchedule.day(DateTime.now())) requestRefresh();
    });
    requestRefresh();
  }

  void requestRefresh() {
    if (_disposed) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _refresh);
  }

  Future<void> _refresh() async {
    if (_disposed) return;
    if (_running) { _again = true; return; }
    _running = true;
    try {
      final today = RepeatSchedule.day(DateTime.now());
      if (_generatedDay != today) {
        await TasksRepository(db).extendRecurringTasks();
        await CalendarRepository(db).extendRecurringEvents();
        _generatedDay = today;
      }
      final settings = await db.select(db.appSettings).getSingleOrNull();
      if (settings == null) return;
      final tasks = await db.select(db.tasks).get();
      final habits = await db.select(db.habits).get();
      final events = await db.select(db.events).get();
      final logs = await db.select(db.habitLogs).get();
      final completed = {for (final l in logs.where((l) => l.completed))
        '${l.habitId}:${RepeatSchedule.day(l.date).toIso8601String()}'};
      final now = DateTime.now();
      final reminders = <ScheduledReminder>[];
      for (final t in tasks) {
        if (settings.taskReminders && t.reminderEnabled && t.status != 'done' && t.dueDate != null && t.dueDate!.isAfter(now)) {
          reminders.add(ScheduledReminder(key: 'task:${t.id}', title: t.title,
            time: t.dueDate!, kind: 'task', mode: ReminderMode.fromStorage(t.reminderMode)));
        }
      }
      for (final e in events) {
        final time = e.startTime.subtract(Duration(minutes: e.reminderMinutesBefore));
        if (settings.taskReminders && e.reminderEnabled && time.isAfter(now)) {
          reminders.add(ScheduledReminder(key: 'event:${e.id}', title: e.title,
            time: time, kind: 'event', mode: ReminderMode.fromStorage(e.reminderMode)));
        }
      }
      for (final h in habits) {
        if (!settings.habitReminders || h.archived || !h.reminderEnabled || h.reminderHour == null || h.reminderMinute == null) continue;
        // At most 60 candidates per habit; a single global queue is selected below.
        var count = 0;
        for (final date in h.repeatSchedule.between(today, DateTime(today.year + 2, today.month, today.day))) {
          if (completed.contains('${h.id}:${RepeatSchedule.day(date).toIso8601String()}')) continue;
          final time = DateTime(date.year, date.month, date.day, h.reminderHour!, h.reminderMinute!);
          if (!time.isAfter(now)) continue;
          reminders.add(ScheduledReminder(key: 'habit:${h.id}:${RepeatSchedule.day(date).toIso8601String()}',
            title: h.name, time: time, kind: 'habit', mode: ReminderMode.fromStorage(h.reminderMode)));
          if (++count >= 60) break;
        }
      }
      reminders.sort((a, b) { final c = a.time.compareTo(b.time); return c != 0 ? c : a.key.compareTo(b.key); });
      if (_disposed) return;
      await notifications.replaceScheduledReminders(reminders, legacyIds: {
        for (final t in tasks) t.id.hashCode,
        for (final e in events) 'event_reminder_${e.id}'.hashCode,
        for (final h in habits) 'habit_reminder_${h.id}'.hashCode,
      });
    } catch (e, stack) {
      debugPrint('Schedule refresh failed: $e\n$stack');
    } finally {
      _running = false;
      if (_again && !_disposed) { _again = false; requestRefresh(); }
    }
  }

  void dispose() { _disposed = true; _changes?.cancel(); _clock?.cancel(); _debounce?.cancel(); }
}

final scheduleCoordinatorProvider = Provider<ScheduleCoordinator>((ref) {
  final coordinator = ScheduleCoordinator(ref.watch(appDatabaseProvider), ref.watch(notificationServiceProvider));
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
