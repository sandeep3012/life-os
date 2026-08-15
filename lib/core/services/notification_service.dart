import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../reminders/reminder_mode.dart';

/// Thin wrapper around `flutter_local_notifications` for the reminder kinds
/// the app schedules: a one-off nudge at a task's due time, a single generic
/// daily nudge for open habits (the app-wide "Habit reminders" setting), and
/// a recurring per-habit reminder at a time the user picks for that habit.
///
/// Each of those can be delivered as a plain [ReminderMode.notification]
/// (respects silent mode / Do Not Disturb, single chime) or as an
/// [ReminderMode.alarm] — loud, bypasses silent mode via the `alarm` audio
/// stream, repeats until dismissed, and shows full-screen if the device is
/// locked, same as a phone's built-in alarm clock.
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

  static final _taskAlarmChannel = AndroidNotificationDetails(
    'task_alarms',
    'Task alarms',
    channelDescription: 'Alarm-style reminders for tasks with a due time',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    audioAttributesUsage: AudioAttributesUsage.alarm,
    sound: UriAndroidNotificationSound('content://settings/system/alarm_alert'),
    fullScreenIntent: true,
    // Insistent flag (4): repeats the sound/vibration until the user
    // interacts with the notification, instead of playing once.
    additionalFlags: _insistentFlag,
  );

  static final _habitAlarmChannel = AndroidNotificationDetails(
    'habit_alarms',
    'Habit alarms',
    channelDescription: 'Alarm-style reminders for habits',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    audioAttributesUsage: AudioAttributesUsage.alarm,
    sound: UriAndroidNotificationSound('content://settings/system/alarm_alert'),
    fullScreenIntent: true,
    additionalFlags: _insistentFlag,
  );

  static const _billChannel = AndroidNotificationDetails(
    'bill_reminders',
    'Bill reminders',
    channelDescription: 'Reminders for upcoming bill due dates',
    importance: Importance.defaultImportance,
  );

  static final _billAlarmChannel = AndroidNotificationDetails(
    'bill_alarms',
    'Bill alarms',
    channelDescription: 'Alarm-style reminders for upcoming bill due dates',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    audioAttributesUsage: AudioAttributesUsage.alarm,
    sound: UriAndroidNotificationSound('content://settings/system/alarm_alert'),
    fullScreenIntent: true,
    additionalFlags: _insistentFlag,
  );

  static const _eventChannel = AndroidNotificationDetails(
    'event_reminders',
    'Event reminders',
    channelDescription: 'Reminders for upcoming calendar events',
    importance: Importance.defaultImportance,
  );

  static final _eventAlarmChannel = AndroidNotificationDetails(
    'event_alarms',
    'Event alarms',
    channelDescription: 'Alarm-style reminders for upcoming calendar events',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    audioAttributesUsage: AudioAttributesUsage.alarm,
    sound: UriAndroidNotificationSound('content://settings/system/alarm_alert'),
    fullScreenIntent: true,
    additionalFlags: _insistentFlag,
  );

  static final _insistentFlag = Int32List.fromList(<int>[4]);

  static const _dailyHabitReminderId = 0;

  /// Notification setup is best-effort: a missing platform channel (e.g. in
  /// widget tests) or a denied/unavailable permission must never take the
  /// rest of the app down with it, so failures here are swallowed.
  Future<void> init() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      // `tz.local` defaults to UTC until explicitly set — without this,
      // every "local time" reminder is computed against UTC instead of the
      // device's actual zone, silently shifting it by the UTC offset (e.g.
      // ~5.5 hours for IST) rather than firing when the user actually asked.
      try {
        tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
      } catch (_) {
        // Falls back to UTC — reminders still fire, just at the wrong
        // wall-clock time, which beats not firing at all.
      }

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      await _plugin.initialize(
        settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      );

      final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
      await android?.requestNotificationsPermission();
      // Android 12+ requires this separately from the notification
      // permission above — without it, `exactAllowWhileIdle`/`alarmClock`
      // silently downgrade to inexact scheduling and reminders can be
      // batched with other nearby alarms instead of firing at their
      // requested time.
      await android?.requestExactAlarmsPermission();
      // Android 14+ requires this to actually show a full-screen alarm UI
      // over the lock screen; without it, an alarm-mode reminder just
      // degrades to a heads-up notification.
      await android?.requestFullScreenIntentPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true, critical: true);

      _initialized = true;
    } catch (_) {
      // No platform channel / permission denied — reminders just won't fire.
    }
  }

  static const _iosAlarmDetails = DarwinNotificationDetails(
    sound: 'default',
    interruptionLevel: InterruptionLevel.timeSensitive,
  );

  /// Schedules a one-off reminder at [dueDate]. Falls back silently if
  /// [dueDate] has already passed (no-op — the caller only calls this for
  /// future due dates anyway).
  ///
  /// [mode] picks the alarm-style channel (loud, bypasses silent mode,
  /// full-screen on lock) versus the regular notification channel. Both use
  /// `exactAllowWhileIdle` scheduling — alarm mode gets its "ring like an
  /// alarm" behavior from the channel's audio attributes and full-screen
  /// intent, not from a different `AndroidScheduleMode` (the alternative,
  /// `alarmClock`, is a one-shot trigger that doesn't support the
  /// day-matching repeat `scheduleHabitReminder` needs).
  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required DateTime dueDate,
    ReminderMode mode = ReminderMode.notification,
  }) async {
    if (dueDate.isBefore(DateTime.now())) return;
    final isAlarm = mode == ReminderMode.alarm;
    await _plugin.zonedSchedule(
      id: taskId.hashCode,
      title: title,
      body: 'Due now',
      scheduledDate: tz.TZDateTime.from(dueDate, tz.local),
      notificationDetails: NotificationDetails(
        android: isAlarm ? _taskAlarmChannel : _taskChannel,
        iOS: isAlarm ? _iosAlarmDetails : const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelTaskReminder(String taskId) {
    return _plugin.cancel(id: taskId.hashCode);
  }

  /// Schedules a one-off reminder for a bill at [reminderTime] (the due
  /// date, offset by however many days early the user asked for). Distinct
  /// notification id namespace from tasks/habits so an ordinary bill id can
  /// never collide with a task or habit id and cancel the wrong reminder.
  Future<void> scheduleBillReminder({
    required String billId,
    required String title,
    required DateTime reminderTime,
    ReminderMode mode = ReminderMode.notification,
  }) async {
    if (reminderTime.isBefore(DateTime.now())) return;
    final isAlarm = mode == ReminderMode.alarm;
    await _plugin.zonedSchedule(
      id: _billReminderId(billId),
      title: title,
      body: 'Bill due',
      scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
      notificationDetails: NotificationDetails(
        android: isAlarm ? _billAlarmChannel : _billChannel,
        iOS: isAlarm ? _iosAlarmDetails : const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelBillReminder(String billId) {
    return _plugin.cancel(id: _billReminderId(billId));
  }

  int _billReminderId(String billId) => 'bill_reminder_$billId'.hashCode;

  /// Schedules a one-off reminder for a calendar event at [reminderTime]
  /// (the event's start time, offset by however many minutes early the user
  /// asked for). Distinct notification id namespace from tasks/habits/bills
  /// so an ordinary event id can never collide with theirs and cancel the
  /// wrong reminder.
  Future<void> scheduleEventReminder({
    required String eventId,
    required String title,
    required DateTime reminderTime,
    ReminderMode mode = ReminderMode.notification,
  }) async {
    if (reminderTime.isBefore(DateTime.now())) return;
    final isAlarm = mode == ReminderMode.alarm;
    await _plugin.zonedSchedule(
      id: _eventReminderId(eventId),
      title: title,
      body: 'Event starting',
      scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
      notificationDetails: NotificationDetails(
        android: isAlarm ? _eventAlarmChannel : _eventChannel,
        iOS: isAlarm ? _iosAlarmDetails : const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelEventReminder(String eventId) {
    return _plugin.cancel(id: _eventReminderId(eventId));
  }

  int _eventReminderId(String eventId) => 'event_reminder_$eventId'.hashCode;

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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyHabitReminder() {
    return _plugin.cancel(id: _dailyHabitReminderId);
  }

  /// Schedules (or re-schedules) a recurring per-habit reminder — a distinct
  /// notification id from both the generic daily check-in (fixed id 0) and
  /// task reminders (`taskId.hashCode`), namespaced so an ordinary habit id
  /// and an ordinary task id can never collide and cancel each other's
  /// notification.
  ///
  Future<void> scheduleHabitReminder({
    required String habitId,
    required String title,
    required int hour,
    required int minute,
    ReminderMode mode = ReminderMode.notification,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));

    final isAlarm = mode == ReminderMode.alarm;
    await _plugin.zonedSchedule(
      id: _habitReminderId(habitId),
      title: title,
      body: "Time to log it — don't break the streak",
      scheduledDate: next,
      notificationDetails: NotificationDetails(
        android: isAlarm ? _habitAlarmChannel : _habitChannel,
        iOS: isAlarm ? _iosAlarmDetails : const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelHabitReminder(String habitId) {
    return _plugin.cancel(id: _habitReminderId(habitId));
  }

  int _habitReminderId(String habitId) => 'habit_reminder_$habitId'.hashCode;
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
