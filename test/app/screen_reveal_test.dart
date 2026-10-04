import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/transitions/screen_reveal.dart';

/// A screen whose colour and label flip, standing in for a theme change.
class _Screen extends StatefulWidget {
  const _Screen({super.key});

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  bool dark = false;
  int taps = 0;

  void goDark() => setState(() => dark = true);

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: GestureDetector(
      onTap: () => taps++,
      child: ColoredBox(
        color: dark ? Colors.black : Colors.white,
        child: Center(child: Text(dark ? 'dark' : 'light')),
      ),
    ),
  );
}

void main() {
  final screen = GlobalKey<_ScreenState>();

  /// Pumps until [reveal] finishes. One long pump isn't enough: an
  /// animation's first frame only records its start time.
  Future<void> finish(WidgetTester tester, Future<void> reveal) async {
    var done = false;
    reveal.whenComplete(() => done = true);
    for (var i = 0; i < 100 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(done, isTrue, reason: 'the reveal never finished');
    await tester.pump();
  }

  Future<void> disposeCleanly(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('without a ScreenReveal in the tree the change just applies', (
    tester,
  ) async {
    var applied = false;
    await ScreenReveal.run(
      style: RevealStyle.circle,
      change: () => applied = true,
    );
    expect(applied, isTrue);
    expect(ScreenReveal.isActive, isFalse);
  });

  for (final style in RevealStyle.values) {
    testWidgets('${style.name}: covers the change, then uncovers it', (
      tester,
    ) async {
      await tester.pumpWidget(ScreenReveal(child: _Screen(key: screen)));

      final done = ScreenReveal.run(
        style: style,
        origin: const Offset(20, 20),
        change: () => screen.currentState!.goDark(),
      );
      // The picture of the old screen goes up before anything changes.
      await tester.pump();
      expect(ScreenReveal.isActive, isTrue);

      // A tap while it's animating lands on the picture, not the app.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('dark'), findsOneWidget);
      await tester.tapAt(const Offset(400, 300));
      expect(screen.currentState!.taps, 0);

      await finish(tester, done);
      expect(ScreenReveal.isActive, isFalse);

      await tester.tapAt(const Offset(400, 300));
      expect(screen.currentState!.taps, 1);
      await disposeCleanly(tester);
    });
  }

  testWidgets('waits for the change to show before uncovering', (tester) async {
    await tester.pumpWidget(ScreenReveal(child: _Screen(key: screen)));
    var applied = false;

    final done = ScreenReveal.run(
      style: RevealStyle.circle,
      // The write "finishes" at once, but reaches the screen later — as a
      // setting does, round-tripping through the database.
      change: () {},
      isApplied: () => applied,
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Still waiting: the circle hasn't started, the picture covers all.
    expect(ScreenReveal.isActive, isTrue);

    applied = true;
    await finish(tester, done);
    expect(ScreenReveal.isActive, isFalse);
    await disposeCleanly(tester);
  });

  testWidgets('a restart-driven change waits for contentReady', (tester) async {
    await tester.pumpWidget(ScreenReveal(child: _Screen(key: screen)));

    final done = ScreenReveal.run(
      style: RevealStyle.pageTurn,
      change: () {},
      awaitContentReady: true,
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(ScreenReveal.isActive, isTrue);

    ScreenReveal.contentReady();
    await finish(tester, done);
    expect(ScreenReveal.isActive, isFalse);
    await disposeCleanly(tester);
  });

  testWidgets('a second change during a reveal applies straight away', (
    tester,
  ) async {
    await tester.pumpWidget(ScreenReveal(child: _Screen(key: screen)));

    final first = ScreenReveal.run(style: RevealStyle.circle, change: () {});
    await tester.pump();
    var second = false;
    await ScreenReveal.run(
      style: RevealStyle.circle,
      change: () => second = true,
    );
    expect(second, isTrue);

    await finish(tester, first);
    await disposeCleanly(tester);
  });
}
