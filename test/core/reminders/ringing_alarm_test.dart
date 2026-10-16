import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/reminders/alarm_sound.dart';
import 'package:life_manager/core/reminders/alarm_tone.dart';
import 'package:life_manager/core/reminders/reminder_status.dart';
import 'package:life_manager/core/reminders/ringing_alarm.dart';
import 'package:life_manager/core/reminders/ringing_alarm_controller.dart';
import 'package:life_manager/core/services/notification_service.dart';
import 'package:life_manager/core/widgets/alarm_ringing_layer.dart';

class _FakeSound implements AlarmSound {
  final played = <AlarmTone>[];
  int stops = 0;
  bool get ringing => played.length > stops;

  @override
  Future<void> start(AlarmTone tone) async => played.add(tone);

  @override
  Future<void> stop() async => stops++;
}

class _FakeNotifications extends NotificationService {
  final taps = StreamController<RingingAlarm>.broadcast();
  RingingAlarm? launched;
  final snoozed = <RingingAlarm>[];
  final dismissed = <RingingAlarm>[];

  @override
  Future<void> init() async {}

  @override
  Stream<RingingAlarm> get ringingAlarms => taps.stream;

  @override
  Future<RingingAlarm?> alarmThatLaunchedApp() async => launched;

  @override
  Future<void> snooze(RingingAlarm alarm) async => snoozed.add(alarm);

  @override
  Future<void> dismiss(RingingAlarm alarm) async => dismissed.add(alarm);
}

const _alarm = RingingAlarm(
  notificationId: 42,
  title: 'Take vitamins',
  body: 'With breakfast',
  kind: 'medication',
);

void main() {
  test('an alarm payload carries what the ringing screen and Snooze need', () {
    final line = RingingAlarm.detailsLine(
      title: 'Gym: legs',
      body: 'Due now',
      kind: 'task',
    );
    final payload = 'lifeos.schedule:task:t1:2026-10-15T07:00:00.000:alarm:gentle\n$line';
    final alarm = RingingAlarm.fromPayload(7, payload)!;
    expect(alarm.title, 'Gym: legs');
    expect(alarm.body, 'Due now');
    expect(alarm.kind, 'task');
    expect(alarm.notificationId, 7);

    // The status list still reads the first line.
    final queued = QueuedReminder.fromPayload(payload, 'Gym: legs')!;
    expect(queued.time, DateTime(2026, 10, 15, 7));

    // A plain notification isn't an alarm.
    expect(
      RingingAlarm.fromPayload(
        7,
        'lifeos.schedule:task:t1:2026-10-15T07:00:00.000:notification',
      ),
      isNull,
    );
    expect(RingingAlarm.fromPayload(7, null), isNull);
  });

  test('a snoozed alarm can be snoozed again, under a stable id', () {
    final again = RingingAlarm.fromPayload(_alarm.snoozeId, _alarm.snoozePayload)!;
    expect(again.title, _alarm.title);
    expect(_alarm.snoozeId, isNot(_alarm.notificationId));
    expect(_alarm.snoozePayload.startsWith('lifeos.schedule:'), isFalse,
        reason: 'the schedule reconciler must not cancel a snooze');
  });

  testWidgets('an alarm opening the app rings until snoozed or dismissed', (
    tester,
  ) async {
    final notifications = _FakeNotifications();
    final sound = _FakeSound();
    final container = ProviderContainer(
      overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
        alarmSoundProvider.overrideWithValue(sound),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(392, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Stack(children: [Text('The app'), AlarmRingingLayer()]),
        ),
      ),
    );
    await container.read(ringingAlarmProvider.notifier).start();

    notifications.taps.add(_alarm);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Take vitamins'), findsOneWidget);
    expect(find.text('MEDICATION'), findsOneWidget);
    expect(find.text('Snooze 10 min'), findsOneWidget);
    // It rings from the app, with the notification taken down so it
    // doesn't ring twice.
    expect(sound.ringing, isTrue);
    expect(notifications.dismissed.single.notificationId, 42);

    await tester.tap(find.text('Snooze 10 min'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(notifications.snoozed.single.notificationId, 42);
    expect(sound.ringing, isFalse);
    expect(find.text('Take vitamins'), findsNothing);

    notifications.taps.add(_alarm);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Dismiss'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    // Once when it rang, once for the button.
    expect(notifications.dismissed, hasLength(3));
    expect(sound.ringing, isFalse);
    expect(find.text('Take vitamins'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an alarm that launched the app from closed shows at once', (
    tester,
  ) async {
    final notifications = _FakeNotifications()..launched = _alarm;
    final sound = _FakeSound();
    final container = ProviderContainer(
      overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
        alarmSoundProvider.overrideWithValue(sound),
      ],
    );
    addTearDown(container.dispose);
    await container.read(ringingAlarmProvider.notifier).start();
    expect(container.read(ringingAlarmProvider), _alarm);
    expect(sound.ringing, isTrue);
  });
}
