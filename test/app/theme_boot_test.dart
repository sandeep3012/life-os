import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app.dart';
import 'package:life_manager/app/boot_plate.dart';
import 'package:life_manager/app/theme/app_color_theme.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/reminders/reminder_mode.dart';
import 'package:life_manager/core/services/notification_service.dart';
import 'package:life_manager/core/services/schedule_coordinator.dart';
import 'package:life_manager/features/settings/application/settings_providers.dart';

class _FakeNotificationService extends NotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<void> scheduleDailyHabitReminder({
    int hour = 20,
    int minute = 0,
  }) async {}

  @override
  Future<void> cancelDailyHabitReminder() async {}

  @override
  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required DateTime dueDate,
    ReminderMode mode = ReminderMode.notification,
  }) async {}
}

/// Starting it would arm a one-minute periodic timer that outlives the test.
class _InertScheduleCoordinator extends ScheduleCoordinator {
  _InertScheduleCoordinator(super.db, super.notifications);

  @override
  void start() {}

  @override
  void requestRefresh() {}
}

/// The colour theme lives in the database, so it isn't known when the app
/// first builds. It used to render in the default theme and repaint in the
/// user's a moment later — a visible flash of the wrong theme after the
/// splash, on every launch and on the in-app restart a theme change triggers.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Widget host() => ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      notificationServiceProvider.overrideWithValue(_FakeNotificationService()),
      scheduleCoordinatorProvider.overrideWith(
        (ref) => _InertScheduleCoordinator(
          ref.watch(appDatabaseProvider),
          ref.watch(notificationServiceProvider),
        ),
      ),
    ],
    child: const LifeOSApp(),
  );

  group('settingsLoadedProvider', () {
    test('is false until the row arrives, then true', () async {
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      // Hold a listener: Riverpod tears an unlistened StreamProvider down
      // before its first emission (see CLAUDE.md).
      container.listen(settingsLoadedProvider, (_, _) {});

      expect(container.read(settingsLoadedProvider), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(settingsLoadedProvider), isTrue);
    });

    test('a missing settings row still counts as loaded', () async {
      // Nothing is written, so the stream emits null rather than a row. The
      // app must not sit on the splash waiting for a row that never comes.
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      container.listen(settingsLoadedProvider, (_, _) {});

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(settingsLoadedProvider), isTrue);
      expect(await db.select(db.appSettings).get(), isEmpty);
    });
  });

  testWidgets('no themed frame is painted before the stored theme is known', (
    tester,
  ) async {
    // 'indigo' is deliberately not the default ('forest'), so a frame drawn
    // from defaults is distinguishable from one drawn from storage.
    await db
        .into(db.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            id: const Value(0),
            colorTheme: const Value('indigo'),
            themeMode: const Value('light'),
          ),
        );

    final indigo = AppTheme.light(AppColorTheme.indigo).colorScheme.primary;
    final forest = AppTheme.light(AppColorTheme.forest).colorScheme.primary;
    expect(indigo, isNot(forest), reason: 'the two themes must be tellable apart');

    // An in-memory database answers almost instantly, so which frame the gate
    // opens on isn't stable enough to assert directly — on a device it is far
    // later. Sample every frame instead and assert the invariant that holds
    // either way: the default theme is never painted, not once. Before the
    // gate existed the very first frame was forest, so this fails loudly.
    final painted = <Color>[];
    void sample() {
      final apps = find.byType(MaterialApp).evaluate();
      if (apps.isEmpty) return;
      final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme;
      if (theme != null) painted.add(theme.colorScheme.primary);
    }

    await tester.pumpWidget(host());
    sample();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      sample();
    }
    await tester.pumpAndSettle();
    sample();

    expect(painted, isNotEmpty, reason: 'the app never rendered at all');
    expect(
      painted,
      isNot(contains(forest)),
      reason: 'a frame was painted in the default theme before the stored one',
    );
    expect(painted.last, indigo);
    expect(find.byType(BootPlate), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('the boot plate matches the native splash plate', (tester) async {
    for (final (brightness, expected) in [
      (Brightness.light, kSplashPlateLight),
      (Brightness.dark, kSplashPlateDark),
    ]) {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(const BootPlate());
      await tester.pump();

      final box = tester.widget<ColoredBox>(find.byType(ColoredBox).first);
      expect(box.color, expected, reason: 'plate colour for $brightness');
    }

    await tester.pumpWidget(const SizedBox());
  });

  test('the plate colours still match pubspec', () {
    // They are duplicated by necessity — pubspec drives the native splash,
    // Dart drives the frame that continues it. Drift between them reappears
    // as the flash this whole mechanism removes.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final splash = pubspec.substring(pubspec.indexOf('flutter_native_splash:'));
    String hex(Color c) =>
        '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}';

    expect(splash, contains('color: "${hex(kSplashPlateLight)}"'));
    expect(splash, contains('color_dark: "${hex(kSplashPlateDark)}"'));
  });
}
