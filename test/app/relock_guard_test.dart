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

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    lock = _FakeLock();
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

  for (final state in [AppLifecycleState.inactive, AppLifecycleState.paused]) {
    testWidgets('leaving the app (${state.name}) locks it', (tester) async {
      final container = await pumpUnlockedApp(tester);
      expect(container.read(isLockedProvider), isFalse);

      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();

      expect(container.read(isLockedProvider), isTrue);
      await disposeCleanly(tester);
    });

    testWidgets('but not while the phone\'s own prompt is up (${state.name})', (
      tester,
    ) async {
      lock.authenticating = true;
      final container = await pumpUnlockedApp(tester);

      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();

      expect(
        container.read(isLockedProvider),
        isFalse,
        reason: 'the prompt re-locked the app it was unlocking',
      );
      await disposeCleanly(tester);
    });
  }
}
