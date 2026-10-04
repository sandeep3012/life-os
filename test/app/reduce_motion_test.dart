import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app.dart';
import 'package:life_manager/app/motion.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/services/notification_service.dart';

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

/// "Animations: Reduced" works by telling every screen what the phone's own
/// reduce-motion setting would, so AppMotion.of collapses everything at once.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<BuildContext> pumpApp(
    WidgetTester tester, {
    bool reduce = false,
  }) async {
    await db
        .into(db.appSettings)
        .insert(
          AppSettingsCompanion(id: const Value(0), reduceMotion: Value(reduce)),
        );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notificationServiceProvider.overrideWithValue(
            _FakeNotificationService(),
          ),
        ],
        child: const LifeOSApp(),
      ),
    );
    await tester.pumpAndSettle();
    return tester.element(find.byType(Scaffold).first);
  }

  Future<void> disposeCleanly(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('Full leaves every animation at its designed length', (
    tester,
  ) async {
    final screen = await pumpApp(tester);
    expect(MediaQuery.of(screen).disableAnimations, isFalse);
    expect(AppMotion.of(screen, AppMotion.sheetOpen), AppMotion.sheetOpen);
    await disposeCleanly(tester);
  });

  testWidgets('Reduced collapses animations across the app', (tester) async {
    final screen = await pumpApp(tester, reduce: true);
    expect(MediaQuery.of(screen).disableAnimations, isTrue);
    expect(AppMotion.of(screen, AppMotion.sheetOpen), AppMotion.reduced);
    await disposeCleanly(tester);
  });

  testWidgets("the phone's reduce motion wins even when the app is Full", (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final screen = await pumpApp(tester);
    expect(MediaQuery.of(screen).disableAnimations, isTrue);
    await disposeCleanly(tester);
  });
}
