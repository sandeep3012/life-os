import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../reminders/alarm_tone.dart';
import '../reminders/reminder_mode.dart';
import '../reminders/scheduled_reminder.dart';
import '../reminders/reminder_status.dart';
import '../reminders/ringing_alarm.dart';

/// Snooze and Dismiss on an alarm's notification.
const alarmSnoozeAction = 'lifeos.alarm.snooze';
const alarmDismissAction = 'lifeos.alarm.dismiss';

/// The iOS notification category carrying those two buttons.
const _iosAlarmCategory = 'lifeos.alarm';

/// How long Snooze puts an alarm off.
const alarmSnoozeDuration = Duration(minutes: 10);

/// Snooze pressed on an alarm's notification while the app wasn't running.
/// Runs in a background isolate, so it builds its own plugin instance.
@pragma('vm:entry-point')
Future<void> alarmActionInBackground(NotificationResponse response) async {
  if (response.actionId != alarmSnoozeAction) return;
  final alarm = RingingAlarm.fromPayload(response.id ?? 0, response.payload);
  if (alarm == null) return;
  final service = NotificationService();
  await service._initPlugin(background: true);
  await service.snooze(alarm);
}

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

  /// Read-only: viewing status must not trigger permission prompts.
  Future<ReminderStatus> readStatus() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final enabled = android != null
        ? await android.areNotificationsEnabled()
        : (await ios?.checkPermissions())?.isEnabled;
    final pending = await _plugin.pendingNotificationRequests();
    final scheduled =
        pending
            .map((p) => QueuedReminder.fromPayload(p.payload, p.title))
            .whereType<QueuedReminder>()
            .where((r) => r.time.isAfter(DateTime.now()))
            .toList()
          ..sort((a, b) => a.time.compareTo(b.time));
    return ReminderStatus(
      enabled: enabled,
      exactAlarms: await android?.canScheduleExactNotifications(),
      pendingCount: pending.length,
      scheduled: scheduled,
    );
  }

  /// What the phone still has switched off that reminders need: null for
  /// either means the platform doesn't have that switch (or couldn't say).
  Future<({bool notificationsOff, bool exactAlarmsOff})>
  missingReminderPermissions() async {
    await init();
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return (
          notificationsOff: await android.areNotificationsEnabled() == false,
          exactAlarmsOff:
              await android.canScheduleExactNotifications() == false,
        );
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final enabled = (await ios?.checkPermissions())?.isEnabled;
      return (notificationsOff: enabled == false, exactAlarmsOff: false);
    } catch (_) {
      return (notificationsOff: false, exactAlarmsOff: false);
    }
  }

  /// Turns on what [missingReminderPermissions] found off: the system
  /// prompt where the phone still offers one, else this app's page in the
  /// phone's settings (Android stops prompting after two refusals).
  /// [alarm] also asks to ring full screen over the lock screen.
  Future<void> fixReminderPermissions({
    required bool notificationsOff,
    required bool exactAlarmsOff,
    bool alarm = false,
  }) async {
    await init();
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (notificationsOff) {
        final granted = android != null
            ? await android.requestNotificationsPermission()
            : await ios?.requestPermissions(
                alert: true,
                badge: true,
                sound: true,
              );
        if (granted != true) {
          await (android?.openAppNotificationSettings() ??
              ios?.openAppNotificationSettings());
          return;
        }
      }
      if (exactAlarmsOff) await android?.requestExactAlarmsPermission();
      if (alarm) await android?.requestFullScreenIntentPermission();
    } catch (_) {
      // Nothing to ask with on this platform.
    }
  }

  /// Asks for everything reminders need. Safe to call repeatedly: the
  /// system only shows a prompt for what hasn't been decided yet.
  Future<void> requestReminderPermissions() async {
    await init();
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
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
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
            critical: true,
          );
    } catch (_) {
      // No platform channel (tests) or the request failed — reminders just
      // won't fire until permission is granted from the system settings.
    }
  }

  static const _taskChannel = AndroidNotificationDetails(
    'task_reminders_v2',
    'Task reminders',
    channelDescription: 'Reminders for tasks with a due time',
    importance: Importance.defaultImportance,
    sound: RawResourceAndroidNotificationSound('reminder'),
  );

  static const _habitChannel = AndroidNotificationDetails(
    'habit_reminders_v2',
    'Habit reminders',
    channelDescription: 'Daily nudge for habits not yet logged today',
    importance: Importance.defaultImportance,
    sound: RawResourceAndroidNotificationSound('reminder'),
  );

  AndroidNotificationDetails get _taskAlarmChannel =>
      _alarmChannel('task_alarms', 'Task alarms', 'Alarm-style reminders for tasks with a due time');

  AndroidNotificationDetails get _habitAlarmChannel =>
      _alarmChannel('habit_alarms', 'Habit alarms', 'Alarm-style reminders for habits');

  static const _billChannel = AndroidNotificationDetails(
    'bill_reminders_v2',
    'Bill reminders',
    channelDescription: 'Reminders for upcoming bill due dates',
    importance: Importance.defaultImportance,
    sound: RawResourceAndroidNotificationSound('reminder'),
  );

  AndroidNotificationDetails get _billAlarmChannel =>
      _alarmChannel('bill_alarms', 'Bill alarms', 'Alarm-style reminders for upcoming bill due dates');

  static const _eventChannel = AndroidNotificationDetails(
    'event_reminders_v2',
    'Event reminders',
    channelDescription: 'Reminders for upcoming calendar events',
    importance: Importance.defaultImportance,
    sound: RawResourceAndroidNotificationSound('notify'),
  );

  AndroidNotificationDetails get _eventAlarmChannel =>
      _alarmChannel('event_alarms', 'Event alarms', 'Alarm-style reminders for upcoming calendar events');

  static const _goalChannel = AndroidNotificationDetails(
    'goal_reminders_v2',
    'Goal reminders',
    channelDescription: 'Reminders for upcoming goal deadlines',
    importance: Importance.defaultImportance,
    sound: RawResourceAndroidNotificationSound('notify'),
  );

  AndroidNotificationDetails get _goalAlarmChannel =>
      _alarmChannel('goal_alarms', 'Goal alarms', 'Alarm-style reminders for upcoming goal deadlines');

  static final _insistentFlag = Int32List.fromList(<int>[4]);

  // LifeOS's own sounds (assets in android/app/src/main/res/raw as OGG and in
  // the iOS Runner bundle as WAV). Reminders for things to act on — tasks,
  // bills, habits, doses — use "reminder"; events and goal deadlines, which
  // are informational, use the softer "notify"; every alarm uses "alarm_gentle",
  // which Android's insistent flag loops until it's dealt with. iOS plays an
  // app's sound once, so there an alarm sounds for its 9.6 seconds.
  /// The tone alarms ring with — Settings → Alarm tone. Set from the app's
  /// settings before anything is scheduled (see `AlarmToneSync`).
  AlarmTone _alarmTone = AlarmTone.gentle;
  AlarmTone get alarmTone => _alarmTone;
  void useAlarmTone(AlarmTone tone) => _alarmTone = tone;

  /// The channel id for an alarm channel ringing [tone]. Android fixes a
  /// channel's sound when it's created, so each tone needs its own channel;
  /// the gentle tone keeps the id it has always had.
  static String alarmChannelId(String base, AlarmTone tone) =>
      tone == AlarmTone.gentle ? '${base}_v2' : '${base}_${tone.name}';

  static const _alarmChannelBases = [
    'task_alarms',
    'habit_alarms',
    'bill_alarms',
    'event_alarms',
    'goal_alarms',
  ];

  AndroidNotificationDetails _alarmChannel(
    String base,
    String name,
    String description,
  ) => AndroidNotificationDetails(
    alarmChannelId(base, _alarmTone),
    name,
    channelDescription: description,
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    audioAttributesUsage: AudioAttributesUsage.alarm,
    sound: RawResourceAndroidNotificationSound(_alarmTone.sound),
    fullScreenIntent: true,
    // Insistent flag (4): repeats the sound/vibration until the user
    // interacts with the notification, instead of playing once.
    additionalFlags: _insistentFlag,
    // Shown when the phone is in use (no full-screen launch then), so the
    // alarm can be dealt with without opening the app.
    actions: const [
      AndroidNotificationAction(
        alarmSnoozeAction,
        'Snooze 10 min',
        cancelNotification: true,
      ),
      AndroidNotificationAction(
        alarmDismissAction,
        'Dismiss',
        cancelNotification: true,
      ),
    ],
  );

  /// Removes the alarm channels of every tone but the current one. Called
  /// once everything has been re-scheduled onto the new tone's channels, so
  /// Android's notification settings don't list a set per tone.
  Future<void> deleteUnusedAlarmChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    for (final base in _alarmChannelBases) {
      for (final tone in AlarmTone.values) {
        if (tone == _alarmTone) continue;
        try {
          await android.deleteNotificationChannel(
            channelId: alarmChannelId(base, tone),
          );
        } catch (_) {
          // Never created, or the platform refused; nothing to tidy.
        }
      }
    }
  }
  static const _iosReminder = DarwinNotificationDetails(sound: 'reminder.wav');
  static const _iosNotify = DarwinNotificationDetails(sound: 'notify.wav');

  /// Android fixes a channel's sound when the channel is first created, so
  /// giving the channels new sounds meant giving them new ids (`_v2`). These
  /// are the ids they replaced, removed at start-up so phones updated from an
  /// older build don't keep a duplicate set in the system's notification
  /// settings.
  static const _retiredChannelIds = [
    'task_reminders',
    'habit_reminders',
    'bill_reminders',
    'event_reminders',
    'goal_reminders',
    'task_alarms',
    'habit_alarms',
    'bill_alarms',
    'event_alarms',
    'goal_alarms',
  ];

  static const _dailyHabitReminderId = 0;

  /// The one scheduled "worth knowing" note — rescheduled in place.
  static const _insightDigestId = 1;

  static const _insightChannel = AndroidNotificationDetails(
    'insight_alerts',
    'Insight alerts',
    channelDescription: 'A morning note when LifeOS finds something new',
    importance: Importance.defaultImportance,
    sound: RawResourceAndroidNotificationSound('insight'),
  );
  static const _iosInsight = DarwinNotificationDetails(sound: 'insight.wav');

  /// Schedules (or replaces) the morning insight note for [at].
  Future<void> scheduleInsightDigest({
    required String title,
    required String body,
    required DateTime at,
  }) async {
    await init();
    if (!_initialized || !at.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: _insightDigestId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: const NotificationDetails(
        android: _insightChannel,
        iOS: _iosInsight,
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelInsightDigest() async {
    await init();
    if (!_initialized) return;
    await _plugin.cancel(id: _insightDigestId);
  }

  /// Notification setup is best-effort: a missing platform channel (e.g. in
  /// widget tests) or a denied/unavailable permission must never take the
  /// rest of the app down with it, so failures here are swallowed.
  Future<void>? _initializing;
  Future<void> init() => _initializing ??= _initPlugin();

  Future<void> _initPlugin({bool background = false}) async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      // `tz.local` defaults to UTC until explicitly set — without this,
      // every "local time" reminder is computed against UTC instead of the
      // device's actual zone, silently shifting it by the UTC offset (e.g.
      // ~5.5 hours for IST) rather than firing when the user actually asked.
      try {
        tz.setLocalLocation(
          tz.getLocation(await FlutterTimezone.getLocalTimezone()),
        );
      } catch (_) {
        // Falls back to UTC — reminders still fire, just at the wrong
        // wall-clock time, which beats not firing at all.
      }

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      final iosInit = DarwinInitializationSettings(
        notificationCategories: [
          DarwinNotificationCategory(
            _iosAlarmCategory,
            actions: [
              DarwinNotificationAction.plain(alarmSnoozeAction, 'Snooze 10 min'),
              DarwinNotificationAction.plain(
                alarmDismissAction,
                'Dismiss',
                options: {DarwinNotificationActionOption.destructive},
              ),
            ],
          ),
        ],
      );
      await _plugin.initialize(
        settings: InitializationSettings(android: androidInit, iOS: iosInit),
        onDidReceiveNotificationResponse: background ? null : _onResponse,
        onDidReceiveBackgroundNotificationResponse: background
            ? null
            : alarmActionInBackground,
      );
      if (background) {
        _initialized = true;
        return;
      }

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      for (final id in _retiredChannelIds) {
        await android?.deleteNotificationChannel(channelId: id);
      }
      // Permissions are asked separately, by [requestReminderPermissions]:
      // a new user is asked on onboarding's "Turn on reminders" page, where
      // the reason is on screen, rather than by a bare system dialog the
      // moment the app first opens.

      _initialized = true;
    } catch (_) {
      // No platform channel / permission denied — reminders just won't fire.
    }
  }

  DarwinNotificationDetails get _iosAlarmDetails => DarwinNotificationDetails(
    sound: '${_alarmTone.sound}.wav',
    interruptionLevel: InterruptionLevel.timeSensitive,
    categoryIdentifier: _iosAlarmCategory,
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
        iOS: isAlarm ? _iosAlarmDetails : _iosReminder,
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
    String body = 'Bill due',
    required DateTime reminderTime,
    ReminderMode mode = ReminderMode.notification,
  }) async {
    if (reminderTime.isBefore(DateTime.now())) return;
    final isAlarm = mode == ReminderMode.alarm;
    await _plugin.zonedSchedule(
      id: _billReminderId(billId),
      title: title,
      body: body,
      payload: _standaloneAlarmPayload(
        isAlarm,
        title: title,
        body: body,
        kind: 'bill',
      ),
      scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
      notificationDetails: NotificationDetails(
        android: isAlarm ? _billAlarmChannel : _billChannel,
        iOS: isAlarm ? _iosAlarmDetails : _iosReminder,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelBillReminder(String billId) {
    return _plugin.cancel(id: _billReminderId(billId));
  }

  int _billReminderId(String billId) => 'bill_reminder_$billId'.hashCode;

  /// Schedules a one-off reminder for a goal at [reminderTime] (the target
  /// date, offset by however many days early the user asked for). Distinct
  /// notification id namespace from tasks/habits/bills/events so an
  /// ordinary goal id can never collide with theirs and cancel the wrong
  /// reminder.
  Future<void> scheduleGoalReminder({
    required String goalId,
    required String title,
    String body = 'Goal deadline',
    required DateTime reminderTime,
    ReminderMode mode = ReminderMode.notification,
  }) async {
    if (reminderTime.isBefore(DateTime.now())) return;
    final isAlarm = mode == ReminderMode.alarm;
    await _plugin.zonedSchedule(
      id: _goalReminderId(goalId),
      title: title,
      body: body,
      payload: _standaloneAlarmPayload(
        isAlarm,
        title: title,
        body: body,
        kind: 'goal',
      ),
      scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
      notificationDetails: NotificationDetails(
        android: isAlarm ? _goalAlarmChannel : _goalChannel,
        iOS: isAlarm ? _iosAlarmDetails : _iosNotify,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelGoalReminder(String goalId) {
    return _plugin.cancel(id: _goalReminderId(goalId));
  }

  int _goalReminderId(String goalId) => 'goal_reminder_$goalId'.hashCode;

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
        iOS: isAlarm ? _iosAlarmDetails : _iosNotify,
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
  Future<void> scheduleDailyHabitReminder({
    int hour = 20,
    int minute = 0,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id: _dailyHabitReminderId,
      title: 'Habit check-in',
      body: "Don't break the streak — log today's habits",
      scheduledDate: next,
      notificationDetails: NotificationDetails(
        android: _habitChannel,
        iOS: _iosReminder,
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
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));

    final isAlarm = mode == ReminderMode.alarm;
    await _plugin.zonedSchedule(
      id: _habitReminderId(habitId),
      title: title,
      body: "Time to log it — don't break the streak",
      scheduledDate: next,
      notificationDetails: NotificationDetails(
        android: isAlarm ? _habitAlarmChannel : _habitChannel,
        iOS: isAlarm ? _iosAlarmDetails : _iosReminder,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelHabitReminder(String habitId) {
    return _plugin.cancel(id: _habitReminderId(habitId));
  }

  // ---- Ringing alarms -------------------------------------------------------

  final _alarmTaps = StreamController<RingingAlarm>.broadcast();

  /// An alarm opened the app — by its full-screen launch over the lock
  /// screen, or a tap on its notification — while the app was running.
  Stream<RingingAlarm> get ringingAlarms => _alarmTaps.stream;

  /// The alarm that launched the app from closed, if one did.
  Future<RingingAlarm?> alarmThatLaunchedApp() async {
    await init();
    if (!_initialized) return null;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      final response = details?.notificationResponse;
      if (details?.didNotificationLaunchApp != true || response == null) {
        return null;
      }
      if (response.actionId != null) return null;
      return RingingAlarm.fromPayload(response.id ?? 0, response.payload);
    } catch (_) {
      return null;
    }
  }

  void _onResponse(NotificationResponse response) {
    switch (response.actionId) {
      case alarmSnoozeAction:
        final alarm = RingingAlarm.fromPayload(
          response.id ?? 0,
          response.payload,
        );
        if (alarm != null) unawaited(snooze(alarm));
      case alarmDismissAction:
        // Android's button already took the notification down; on iOS it's
        // gone once acted on.
        break;
      default:
        final alarm = RingingAlarm.fromPayload(
          response.id ?? 0,
          response.payload,
        );
        if (alarm != null) _alarmTaps.add(alarm);
    }
  }

  /// Stops [alarm] ringing.
  Future<void> dismiss(RingingAlarm alarm) async {
    await init();
    if (!_initialized) return;
    await _plugin.cancel(id: alarm.notificationId);
  }

  /// Stops [alarm] ringing and rings it again in [alarmSnoozeDuration], as
  /// the same kind of alarm. Scheduled against UTC so it needs no local
  /// time zone — the background isolate doesn't have one.
  Future<void> snooze(RingingAlarm alarm) async {
    await init();
    if (!_initialized) return;
    await _plugin.cancel(id: alarm.notificationId);
    Future<void> schedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
      id: alarm.snoozeId,
      title: alarm.title,
      body: alarm.body.isEmpty ? 'Snoozed' : alarm.body,
      payload: alarm.snoozePayload,
      scheduledDate: tz.TZDateTime.now(tz.UTC).add(alarmSnoozeDuration),
      notificationDetails: NotificationDetails(
        android: switch (alarm.kind) {
          'habit' || 'medication' => _habitAlarmChannel,
          'event' => _eventAlarmChannel,
          'bill' => _billAlarmChannel,
          'goal' => _goalAlarmChannel,
          _ => _taskAlarmChannel,
        },
        iOS: _iosAlarmDetails,
      ),
      androidScheduleMode: mode,
    );
    try {
      await schedule(AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException {
      // Exact alarms not allowed (Android 12+ "Alarms & reminders" off):
      // ring roughly on time rather than not at all.
      await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  /// The payload for an alarm scheduled outside the managed schedule (a
  /// bill's or goal's): only its details, for the ringing screen and Snooze.
  static String? _standaloneAlarmPayload(
    bool isAlarm, {
    required String title,
    required String body,
    required String kind,
  }) => isAlarm
      ? 'lifeos.alarm\n'
            '${RingingAlarm.detailsLine(title: title, body: body, kind: kind)}'
      : null;

  /// iOS has a small pending-notification limit. Keep the earliest reminders,
  /// reserving room for unrelated bill/goal/global reminders. Opening/resuming
  /// the app replenishes this offline queue; no background execution is assumed.
  Future<void> replaceScheduledReminders(
    List<ScheduledReminder> reminders, {
    required Set<int> legacyIds,
  }) async {
    await init();
    if (!_initialized) return;
    final pending = await _plugin.pendingNotificationRequests();
    final ours = pending
        .where(
          (p) =>
              (p.payload?.startsWith('lifeos.schedule:') ?? false) ||
              legacyIds.contains(p.id),
        )
        .toList();
    final otherCount = pending.length - ours.length;
    final capacity = (60 - otherCount).clamp(0, 60).toInt();
    final selected = reminders.take(capacity).toList();
    final byId = {for (final r in selected) r.id: r};
    for (final old in ours) {
      final r = byId[old.id];
      final payload = r == null
          ? null
          : _payloadFor(r);
      // Wording counts as a change too, so improved text reaches reminders
      // that were already queued.
      if (r == null ||
          old.payload != payload ||
          old.title != r.title ||
          old.body != r.body) {
        await _plugin.cancel(id: old.id);
      }
    }
    for (final r in selected) {
      final payload =
          _payloadFor(r);
      if (ours.any(
        (p) =>
            p.id == r.id &&
            p.payload == payload &&
            p.title == r.title &&
            p.body == r.body,
      )) {
        continue;
      }
      final alarm = r.mode == ReminderMode.alarm;
      final android = switch (r.kind) {
        // A dose reminder is the same kind of personal-routine nudge a habit
        // check-in is, so it shares that channel rather than adding one the
        // user would have to configure separately.
        'habit' || 'medication' => alarm ? _habitAlarmChannel : _habitChannel,
        'event' => alarm ? _eventAlarmChannel : _eventChannel,
        _ => alarm ? _taskAlarmChannel : _taskChannel,
      };
      await _plugin.zonedSchedule(
        id: r.id,
        title: r.title,
        body: r.body,
        payload: payload,
        scheduledDate: tz.TZDateTime.from(r.time, tz.local),
        notificationDetails: NotificationDetails(
          android: android,
          iOS: alarm
              ? _iosAlarmDetails
              : r.kind == 'event'
              ? _iosNotify
              : _iosReminder,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  /// What identifies a queued reminder. An alarm's includes its tone, so a
  /// new tone reads as a changed reminder and gets re-scheduled onto the
  /// tone's channel.
  /// An alarm's carries its details on a second line too, for the ringing
  /// screen and Snooze.
  String _payloadFor(ScheduledReminder r) =>
      'lifeos.schedule:${r.key}:${r.time.toIso8601String()}:${r.mode.name}'
      '${r.mode == ReminderMode.alarm ? ':${_alarmTone.name}\n${RingingAlarm.detailsLine(title: r.title, body: r.body, kind: r.kind)}' : ''}';

  int _habitReminderId(String habitId) => 'habit_reminder_$habitId'.hashCode;
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
