import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_color_theme.dart';
import 'package:life_manager/app/theme/app_font_style.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/features/settings/application/settings_providers.dart';
import 'package:life_manager/features/subscription/application/plan_providers.dart';
import 'package:life_manager/features/subscription/data/plan_backend.dart';
import 'package:life_manager/features/subscription/domain/plan.dart';
import 'package:life_manager/features/sync/application/sync_providers.dart';

import '../sync/sync_fakes.dart';
import 'plan_fakes.dart';

void main() {
  late AppDatabase db;
  late FakeSession session;
  late FakePlanBackend backend;
  late MemoryPlanCache cache;
  late ProviderContainer container;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Someone who chose a Plus theme and font.
    await db
        .into(db.appSettings)
        .insert(
          const AppSettingsCompanion(
            id: Value(0),
            colorTheme: Value('ocean'),
            fontStyle: Value('friendly'),
          ),
        );
    session = FakeSession();
    backend = FakePlanBackend();
    cache = MemoryPlanCache();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        syncSessionProvider.overrideWithValue(session),
        planBackendProvider.overrideWithValue(backend),
        planCacheProvider.overrideWithValue(cache),
      ],
    );
    container.listen(settingsProvider, (_, _) {});
    container.listen(effectiveColorThemeProvider, (_, _) {});
    container.listen(effectiveFontStyleProvider, (_, _) {});
    for (var i = 0; i < 50; i++) {
      if (container.read(settingsProvider).colorTheme == AppColorTheme.ocean) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  PlanState plan() => container.read(planControllerProvider);
  PlanController controller() =>
      container.read(planControllerProvider.notifier);
  (AppColorTheme, AppFontStyle) looks() => (
    container.read(effectiveColorThemeProvider),
    container.read(effectiveFontStyleProvider),
  );

  test('signed out is the free plan: the free theme and font are drawn, the '
      'choice is kept', () async {
    await controller().start();
    expect(plan().status, PlanStatus.signedOut);
    expect(plan().allows(PlusFeature.themes), isFalse);
    expect(looks(), (AppColorTheme.forest, AppFontStyle.classic));
    // Not overwritten: it comes back the moment Plus does.
    expect(container.read(settingsProvider).colorTheme, AppColorTheme.ocean);
  });

  test('an account with Plus gets its chosen looks', () async {
    backend.plus = true;
    session.userId = 'u1';
    await controller().start();
    expect(plan().isPlus, isTrue);
    expect(looks(), (AppColorTheme.ocean, AppFontStyle.friendly));
    expect(cache.plans['u1']!.plus, isTrue);
  });

  test('a signed-in account without Plus is on the free looks', () async {
    session.userId = 'u1';
    await controller().start();
    expect(plan().status, PlanStatus.known);
    expect(plan().isPlus, isFalse);
    expect(looks(), (AppColorTheme.forest, AppFontStyle.classic));
  });

  test('offline, a recent Plus is remembered; an old one is not', () async {
    session.userId = 'u1';
    backend.offline = true;
    cache.plans['u1'] = CachedPlan(
      plus: true,
      checkedAt: DateTime.now().subtract(const Duration(days: 3)),
    );
    await controller().start();
    expect(plan().isPlus, isTrue);
    expect(looks(), (AppColorTheme.ocean, AppFontStyle.friendly));

    cache.plans['u1'] = CachedPlan(
      plus: true,
      checkedAt: DateTime.now().subtract(
        PlanController.trustFor + const Duration(days: 1),
      ),
    );
    await controller().refresh();
    expect(plan().isPlus, isFalse);
    expect(looks(), (AppColorTheme.forest, AppFontStyle.classic));
  });

  test('while a signed-in account is still being checked, nothing is taken '
      'away', () async {
    session.userId = 'u1';
    // As at launch: the controller is first read with someone signed in.
    container.invalidate(planControllerProvider);
    expect(plan().status, PlanStatus.checking);
    expect(plan().allows(PlusFeature.themes), isTrue);
    expect(plan().allows(PlusFeature.fonts), isTrue);
    // But nothing that costs money is promised.
    expect(plan().allows(PlusFeature.sync), isFalse);
    expect(plan().allows(PlusFeature.voice), isFalse);
    expect(looks(), (AppColorTheme.ocean, AppFontStyle.friendly));
  });

  test('signing in and out moves between the plans', () async {
    backend.plus = true;
    await controller().start();
    expect(plan().status, PlanStatus.signedOut);

    session.signIn('u1');
    for (var i = 0; i < 50 && !plan().isPlus; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(plan().isPlus, isTrue);

    await session.signOut();
    for (var i = 0; i < 50 && plan().status != PlanStatus.signedOut; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(plan().status, PlanStatus.signedOut);
    expect(looks(), (AppColorTheme.forest, AppFontStyle.classic));
  });

  test('the voice allowance reads the server and says what is left', () {
    final free = VoiceAllowance.fromJson({
      'plan': 'free',
      'period': 'once',
      'limit': 15,
      'used': 12,
      'remaining': 3,
    })!;
    expect(free.plan, AppPlan.free);
    expect(free.hint, '3 of 15 free voice entries left');
    expect(free.exhausted, isFalse);

    final spent = VoiceAllowance.fromJson({
      'plan': 'free',
      'limit': 15,
      'used': 15,
      'remaining': 0,
    })!;
    expect(spent.exhausted, isTrue);
    expect(spent.exhaustedMessage, contains('15 free voice entries'));

    final plus = VoiceAllowance.fromJson({
      'plan': 'plus',
      'limit': 300,
      'used': 40,
      'remaining': 40,
    })!;
    expect(plus.hint, isNull, reason: 'plenty left: nothing to say');
    final plusDaily = VoiceAllowance.fromJson({
      'plan': 'plus',
      'limit': 300,
      'used': 120,
      'remaining': 0,
    })!;
    expect(plusDaily.exhaustedMessage, contains('today'));
    final plusMonth = VoiceAllowance.fromJson({
      'plan': 'plus',
      'limit': 300,
      'used': 300,
      'remaining': 0,
    })!;
    expect(plusMonth.exhaustedMessage, contains('refill'));
    expect(VoiceAllowance.fromJson('nope'), isNull);
  });
}
