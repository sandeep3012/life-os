import 'package:flutter/material.dart';

import '../../../../app/motion.dart';

/// A row of cards you swipe sideways, with the next one peeking in from the
/// right edge and a dot per card underneath — the peek and the dots are what
/// tell you there's more to swipe to.
///
/// The first card lines up with the rest of the page (it starts at the page
/// margin, [bleed]); the last one, once swiped to, ends at the right margin too,
/// with a sliver of the previous card showing at the left edge. The next card's
/// peek reaches the screen edge. All cards share one [height].
class SwipeCards extends StatefulWidget {
  const SwipeCards({
    super.key,
    required this.children,
    required this.height,
    this.bleed = 20,
    this.peek = 28,
    this.gap = 10,
  });

  final List<Widget> children;
  final double height;

  /// The parent's horizontal padding, which the carousel reaches back across.
  final double bleed;

  /// How much of the next card shows beside the current one.
  final double peek;
  final double gap;

  @override
  State<SwipeCards> createState() => _SwipeCardsState();
}

class _SwipeCardsState extends State<SwipeCards> {
  PageController? _controller;
  double? _fraction;
  int _page = 0;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// One controller per viewport fraction: the fraction depends on the width.
  PageController _controllerFor(double fraction) {
    if (_controller == null || _fraction != fraction) {
      _controller?.dispose();
      _fraction = fraction;
      _controller = PageController(
        viewportFraction: fraction,
        initialPage: _page,
      );
    }
    return _controller!;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final duration = AppMotion.of(context, AppMotion.navColor);

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // P: the page's content width. W: the screen. The pages live in a
            // region one gap wider than P, so that the last card ends exactly
            // at the right margin once the final page snaps into place.
            final regionWidth = constraints.maxWidth + widget.gap;
            final screenWidth = constraints.maxWidth + widget.bleed * 2;
            // The next card starts one gap after this one; [peek] of it shows
            // before the screen edge.
            final cardWidth =
                screenWidth - widget.bleed - widget.gap - widget.peek;
            final controller = _controllerFor(
              (cardWidth + widget.gap) / regionWidth,
            );

            // The OverflowBox sizes itself to the biggest size it is allowed,
            // which inside a scrolling list is unbounded in height — hence the
            // fixed-height box around it.
            return SizedBox(
              height: widget.height,
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: regionWidth,
                maxWidth: regionWidth,
                minHeight: widget.height,
                maxHeight: widget.height,
                child: SizedBox(
                  width: regionWidth,
                  height: widget.height,
                  child: PageView.builder(
                    controller: controller,
                    padEnds: false,
                    // The peek, and the sliver of the previous card, are
                    // outside this box on purpose.
                    clipBehavior: Clip.none,
                    itemCount: widget.children.length,
                    onPageChanged: (page) => setState(() => _page = page),
                    itemBuilder: (context, index) => Padding(
                      padding: EdgeInsets.only(right: widget.gap),
                      child: widget.children[index],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.children.length; i++)
              AnimatedContainer(
                duration: duration,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? scheme.primary : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
