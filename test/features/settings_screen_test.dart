import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_color_theme.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/services/app_lock_service.dart';
import 'package:life_manager/core/services/notification_service.dart';
import 'package:life_manager/features/settings/application/app_lock_providers.dart';
import 'package:life_manager/features/settings/application/settings_providers.dart';
import 'package:life_manager/features/settings/presentation/screens/settings_screen.dart';

class _FakeAppLockService extends AppLockService {
  String? _pin;
  bool deviceAuthAvailable = false;

  @override
  Future<void> setPin(String pin) async => _pin = pin;

  @override
  Future<bool> verifyPin(String pin) async => _pin != null && _pin == pin;

  @override
  Future<bool> hasPin() async => _pin != null;

  @override
  Future<void> clearPin() async => _pin = null;

  @override
  Future<bool> canUseDeviceAuth() async => deviceAuthAvailable;

  DeviceAuthResult nextAuth = DeviceAuthResult.success;
  final authReasons = <String>[];

  @override
  Future<DeviceAuthResult> authenticateWithDevice({
    String reason = 'Unlock LifeOS',
  }) async {
    authReasons.add(reason);
    return nextAuth;
  }
}

class _FakeNotificationService extends NotificationService {
  int scheduleCalls = 0;
  int cancelCalls = 0;

  @override
  Future<void> init() async {}

  @override
  Future<void> scheduleDailyHabitReminder({
    int hour = 20,
    int minute = 0,
  }) async {
    scheduleCalls++;
  }

  @override
  Future<void> cancelDailyHabitReminder() async {
    cancelCalls++;
  }
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late _FakeNotificationService notifications;
  late _FakeAppLockService appLock;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    notifications = _FakeNotificationService();
    appLock = _FakeAppLockService();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(notifications),
        appLockServiceProvider.overrideWithValue(appLock),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  Widget buildApp() {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light(), home: const SettingsScreen()),
    );
  }

  testWidgets('defaults render when no settings row exists yet', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).colorTheme, AppColorTheme.forest);

    final settings = container.read(settingsProvider);
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.taskReminders, isTrue);
    expect(settings.aiInsightAlerts, isFalse);
  });

  testWidgets(
    'changing theme persists and is reflected back through the stream',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(container.read(settingsProvider).themeMode, ThemeMode.dark);

      final row = await db.select(db.appSettings).getSingle();
      expect(row.themeMode, 'dark');
      // Untouched settings must survive a partial upsert.
      expect(row.taskReminders, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('changing color theme persists and updates resolved settings', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();
    expect(find.text('Preview Ocean'), findsOneWidget);
    await tester.tap(find.text('Apply & restart'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).colorTheme, AppColorTheme.ocean);
    final row = await db.select(db.appSettings).getSingle();
    expect(row.colorTheme, 'ocean');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('transaction recorder layout persists', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await container
        .read(settingsControllerProvider)
        .setTransactionEntryLayout('form');
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).transactionEntryLayout, 'form');
    final row = await db.select(db.appSettings).getSingle();
    expect(row.transactionEntryLayout, 'form');
  });

  testWidgets(
    'turning off habit reminders cancels the scheduled notification',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView).first, const Offset(0, -420));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Habit reminders'));
      await tester.pumpAndSettle();

      expect(container.read(settingsProvider).habitReminders, isFalse);
      expect(notifications.cancelCalls, 1);

      await tester.tap(find.text('Habit reminders'));
      await tester.pumpAndSettle();

      expect(container.read(settingsProvider).habitReminders, isTrue);
      expect(notifications.scheduleCalls, 1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('changing currency updates the displayed symbol', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Currency'), 200);
    await tester.ensureVisible(find.text('Currency'));
    await tester.pumpAndSettle();
    expect(find.text('₹ · INR'), findsOneWidget);

    await tester.tap(find.text('Currency'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('US Dollar (USD)'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).currencyCode, 'USD');
    expect(find.text('\$ · USD'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('enabling app lock requires setting a PIN to complete', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('App lock'), 200);
    await tester.ensureVisible(find.text('App lock'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('App lock'));
    await tester.pumpAndSettle();

    // The pin-setup sheet is open — cancel without entering anything.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).appLockEnabled, isFalse);

    await tester.scrollUntilVisible(find.text('App lock'), 200);
    await tester.ensureVisible(find.text('App lock'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('App lock'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm PIN'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).appLockEnabled, isTrue);
    expect(await appLock.hasPin(), isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('disabling app lock requires the correct PIN', (tester) async {
    await appLock.setPin('1234');
    await container.read(settingsControllerProvider).setAppLockEnabled(true);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('App lock'), 200);
    await tester.ensureVisible(find.text('App lock'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('App lock'));
    await tester.pumpAndSettle();

    // Wrong PIN keeps app lock enabled.
    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).appLockEnabled, isTrue);

    await tester.tap(find.text('App lock'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).appLockEnabled, isFalse);
    expect(await appLock.hasPin(), isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });

  group('app lock with the phone lock', () {
    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('App lock'), 200);
      await tester.ensureVisible(find.text('App lock'));
      await tester.pumpAndSettle();
    }

    Future<void> disposeCleanly(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    }

    Future<void> tapAppLock(WidgetTester tester) async {
      await tester.tap(find.text('App lock'));
      await tester.pumpAndSettle();
    }

    testWidgets('with a phone lock available, turning it on asks which way', (
      tester,
    ) async {
      appLock.deviceAuthAvailable = true;
      await open(tester);

      await tapAppLock(tester);

      expect(find.text('Unlock with'), findsOneWidget);
      expect(find.text('Phone lock'), findsOneWidget);
      expect(find.text('Recommended'), findsOneWidget);
      expect(find.text('App PIN'), findsOneWidget);
      await disposeCleanly(tester);
    });

    testWidgets(
      'choosing Phone lock confirms with the phone and needs no PIN',
      (tester) async {
        appLock.deviceAuthAvailable = true;
        await open(tester);

        await tapAppLock(tester);
        await tester.tap(find.text('Phone lock'));
        await tester.pumpAndSettle();

        expect(appLock.authReasons, ['Confirm to turn on app lock']);
        final settings = container.read(settingsProvider);
        expect(settings.appLockEnabled, isTrue);
        expect(settings.biometricEnabled, isTrue);
        expect(
          await appLock.hasPin(),
          isFalse,
          reason: 'no extra PIN to remember',
        );
        await disposeCleanly(tester);
      },
    );

    testWidgets('if the phone does not confirm, the lock stays off', (
      tester,
    ) async {
      appLock
        ..deviceAuthAvailable = true
        ..nextAuth = DeviceAuthResult.cancelled;
      await open(tester);

      await tapAppLock(tester);
      await tester.tap(find.text('Phone lock'));
      await tester.pumpAndSettle();

      expect(container.read(settingsProvider).appLockEnabled, isFalse);
      expect(container.read(settingsProvider).biometricEnabled, isFalse);
      await disposeCleanly(tester);
    });

    testWidgets(
      'choosing App PIN goes to PIN setup, and leaves phone lock off',
      (tester) async {
        appLock.deviceAuthAvailable = true;
        await open(tester);

        await tapAppLock(tester);
        await tester.tap(find.text('App PIN'));
        await tester.pumpAndSettle();
        expect(find.text('Set a new PIN'), findsOneWidget);

        await tester.enterText(find.byType(TextField), '2468');
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '2468');
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        final settings = container.read(settingsProvider);
        expect(settings.appLockEnabled, isTrue);
        expect(settings.biometricEnabled, isFalse);
        expect(await appLock.hasPin(), isTrue);
        await disposeCleanly(tester);
      },
    );

    testWidgets('closing the chooser turns nothing on', (tester) async {
      appLock.deviceAuthAvailable = true;
      await open(tester);

      await tapAppLock(tester);
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();

      expect(container.read(settingsProvider).appLockEnabled, isFalse);
      expect(appLock.authReasons, isEmpty);
      await disposeCleanly(tester);
    });

    testWidgets(
      'turning off a phone-lock-only app lock confirms with the phone',
      (tester) async {
        appLock.deviceAuthAvailable = true;
        final controller = container.read(settingsControllerProvider);
        await controller.setAppLockEnabled(true);
        await controller.setBiometricEnabled(true);
        await open(tester);

        // The phone doesn't confirm: still on.
        appLock.nextAuth = DeviceAuthResult.cancelled;
        await tapAppLock(tester);
        expect(container.read(settingsProvider).appLockEnabled, isTrue);

        // It does: off, and phone lock reset with it.
        appLock.nextAuth = DeviceAuthResult.success;
        await tapAppLock(tester);
        expect(appLock.authReasons.last, 'Confirm to turn off app lock');
        expect(container.read(settingsProvider).appLockEnabled, isFalse);
        expect(container.read(settingsProvider).biometricEnabled, isFalse);
        await disposeCleanly(tester);
      },
    );

    testWidgets('phone lock cannot be switched off while there is no PIN', (
      tester,
    ) async {
      appLock.deviceAuthAvailable = true;
      final controller = container.read(settingsControllerProvider);
      await controller.setAppLockEnabled(true);
      await controller.setBiometricEnabled(true);
      await open(tester);

      await tester.tap(find.text('Use phone lock'));
      await tester.pumpAndSettle();

      expect(
        find.text('Set an app PIN first, or turn off app lock.'),
        findsOneWidget,
      );
      expect(container.read(settingsProvider).biometricEnabled, isTrue);
      await disposeCleanly(tester);
    });

    testWidgets(
      'phone lock can be switched off when a PIN is there to fall back on',
      (tester) async {
        appLock.deviceAuthAvailable = true;
        await appLock.setPin('1234');
        final controller = container.read(settingsControllerProvider);
        await controller.setAppLockEnabled(true);
        await controller.setBiometricEnabled(true);
        await open(tester);

        await tester.tap(find.text('Use phone lock'));
        await tester.pumpAndSettle();

        expect(container.read(settingsProvider).biometricEnabled, isFalse);
        await disposeCleanly(tester);
      },
    );

    testWidgets('switching phone lock on needs the phone to confirm', (
      tester,
    ) async {
      appLock.deviceAuthAvailable = true;
      await appLock.setPin('1234');
      await container.read(settingsControllerProvider).setAppLockEnabled(true);
      await open(tester);

      appLock.nextAuth = DeviceAuthResult.cancelled;
      await tester.tap(find.text('Use phone lock'));
      await tester.pumpAndSettle();
      expect(container.read(settingsProvider).biometricEnabled, isFalse);

      appLock.nextAuth = DeviceAuthResult.success;
      await tester.tap(find.text('Use phone lock'));
      await tester.pumpAndSettle();
      expect(container.read(settingsProvider).biometricEnabled, isTrue);
      await disposeCleanly(tester);
    });

    testWidgets('without a phone lock, the switch says so and is off', (
      tester,
    ) async {
      appLock.deviceAuthAvailable = false;
      await appLock.setPin('1234');
      await container.read(settingsControllerProvider).setAppLockEnabled(true);
      await open(tester);

      expect(
        find.text('Set a screen lock on your phone first'),
        findsOneWidget,
      );
      await disposeCleanly(tester);
    });

    testWidgets(
      'the PIN row reads Set app PIN with none, Change PIN with one',
      (tester) async {
        appLock.deviceAuthAvailable = true;
        final controller = container.read(settingsControllerProvider);
        await controller.setAppLockEnabled(true);
        await controller.setBiometricEnabled(true);
        await open(tester);

        expect(find.text('Set app PIN'), findsOneWidget);
        expect(find.text('Change PIN'), findsNothing);
        expect(find.text('Remove app PIN'), findsNothing);
        await disposeCleanly(tester);
      },
    );

    testWidgets('with a PIN and phone lock on, the PIN can be removed', (
      tester,
    ) async {
      appLock.deviceAuthAvailable = true;
      await appLock.setPin('1234');
      final controller = container.read(settingsControllerProvider);
      await controller.setAppLockEnabled(true);
      await controller.setBiometricEnabled(true);
      await open(tester);

      expect(find.text('Change PIN'), findsOneWidget);
      await tester.tap(find.text('Remove app PIN'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(await appLock.hasPin(), isFalse);
      expect(container.read(settingsProvider).appLockEnabled, isTrue);
      await disposeCleanly(tester);
    });

    testWidgets('a PIN-only lock cannot have its PIN removed', (tester) async {
      appLock.deviceAuthAvailable = true;
      await appLock.setPin('1234');
      await container.read(settingsControllerProvider).setAppLockEnabled(true);
      await open(tester);

      expect(
        find.text('Remove app PIN'),
        findsNothing,
        reason: 'would leave no way in',
      );
      await disposeCleanly(tester);
    });
  });
}
