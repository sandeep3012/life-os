import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_service.dart';
import '../services/system_settings.dart';
import 'alarm_sound.dart';
import 'ringing_alarm.dart';

/// The alarm the ringing screen is showing, if any. Set when an alarm opens
/// the app — from closed, or while it was running — and cleared by Snooze
/// or Dismiss.
class RingingAlarmController extends Notifier<RingingAlarm?> {
  StreamSubscription<RingingAlarm>? _taps;

  @override
  RingingAlarm? build() {
    ref.onDispose(() => _taps?.cancel());
    return null;
  }

  /// Starts following alarms. Called once the app is up.
  Future<void> start() async {
    if (_taps != null) return;
    final notifications = ref.read(notificationServiceProvider);
    _taps = notifications.ringingAlarms.listen(_ring);
    final launched = await notifications.alarmThatLaunchedApp();
    if (launched != null) await _ring(launched);
  }

  /// Shows [alarm] and rings it from the app: the notification is taken
  /// down (opening it stops its sound anyway) so it doesn't ring twice.
  Future<void> _ring(RingingAlarm alarm) async {
    state = alarm;
    final notifications = ref.read(notificationServiceProvider);
    try {
      await notifications.dismiss(alarm);
    } catch (_) {}
    await ref.read(alarmSoundProvider).start(notifications.alarmTone);
  }

  Future<void> snooze() => _finish(
    (notifications, alarm) => notifications.snooze(alarm),
  );

  Future<void> dismiss() => _finish(
    (notifications, alarm) => notifications.dismiss(alarm),
  );

  Future<void> _finish(
    Future<void> Function(NotificationService, RingingAlarm) action,
  ) async {
    final alarm = state;
    if (alarm == null) return;
    state = null;
    await ref.read(alarmSoundProvider).stop();
    try {
      await action(ref.read(notificationServiceProvider), alarm);
    } catch (_) {
      // The screen is already gone; a failed snooze must not leave it stuck.
    }
    // Rang over the lock screen: go back to it, as the clock app does.
    await SystemSettings.leaveIfLocked();
  }
}

final ringingAlarmProvider =
    NotifierProvider<RingingAlarmController, RingingAlarm?>(
      RingingAlarmController.new,
    );
