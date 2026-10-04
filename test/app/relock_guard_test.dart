import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/services/app_lock_service.dart';
import 'package:life_manager/core/services/notification_service.dart';
import 'package:life_manager/features/settings/application/app_lock_providers.dart';

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
}

class _FakeLock extends AppLockService {
  bool authenticating = false;

  @override
  bool get isAuthenticating => authenticating;

  @override
  Future<bool> hasPin() async => true;

  @override
  Future<bool> verifyPin(String pin) async => pin == '1234';

  @override
  Future<bool> canUseDeviceAuth() async => true;
}

/// The system's Face ID / fingerprint dialog takes focus from the app, and the
/// platform reports that as `inactive` (iOS) or `paused` (Android). The app
/// re-locks on both — which would lock it again the instant the dialog
/// succeeded, unless it knows the dialog is the reason.
void main() {
  late AppDatabase db;
  late _FakeLock lock;
  late DateTime now;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    lock = _FakeLock();
    now = DateTime(2026, 10, 4, 9);
  });

  tearDown(() => db.close());

  Future<ProviderContainer> pumpUnlockedApp(WidgetTester tester) async {
    await db
        .into(db.appSettings)
        .insert(
          AppSettingsCompanion(
            id: const Value(0),
            appLockEnabled: const Value(true),
          ),
        );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notificationServiceProvider.overrideWithValue(
            _FakeNotificationService(),
          ),
          appLockServiceProvider.overrideWithValue(lock),
          relockPolicyProvider.overrideWithValue(RelockPolicy(now: () => now)),
        ],
        child: const LifeOSApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    container.read(isLockedProvider.notifier).unlock();
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> disposeCleanly(WidgetTester tester) async {
    // `paused` stops the framework drawing frames; bring it back first, or the
    // teardown below waits forever for one.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// Home button / app switch: the states the platform walks through.
  Future<void> leave(WidgetTester tester) async {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
  }

  Future<void> comeBack(WidgetTester tester) async {
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
  }

  testWidgets('a quick trip to the background does not lock it', (
    tester,
  ) async {
    final container = await pumpUnlockedApp(tester);

    await leave(tester);
    now = now.add(const Duration(seconds: 40));
    await comeBack(tester);

    expect(container.read(isLockedProvider), isFalse);
    await disposeCleanly(tester);
  });

  testWidgets('a minute or more in the background locks it on return', (
    tester,
  ) async {
    final container = await pumpUnlockedApp(tester);

    await leave(tester);
    // Not while it's away — only when it comes back.
    expect(container.read(isLockedProvider), isFalse);
    now = now.add(RelockPolicy.defaultGrace);
    await comeBack(tester);

    expect(container.read(isLockedProvider), isTrue);
    await disposeCleanly(tester);
  });

  testWidgets(
    'the notification shade or app switcher never locks it, however long',
    (tester) async {
      final container = await pumpUnlockedApp(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      now = now.add(const Duration(minutes: 10));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(container.read(isLockedProvider), isFalse);
      await disposeCleanly(tester);
    },
  );

  testWidgets("the phone's own unlock prompt doesn't count as leaving", (
    tester,
  ) async {
    lock.authenticating = true;
    final container = await pumpUnlockedApp(tester);

    await leave(tester);
    now = now.add(const Duration(minutes: 2));
    await comeBack(tester);

    expect(
      container.read(isLockedProvider),
      isFalse,
      reason: 'the prompt re-locked the app it was unlocking',
    );
    await disposeCleanly(tester);
  });

  group('RelockPolicy', () {
    test('only the first exit starts the clock', () {
      var t = DateTime(2026);
      final policy = RelockPolicy(now: () => t);
      policy.left();
      t = t.add(const Duration(seconds: 50));
      policy.left(); // paused after hidden
      t = t.add(const Duration(seconds: 10));
      expect(policy.returned(), isTrue);
    });

    test('returning without having left never locks', () {
      final policy = RelockPolicy();
      expect(policy.returned(), isFalse);
    });

    test('each return resets the clock', () {
      var t = DateTime(2026);
      final policy = RelockPolicy(now: () => t);
      policy.left();
      t = t.add(const Duration(minutes: 5));
      expect(policy.returned(), isTrue);
      t = t.add(const Duration(minutes: 5));
      expect(policy.returned(), isFalse);
    });
  });

  group('colour theme restart', () {
    test('an unlocked session stays unlocked through it, once', () {
      IsLocked.keepUnlockedThroughRestart();
      final rebuilt = ProviderContainer();
      addTearDown(rebuilt.dispose);
      expect(rebuilt.read(isLockedProvider), isFalse);

      // Consumed: a later start (a real launch) is locked again.
      final later = ProviderContainer();
      addTearDown(later.dispose);
      expect(later.read(isLockedProvider), isTrue);
    });
  });
}
