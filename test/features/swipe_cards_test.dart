import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/spend_analyzer/presentation/widgets/swipe_cards.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(392, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: const [
              SwipeCards(
                height: 200,
                children: [
                  ColoredBox(key: Key('first'), color: Colors.red),
                  ColoredBox(key: Key('second'), color: Colors.blue),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<double> dotWidths(WidgetTester tester) => [
    for (final e in find.byType(AnimatedContainer).evaluate())
      tester.getSize(find.byWidget(e.widget)).width,
  ];

  testWidgets('the first card lines up with the page margin', (tester) async {
    await pump(tester);

    expect(tester.getTopLeft(find.byKey(const Key('first'))).dx, 20);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the next card peeks in from the right edge', (tester) async {
    await pump(tester);

    final first = tester.getRect(find.byKey(const Key('first')));
    final second = tester.getRect(find.byKey(const Key('second')));

    expect(
      second.left,
      greaterThan(first.right),
      reason: 'a gap between cards',
    );
    expect(
      second.left,
      lessThan(392),
      reason: 'the next card is not visible at all',
    );
    expect(
      392 - second.left,
      greaterThanOrEqualTo(20),
      reason: 'peek too slim to notice',
    );
    expect(first.height, second.height);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('one dot per card, the current one stretched', (tester) async {
    await pump(tester);

    final dots = dotWidths(tester);
    expect(dots, hasLength(2));
    expect(dots[0], greaterThan(dots[1]));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('swiping moves to the next card and moves the dot', (
    tester,
  ) async {
    await pump(tester);

    await tester.drag(find.byKey(const Key('first')), const Offset(-300, 0));
    await tester.pumpAndSettle();

    // The last card ends at the right margin, like everything else on the page,
    // and a sliver of the previous one stays at the left edge.
    expect(tester.getTopRight(find.byKey(const Key('second'))).dx, 392 - 20);
    final first = tester.getRect(find.byKey(const Key('first')));
    expect(first.right, greaterThan(0));
    expect(
      first.right,
      lessThan(tester.getRect(find.byKey(const Key('second'))).left),
    );
    final dots = dotWidths(tester);
    expect(dots[1], greaterThan(dots[0]));
    await tester.pumpWidget(const SizedBox());
  });
}
