import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A notification sound that's missing on a platform doesn't fail anything —
/// the phone just plays its default sound instead. So check the wiring: every
/// sound the service names exists for both platforms, survives Android's
/// resource shrinking, and is bundled into the iOS app.
void main() {
  final service = File(
    'lib/core/services/notification_service.dart',
  ).readAsStringSync();
  final android = RegExp(
    r"RawResourceAndroidNotificationSound\(\s*'(\w+)'",
  ).allMatches(service).map((m) => m.group(1)!).toSet();
  final ios = RegExp(
    r"sound: '(\w+)\.wav'",
  ).allMatches(service).map((m) => m.group(1)!).toSet();

  test('the service uses the three LifeOS sounds on both platforms', () {
    expect(android, {'reminder', 'notify', 'alarm_gentle'});
    expect(ios, android);
  });

  test('each Android sound is a raw resource kept from shrinking', () {
    final keep = File(
      'android/app/src/main/res/raw/keep.xml',
    ).readAsStringSync();
    for (final name in android) {
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
    for (final name in ios) {
      expect(File('ios/Runner/$name.wav').existsSync(), isTrue, reason: name);
      expect(project, contains('/* $name.wav in Resources */,'), reason: name);
    }
  });
}
