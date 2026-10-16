import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/finance/application/finance_providers.dart';
import '../../features/goals/application/goals_providers.dart';
import '../../features/settings/application/settings_providers.dart';
import '../services/notification_service.dart';
import '../services/schedule_coordinator.dart';
import 'alarm_tone.dart';

/// Keeps queued alarms ringing with the tone chosen in Settings.
///
/// At start-up it hands the saved tone to the notification service before
/// anything is scheduled. When the tone changes it re-schedules every alarm —
/// tasks, events, habits and doses through the schedule coordinator, whose
/// queue reads the tone as part of each alarm; bills and goals directly — and
/// only then removes the old tone's channels, so no alarm is left on a
/// channel that no longer exists.
class AlarmToneSync {
  AlarmToneSync(this._ref);

  final Ref _ref;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    final notifications = _ref.read(notificationServiceProvider);
    notifications.useAlarmTone(_ref.read(settingsProvider).alarmTone);
    _ref.listen<AlarmTone>(
      settingsProvider.select((s) => s.alarmTone),
      (previous, tone) {
        if (previous == tone) return;
        apply(tone);
      },
    );
  }

  Future<void> apply(AlarmTone tone) async {
    final notifications = _ref.read(notificationServiceProvider);
    notifications.useAlarmTone(tone);
    try {
      await _ref.read(scheduleCoordinatorProvider).refreshNow();
      await _ref.read(financeControllerProvider).rescheduleBillAlarms();
      await _ref.read(goalsControllerProvider).rescheduleGoalAlarms();
      await notifications.deleteUnusedAlarmChannels();
    } catch (_) {
      // Re-scheduling is best-effort, like all notification work: a failure
      // leaves alarms on the old tone rather than breaking the app.
    }
  }
}

final alarmToneSyncProvider = Provider<AlarmToneSync>(AlarmToneSync.new);
