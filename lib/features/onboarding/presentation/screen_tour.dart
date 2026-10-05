import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/motion.dart';
import '../../../app/theme/app_fonts.dart';

/// One stop on a screen tour: the control to light up and what to say.
class TourStep {
  const TourStep({
    required this.target,
    required this.title,
    required this.body,
  });

  final GlobalKey target;
  final String title;
  final String body;
}

/// Plays [steps] over the whole app: the screen dims except for a rounded
/// cut-out around each step's control, with a card explaining it. Completes
/// when the tour is finished or skipped. A step whose control isn't on screen
/// is passed over rather than pointing at nothing.
Future<void> showScreenTour(BuildContext context, List<TourStep> steps) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final done = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ScreenTour(
      steps: steps,
      onDone: () {
        entry.remove();
        if (!done.isCompleted) done.complete();
      },
    ),
  );
  overlay.insert(entry);
  return done.future;
}

class _ScreenTour extends StatefulWidget {
  const _ScreenTour({required this.steps, required this.onDone});

  final List<TourStep> steps;
  final VoidCallback onDone;

  @override
  State<_ScreenTour> createState() => _ScreenTourState();
}

class _ScreenTourState extends State<_ScreenTour> {
  int _index = -1;
  Rect? _hole;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _advance());
  }

  /// Moves to the next step whose control can be found, scrolling it into
  /// view first; ends the tour when there are none left.
  Future<void> _advance() async {
    for (var i = _index + 1; i < widget.steps.length; i++) {
      final target = widget.steps[i].target.currentContext;
      if (target == null || !target.mounted) continue;
      await Scrollable.ensureVisible(
        target,
        alignment: 0.3,
        duration: AppMotion.of(context, AppMotion.screenEnter),
      );
      if (!mounted || !target.mounted) return;
      final box = target.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      setState(() {
        _index = i;
        _hole = rect.inflate(6);
      });
      return;
    }
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final hole = _hole;
    final screen = MediaQuery.sizeOf(context);
    final move = AppMotion.of(context, AppMotion.tabSlide);
    final curve = AppMotion.curveOf(context, AppMotion.standard);
    if (hole == null) {
      // Before the first step is measured: just block touches.
      return const SizedBox.expand();
    }
    final step = widget.steps[_index];
    final last = !widget.steps
        .skip(_index + 1)
        .any((s) => s.target.currentContext != null);
    // The card goes under the cut-out when there's room, else above it.
    const cardHeight = 150.0;
    final below = hole.bottom + 14 + cardHeight < screen.height - 24;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Taps on the dimmed area are swallowed: the tour is the only
          // thing to interact with until it's done or skipped.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: TweenAnimationBuilder<Rect?>(
                tween: RectTween(end: hole),
                duration: move,
                curve: curve,
                builder: (context, rect, _) =>
                    CustomPaint(painter: _ScrimPainter(rect ?? hole)),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: move,
            curve: curve,
            left: 16,
            right: 16,
            top: below ? hole.bottom + 14 : null,
            bottom: below ? null : screen.height - hole.top + 14,
            child: _TipCard(
              step: step,
              position: '${_index + 1} of ${widget.steps.length}',
              last: last,
              onNext: _advance,
              onSkip: widget.onDone,
            ),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.step,
    required this.position,
    required this.last,
    required this.onNext,
    required this.onSkip,
  });

  final TourStep step;
  final String position;
  final bool last;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            step.title,
            style: const TextStyle(
              fontFamily: AppFonts.serif,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            step.body,
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 13.5,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // Takes what the buttons leave: at phone width and a raised
              // text size the row is tight, and the count is the part that
              // can give.
              Expanded(
                child: Text(
                  position,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (!last)
                TextButton(onPressed: onSkip, child: const Text('Skip tour')),
              FilledButton(
                onPressed: onNext,
                child: Text(last ? 'Got it' : 'Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The dim layer, with a rounded hole over the current control and a thin
/// ring around it.
class _ScrimPainter extends CustomPainter {
  _ScrimPainter(this.hole);

  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final cut = RRect.fromRectAndRadius(hole, const Radius.circular(18));
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRRect(cut),
      Paint()..color = const Color(0xA0141612),
    );
    canvas.drawRRect(
      cut.inflate(3),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.hole != hole;
}
