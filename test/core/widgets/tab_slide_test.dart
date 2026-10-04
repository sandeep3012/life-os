import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/motion.dart';
import 'package:life_manager/app/theme/app_color_theme.dart';
import 'package:life_manager/core/widgets/tab_slide.dart';
import 'package:life_manager/features/settings/application/settings_providers.dart';

/// A tab page with state of its own, to prove the slide never remounts it.
class _Page extends StatefulWidget {
  const _Page(this.label);

  final String label;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => taps++),
    child: SizedBox(
      height: 120,
      child: Center(child: Text('${widget.label} $taps')),
    ),
  );
}

/// Switches between two pages; [sliver] puts them in a CustomScrollView.
class _Harness extends StatefulWidget {
  const _Harness({super.key, this.sliver = false});

  final bool sliver;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int index = 0;

  void select(int value) => setState(() => index = value);

  @override
  Widget build(BuildContext context) {
    final page = _Page(index == 0 ? 'Tasks' : 'Habits');
    return widget.sliver
        ? CustomScrollView(
            slivers: [
              SliverTabSlide(
                index: index,
                sliver: SliverToBoxAdapter(child: page),
              ),
            ],
          )
        : TabSlide(index: index, child: page);
  }
}

const _effectsOff = ResolvedSettings(
  themeMode: ThemeMode.system,
  colorTheme: AppColorTheme.forest,
  transactionEntryLayout: 'keypad',
  taskReminders: true,
  habitReminders: true,
  aiInsightAlerts: false,
  currencyCode: 'INR',
  appLockEnabled: false,
  biometricEnabled: false,
  transitionEffectsEnabled: false,
);

void main() {
  final harness = GlobalKey<_HarnessState>();

  Future<void> pump(
    WidgetTester tester, {
    bool sliver = false,
    bool reduceMotion = false,
    ResolvedSettings? settings,
  }) async {
    // A phone-width surface, so the page centre is x = 200.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (settings != null) settingsProvider.overrideWithValue(settings),
        ],
        child: MediaQuery(
          data: MediaQueryData(
            size: const Size(400, 800),
            disableAnimations: reduceMotion,
          ),
          child: MaterialApp(
            home: Scaffold(
              body: _Harness(key: harness, sliver: sliver),
            ),
          ),
        ),
      ),
    );
  }

  /// The frame that builds the new tab, then the one the slide starts on.
  Future<void> startSlide(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  Future<void> disposeCleanly(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  for (final sliver in [false, true]) {
    final kind = sliver ? 'sliver' : 'box';

    testWidgets('$kind: both pages slide, the new one in from the right', (
      tester,
    ) async {
      await pump(tester, sliver: sliver);
      harness.currentState!.select(1);
      await startSlide(tester);
      await tester.pump(AppMotion.tabSlide * 0.3);

      // Mid-slide the old page is on its way out to the left and the new one
      // is arriving from the right.
      final oldX = tester.getCenter(find.text('Tasks 0')).dx;
      final newX = tester.getCenter(find.text('Habits 0')).dx;
      expect(oldX, lessThan(200));
      expect(newX, greaterThan(200));

      await tester.pumpAndSettle();
      expect(find.text('Tasks 0'), findsNothing);
      expect(tester.getCenter(find.text('Habits 0')).dx, closeTo(200, 0.5));
      await disposeCleanly(tester);
    });

    testWidgets("$kind: a slow first frame doesn't use up the slide", (
      tester,
    ) async {
      await pump(tester, sliver: sliver);
      harness.currentState!.select(1);
      await tester.pump();
      // The next frame comes late, as when the new tab is costly to build.
      // Had the slide been running through it, it would be nearly over.
      await tester.pump(AppMotion.tabSlide * 0.9);
      expect(tester.getCenter(find.text('Habits 0')).dx, greaterThan(500));
      expect(tester.getCenter(find.text('Tasks 0')).dx, closeTo(200, 0.5));

      // From there it runs its full course on later frames.
      await tester.pump(AppMotion.tabSlide * 0.2);
      expect(tester.getCenter(find.text('Habits 0')).dx, lessThan(500));
      await tester.pumpAndSettle();
      await disposeCleanly(tester);
    });

    testWidgets('$kind: going back slides the other way', (tester) async {
      await pump(tester, sliver: sliver);
      harness.currentState!.select(1);
      await tester.pumpAndSettle();
      harness.currentState!.select(0);
      await startSlide(tester);
      await tester.pump(AppMotion.tabSlide * 0.3);

      expect(tester.getCenter(find.text('Habits 0')).dx, greaterThan(200));
      expect(tester.getCenter(find.text('Tasks 0')).dx, lessThan(200));
      await tester.pumpAndSettle();
      await disposeCleanly(tester);
    });

    testWidgets('$kind: the arriving page keeps its state once settled', (
      tester,
    ) async {
      await pump(tester, sliver: sliver);
      harness.currentState!.select(1);
      await startSlide(tester);
      await tester.pump(AppMotion.tabSlide * 0.5);
      // Taps mid-slide go to the arriving page, never the leaving one.
      await tester.tap(find.text('Habits 0'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Had the slide's end remounted the page, the count would be back to 0.
      expect(find.text('Habits 1'), findsOneWidget);
      await tester.tap(find.text('Habits 1'));
      await tester.pump();
      expect(find.text('Habits 2'), findsOneWidget);
      await disposeCleanly(tester);
    });

    testWidgets('$kind: reduced motion swaps without sliding', (tester) async {
      await pump(tester, sliver: sliver, reduceMotion: true);
      harness.currentState!.select(1);
      await tester.pump();

      expect(find.text('Tasks 0'), findsNothing);
      expect(tester.getCenter(find.text('Habits 0')).dx, closeTo(200, 0.5));
      await disposeCleanly(tester);
    });

    testWidgets('$kind: transition effects off swaps without sliding', (
      tester,
    ) async {
      await pump(tester, sliver: sliver, settings: _effectsOff);
      harness.currentState!.select(1);
      await tester.pump();

      expect(find.text('Tasks 0'), findsNothing);
      expect(find.text('Habits 0'), findsOneWidget);
      await disposeCleanly(tester);
    });
  }
}
