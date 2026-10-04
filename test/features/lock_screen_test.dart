import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/services/app_lock_service.dart';
import 'package:life_manager/features/settings/application/app_lock_providers.dart';
import 'package:life_manager/features/settings/application/settings_providers.dart';
import 'package:life_manager/features/settings/presentation/screens/lock_screen.dart';

/// Stands in for the PIN store and the phone's own lock.
class _FakeLock extends AppLockService {
  _FakeLock({this.pin, this.deviceAvailable = true});

  String? pin;
  bool deviceAvailable;
  DeviceAuthResult next = DeviceAuthResult.success;
  int authCalls = 0;

  @override
  Future<void> setPin(String value) async => pin = value;

  @override
  Future<bool> verifyPin(String value) async => pin != null && pin == value;

  @override
  Future<bool> hasPin() async => pin != null;

  @override
  Future<void> clearPin() async => pin = null;

  @override
  Future<bool> canUseDeviceAuth() async => deviceAvailable;

  @override
  Future<DeviceAuthResult> authenticateWithDevice({
    String reason = 'Unlock LifeOS',
  }) async {
    authCalls++;
    return next;
  }
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pump(
    WidgetTester tester,
    _FakeLock lock, {
    bool phoneLockOn = false,
  }) async {
    tester.view.physicalSize = const Size(392, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appLockServiceProvider.overrideWithValue(lock),
      ],
    );
    // Keep the settings stream alive and let its first value land.
    container.listen(settingsProvider, (_, _) {});
    // Real async work (the database), so it runs outside the test clock.
    await tester.runAsync(() async {
      await container
          .read(settingsControllerProvider)
          .setBiometricEnabled(phoneLockOn);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light(), home: const LockScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool locked() => container.read(isLockedProvider);

  Future<void> typePin(WidgetTester tester, String digits) async {
    for (final d in digits.split('')) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> disposeCleanly(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  group('with an app PIN', () {
    testWidgets(
      'shows the keypad and does not ask the phone when phone lock is off',
      (tester) async {
        final lock = _FakeLock(pin: '1234');
        await pump(tester, lock);

        expect(find.text('Enter PIN'), findsOneWidget);
        expect(find.text('Unlock with phone lock'), findsNothing);
        expect(lock.authCalls, 0);
        await disposeCleanly(tester);
      },
    );

    testWidgets('the right PIN unlocks', (tester) async {
      await pump(tester, _FakeLock(pin: '1234'));

      expect(locked(), isTrue);
      await typePin(tester, '1234');
      expect(locked(), isFalse);
      await disposeCleanly(tester);
    });

    testWidgets('a wrong PIN does not', (tester) async {
      await pump(tester, _FakeLock(pin: '1234'));

      await typePin(tester, '999999');
      expect(locked(), isTrue);
      expect(find.text('Incorrect PIN'), findsOneWidget);
      await disposeCleanly(tester);
    });

    testWidgets('with phone lock on, it asks the phone as soon as it opens', (
      tester,
    ) async {
      final lock = _FakeLock(pin: '1234');
      await pump(tester, lock, phoneLockOn: true);

      expect(lock.authCalls, 1);
      expect(locked(), isFalse, reason: 'the phone said yes');
      await disposeCleanly(tester);
    });

    testWidgets('if the phone prompt is dismissed, the PIN is still there', (
      tester,
    ) async {
      final lock = _FakeLock(pin: '1234')..next = DeviceAuthResult.cancelled;
      await pump(tester, lock, phoneLockOn: true);

      expect(locked(), isTrue);
      expect(find.text('Enter PIN'), findsOneWidget);
      expect(find.text('Unlock with phone lock'), findsOneWidget);

      await typePin(tester, '1234');
      expect(locked(), isFalse);
      await disposeCleanly(tester);
    });

    testWidgets('the phone-lock button asks again', (tester) async {
      final lock = _FakeLock(pin: '1234')..next = DeviceAuthResult.cancelled;
      await pump(tester, lock, phoneLockOn: true);
      expect(lock.authCalls, 1);

      lock.next = DeviceAuthResult.success;
      await tester.tap(find.text('Unlock with phone lock'));
      await tester.pumpAndSettle();

      expect(lock.authCalls, 2);
      expect(locked(), isFalse);
      await disposeCleanly(tester);
    });

    testWidgets('no phone-lock button when the phone has no lock', (
      tester,
    ) async {
      final lock = _FakeLock(pin: '1234', deviceAvailable: false);
      await pump(tester, lock, phoneLockOn: true);

      expect(find.text('Unlock with phone lock'), findsNothing);
      expect(lock.authCalls, 0);
      await disposeCleanly(tester);
    });
  });

  group('phone lock only (no app PIN)', () {
    testWidgets('asks the phone straight away, and unlocks on success', (
      tester,
    ) async {
      final lock = _FakeLock();
      await pump(tester, lock, phoneLockOn: true);

      expect(lock.authCalls, 1);
      expect(locked(), isFalse);
      await disposeCleanly(tester);
    });

    testWidgets(
      'stays locked if the prompt is dismissed, with an Unlock button',
      (tester) async {
        final lock = _FakeLock()..next = DeviceAuthResult.cancelled;
        await pump(tester, lock, phoneLockOn: true);

        expect(locked(), isTrue);
        expect(find.text('LifeOS is locked'), findsOneWidget);
        expect(find.text('Unlock'), findsOneWidget);
        expect(find.text('Enter PIN'), findsNothing, reason: 'no PIN to enter');
        await disposeCleanly(tester);
      },
    );

    testWidgets('Unlock asks again', (tester) async {
      final lock = _FakeLock()..next = DeviceAuthResult.cancelled;
      await pump(tester, lock, phoneLockOn: true);

      lock.next = DeviceAuthResult.success;
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(locked(), isFalse);
      await disposeCleanly(tester);
    });

    testWidgets('too many attempts says so and stays locked', (tester) async {
      final lock = _FakeLock()..next = DeviceAuthResult.lockedOut;
      await pump(tester, lock, phoneLockOn: true);

      expect(locked(), isTrue);
      expect(
        find.text('Too many attempts. Try again in a moment.'),
        findsOneWidget,
      );
      await disposeCleanly(tester);
    });

    testWidgets('an error says so and stays locked', (tester) async {
      final lock = _FakeLock()..next = DeviceAuthResult.error;
      await pump(tester, lock, phoneLockOn: true);

      expect(locked(), isTrue);
      expect(find.text("Couldn't unlock. Try again."), findsOneWidget);
      await disposeCleanly(tester);
    });

    testWidgets(
      'also prompts when settings came back from a backup with no PIN',
      (tester) async {
        // A restored backup brings the "app lock on" setting but not the PIN, which
        // lives in secure storage. That used to leave a keypad with nothing to
        // check against — a permanent lock-out.
        final lock = _FakeLock();
        await pump(tester, lock, phoneLockOn: false);

        expect(lock.authCalls, 1);
        expect(find.text('Enter PIN'), findsNothing);
        await disposeCleanly(tester);
      },
    );

    testWidgets(
      'the phone losing its lock mid-prompt falls through to the no-lock screen',
      (tester) async {
        final lock = _FakeLock()..next = DeviceAuthResult.unavailable;
        await pump(tester, lock, phoneLockOn: true);
        lock.deviceAvailable = false;
        container.invalidate(canUseDeviceAuthProvider);
        await tester.pumpAndSettle();

        expect(find.text('No phone lock is set'), findsOneWidget);
        await disposeCleanly(tester);
      },
    );
  });

  group('no PIN and no phone lock', () {
    testWidgets('says so and offers to set a PIN', (tester) async {
      final lock = _FakeLock(deviceAvailable: false);
      await pump(tester, lock, phoneLockOn: true);

      expect(find.text('No phone lock is set'), findsOneWidget);
      expect(find.text('Set an app PIN'), findsOneWidget);
      expect(lock.authCalls, 0, reason: 'nothing to ask');
      expect(locked(), isTrue);
      await disposeCleanly(tester);
    });

    testWidgets('setting a PIN unlocks, stores it, and turns phone lock off', (
      tester,
    ) async {
      final lock = _FakeLock(deviceAvailable: false);
      await pump(tester, lock, phoneLockOn: true);

      await tester.tap(find.text('Set an app PIN'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a PIN'), findsOneWidget);

      await typePin(tester, '4821');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm your PIN'), findsOneWidget);

      await typePin(tester, '4821');
      await tester.tap(find.text('Set PIN'));
      await tester.pumpAndSettle();

      expect(lock.pin, '4821');
      expect(locked(), isFalse);
      expect(container.read(settingsProvider).biometricEnabled, isFalse);
      await disposeCleanly(tester);
    });

    testWidgets('a PIN that does not match is refused', (tester) async {
      final lock = _FakeLock(deviceAvailable: false);
      await pump(tester, lock);

      await tester.tap(find.text('Set an app PIN'));
      await tester.pumpAndSettle();
      await typePin(tester, '4821');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await typePin(tester, '1111');
      await tester.tap(find.text('Set PIN'));
      await tester.pumpAndSettle();

      expect(lock.pin, isNull);
      expect(locked(), isTrue);
      expect(find.text("PINs don't match. Start again."), findsOneWidget);
      await disposeCleanly(tester);
    });

    testWidgets('a PIN under four digits is refused', (tester) async {
      final lock = _FakeLock(deviceAvailable: false);
      await pump(tester, lock);

      await tester.tap(find.text('Set an app PIN'));
      await tester.pumpAndSettle();
      await typePin(tester, '12');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('PIN must be at least 4 digits'), findsOneWidget);
      expect(lock.pin, isNull);
      await disposeCleanly(tester);
    });
  });
}
