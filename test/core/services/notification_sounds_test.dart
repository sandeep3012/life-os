import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/reminders/alarm_tone.dart';
import 'package:life_manager/core/reminders/reminder_status.dart';
import 'package:life_manager/core/services/notification_service.dart';

/// A notification sound that's missing on a platform doesn't fail anything —
/// the phone just plays its default sound instead. So check the wiring: every
/// sound the app can play exists for both platforms, survives Android's
/// resource shrinking, and is bundled into the iOS app.
void main() {
  final service = File(
    'lib/core/services/notification_service.dart',
  ).readAsStringSync();
  // Notification sounds are named in the service; alarm sounds come from
  // whichever tone is chosen.
  final notificationSounds = RegExp(
    r"RawResourceAndroidNotificationSound\(\s*'(\w+)'",
  ).allMatches(service).map((m) => m.group(1)!).toSet();
  final iosNotificationSounds = RegExp(
    r"sound: '(\w+)\.wav'",
  ).allMatches(service).map((m) => m.group(1)!).toSet();
  final alarmSounds = AlarmTone.values.map((t) => t.sound).toSet();
  final all = {...notificationSounds, ...alarmSounds};

  test('notifications use reminder, notify and insight on both platforms', () {
    expect(notificationSounds, {'reminder', 'notify', 'insight'});
    expect(iosNotificationSounds, notificationSounds);
  });

  test('each Android sound is a raw resource kept from shrinking', () {
    final keep = File(
      'android/app/src/main/res/raw/keep.xml',
    ).readAsStringSync();
    for (final name in all) {
      expect(
        File('android/app/src/main/res/raw/$name.ogg').existsSync(),
        isTrue,
        reason: name,
      );
      expect(keep, contains('@raw/$name'), reason: name);
    }
  });

  test('each iOS sound is in the Runner target', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    for (final name in all) {
      expect(File('ios/Runner/$name.wav').existsSync(), isTrue, reason: name);
      expect(project, contains('/* $name.wav in Resources */,'), reason: name);
    }
  });

  test('every alarm tone has its in-app preview', () {
    for (final tone in AlarmTone.values) {
      expect(
        File('assets/${tone.previewAsset}').existsSync(),
        isTrue,
        reason: tone.name,
      );
    }
  });

  test('each tone rings on its own alarm channel', () {
    // Gentle keeps the id existing installs already have.
    expect(
      NotificationService.alarmChannelId('task_alarms', AlarmTone.gentle),
      'task_alarms_v2',
    );
    final ids = {
      for (final tone in AlarmTone.values)
        NotificationService.alarmChannelId('task_alarms', tone),
    };
    expect(ids, hasLength(AlarmTone.values.length));
  });

  test('stored tones read back, unknown ones fall back to gentle', () {
    for (final tone in AlarmTone.values) {
      expect(AlarmTone.fromStorage(tone.name), tone);
    }
    expect(AlarmTone.fromStorage('siren'), AlarmTone.gentle);
    expect(AlarmTone.fromStorage(null), AlarmTone.gentle);
  });

  test('Reminder status still lists alarms that carry their tone', () {
    final queued = QueuedReminder.fromPayload(
      'lifeos.schedule:task:abc:2026-10-08T09:00:00.000:alarm:marimba',
      'Pay rent',
    );
    expect(queued?.time, DateTime(2026, 10, 8, 9));
    expect(
      QueuedReminder.fromPayload(
        'lifeos.schedule:task:abc:2026-10-08T09:00:00.000:notification',
        'Pay rent',
      ),
      isNotNull,
    );
  });
}
