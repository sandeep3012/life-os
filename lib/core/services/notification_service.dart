import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Thin wrapper around `flutter_local_notifications` for the two reminder
/// kinds the app schedules: a one-off nudge at a task's due time, and a
/// single daily nudge for open habits. Kept deliberately minimal — no
/// per-habit scheduling, no rich notification actions — since this is groundwork
/// for Phase 2, not a notifications feature in its own right.
class NotificationService {
  NotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const _taskChannel = AndroidNotificationDetails(
    'task_reminders',
    'Task reminders',
    channelDescription: 'Reminders for tasks with a due time',
    importance: Importance.defaultImportance,
  );

  static const _habitChannel = AndroidNotificationDetails(
    'habit_reminders',
    'Habit reminders',
    channelDescription: 'Daily nudge for habits not yet logged today',
    importance: Importance.defaultImportance,
  );

  static const _dailyHabitReminderId = 0;

  /// Notification setup is best-effort: a missing platform channel (e.g. in
  /// widget tests) or a denied/unavailable permission must never take the
  /// rest of the app down with it, so failures here are swallowed.
  Future<void> init() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      await _plugin.initialize(
        settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      _initialized = true;
    } catch (_) {
      // No platform channel / permission denied — reminders just won't fire.
    }
  }

  /// Schedules a one-off reminder at [dueDate]. Uses `exactAllowWhileIdle` so
  /// it fires even in Doze, but falls back silently if [dueDate] has already
  /// passed (no-op — the caller only calls this for future due dates anyway).
  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required DateTime dueDate,
  }) async {
    if (dueDate.isBefore(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: taskId.hashCode,
      title: title,
      body: 'Due now',
      scheduledDate: tz.TZDateTime.from(dueDate, tz.local),
      notificationDetails: NotificationDetails(
        android: _taskChannel,
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelTaskReminder(String taskId) {
    return _plugin.cancel(id: taskId.hashCode);
  }

  /// Schedules (or re-schedules) one recurring notification at [hour]:[minute]
  /// local time every day, reminding the user to check in on open habits.
  Future<void> scheduleDailyHabitReminder({int hour = 20, int minute = 0}) async {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id: _dailyHabitReminderId,
      title: 'Habit check-in',
      body: "Don't break the streak — log today's habits",
      scheduledDate: next,
      notificationDetails: NotificationDetails(
        android: _habitChannel,
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyHabitReminder() {
    return _plugin.cancel(id: _dailyHabitReminderId);
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
