import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/launch/launch_splash.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';

/// The launch animation plays while the app loads and ends once it's ready —
/// finishing the current item, never running past 20 seconds, and skippable
/// by a tap once there's something to skip to.
void main() {
  late AppDatabase db;
  late ValueNotifier<bool> ready;
  late int finished;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ready = ValueNotifier(false);
    finished = 0;
  });

  tearDown(() => db.close());

  const phone = Size(392, 844);

  Widget host({bool reduceMotion = false}) => ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: MediaQuery(
      data: MediaQueryData(size: phone, disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<bool>(
          valueListenable: ready,
          builder: (_, isReady, _) =>
              LaunchSplash(ready: isReady, onFinished: () => finished++),
        ),
      ),
    ),
  );

  Future<void> usePhone(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = phone;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> disposeCleanly(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  // Handoff + logo lift, i.e. when the first item starts.
  const intro = Duration(milliseconds: 300 + 650);
  // One item: enter + hold, then the gap before the next.
  const item = Duration(milliseconds: 350 + 1250);
  const gap = Duration(milliseconds: 350);

  Future<void> advance(WidgetTester tester, Duration d) async {
    // Step in frames so tickers and timers both advance.
    final end = d.inMilliseconds;
    for (var t = 0; t < end; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('items play one after another while loading', (tester) async {
    await usePhone(tester);
    await tester.pumpWidget(host());
    await advance(tester, intro);
    expect(find.text('SPENT THIS MONTH'), findsOneWidget);

    // A beat past the switch: the outgoing item's fade ends as the next
    // one starts.
    await advance(tester, item + gap + const Duration(milliseconds: 200));
    expect(find.text("TODAY'S TO-DOS"), findsOneWidget);
    expect(find.text('SPENT THIS MONTH'), findsNothing);
    expect(finished, 0);
    expect(tester.takeException(), isNull);

    await disposeCleanly(tester);
  });

  testWidgets('once ready, it finishes the current item and then leaves', (
    tester,
  ) async {
    await usePhone(tester);
    await tester.pumpWidget(host());
    await advance(tester, intro + const Duration(milliseconds: 400));
    expect(find.text('SPENT THIS MONTH'), findsOneWidget);

    ready.value = true;
    await tester.pump();
    // Not cut off mid-item…
    await advance(tester, const Duration(milliseconds: 600));
    expect(finished, 0);
    // …but gone once it has played and faded.
    await advance(tester, const Duration(milliseconds: 1400));
    expect(finished, 1);

    await disposeCleanly(tester);
  });

  testWidgets('a tap skips at once when ready, or queues until ready', (
    tester,
  ) async {
    await usePhone(tester);
    await tester.pumpWidget(host());
    await advance(tester, intro);

    // Before ready: remembered, and it says so.
    await tester.tap(find.byType(LaunchSplash));
    await tester.pump();
    expect(find.text('Opening as soon as your data is ready'), findsOneWidget);
    expect(finished, 0);

    // The moment data arrives it leaves, without waiting out the item.
    ready.value = true;
    await advance(tester, const Duration(milliseconds: 450));
    expect(finished, 1);

    await disposeCleanly(tester);
  });

  testWidgets('it never runs past 20 seconds, even if never ready', (
    tester,
  ) async {
    await usePhone(tester);
    await tester.pumpWidget(host());
    await advance(tester, const Duration(seconds: 19));
    expect(finished, 0, reason: 'still inside the cap');
    await advance(tester, const Duration(milliseconds: 1500));
    expect(finished, 1);

    await disposeCleanly(tester);
  });

  testWidgets('onLeaving fires as the fade starts, before onFinished', (
    tester,
  ) async {
    await usePhone(tester);
    var leaving = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MediaQuery(
          data: const MediaQueryData(size: phone),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: LaunchSplash(
              ready: true,
              onLeaving: () => leaving++,
              onFinished: () => finished++,
            ),
          ),
        ),
      ),
    );
    // Ready from the very start: it leaves right after the logo lift,
    // without waiting for an item.
    await advance(tester, intro - const Duration(milliseconds: 50));
    expect(leaving, 0);
    expect(finished, 0);

    await advance(tester, const Duration(milliseconds: 100));
    expect(leaving, 1, reason: 'fires the moment the fade starts');
    expect(finished, 0, reason: 'not until the fade finishes');

    await advance(tester, const Duration(milliseconds: 400));
    expect(finished, 1);

    await disposeCleanly(tester);
  });

  testWidgets('reduced motion still plays through without errors', (
    tester,
  ) async {
    await usePhone(tester);
    await tester.pumpWidget(host(reduceMotion: true));
    await advance(tester, intro);
    expect(find.text('SPENT THIS MONTH'), findsOneWidget);
    ready.value = true;
    await advance(tester, item + gap);
    expect(finished, 1);
    expect(tester.takeException(), isNull);

    await disposeCleanly(tester);
  });
}
