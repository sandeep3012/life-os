import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/application/settings_providers.dart';
import '../motion.dart';

/// How [ScreenReveal] hands the old screen over to the new one.
enum RevealStyle {
  /// The new screen spreads in a circle from the tapped control.
  circle,

  /// The old screen turns away like a page, hinged on its left edge.
  pageTurn,

  /// A short cross-fade — reduced motion, or transition effects turned off.
  fade,
}

/// Sits above the whole app and animates a change of the *entire* screen:
/// light/dark, colour theme, unlocking, hiding balances.
///
/// It works on a picture of the screen rather than on widgets, which is what
/// lets one mechanism cover changes that rebuild everything — a theme switch
/// repaints every widget, and a colour theme change restarts the app outright.
/// [run] photographs the current screen, covers the app with that picture,
/// applies the change underneath, waits for the new screen to be painted, then
/// animates the picture away to uncover it.
///
/// It lives above [AppRestartBoundary] so the picture survives the restart a
/// colour theme change triggers.
class ScreenReveal extends StatefulWidget {
  const ScreenReveal({super.key, required this.child});

  final Widget child;

  static _ScreenRevealState? _current;

  /// Whether a picture of the old screen is up. Theme lerping is switched off
  /// meanwhile, so the uncovered screen is already in its final colours.
  static bool get isActive => _current?._image != null;

  /// Applies [change] behind a [style] transition starting at [origin], in
  /// global coordinates (the screen centre when null).
  ///
  /// [isApplied] reports when the change has reached the widgets — settings
  /// round-trip through the database, so "the write finished" is not yet
  /// "the screen shows it". [awaitContentReady] waits instead for the app to
  /// call [contentReady], for a change that restarts the app.
  ///
  /// [settleFirst] delays the picture — for a dialog that is still closing
  /// when the change is asked for.
  ///
  /// Without a [ScreenReveal] in the tree (widget tests that pump a screen
  /// directly) the change is simply applied.
  static Future<void> run({
    required RevealStyle style,
    Offset? origin,
    required FutureOr<void> Function() change,
    bool Function()? isApplied,
    bool awaitContentReady = false,
    Duration settleFirst = Duration.zero,
  }) async {
    final state = _current;
    if (state == null || !state.mounted) {
      await change();
      return;
    }
    if (settleFirst > Duration.zero) await Future<void>.delayed(settleFirst);
    if (!state.mounted) {
      await change();
      return;
    }
    await state._run(style, origin, change, isApplied, awaitContentReady);
  }

  /// Called by the app once a restarted interface has its data on screen.
  static void contentReady() {
    final ready = _current?._contentReady;
    if (ready != null && !ready.isCompleted) ready.complete();
  }

  @override
  State<ScreenReveal> createState() => _ScreenRevealState();
}

class _ScreenRevealState extends State<ScreenReveal>
    with SingleTickerProviderStateMixin {
  final _boundaryKey = GlobalKey(debugLabel: 'screen reveal');
  late final _controller = AnimationController(vsync: this);

  ui.Image? _image;
  RevealStyle _style = RevealStyle.fade;
  Offset _origin = Offset.zero;
  bool _busy = false;
  Completer<void>? _contentReady;

  /// How long to wait for a change to show before revealing regardless — a
  /// stalled database write shouldn't leave the screen frozen under a picture.
  static const _settleTimeout = Duration(milliseconds: 1500);
  static const _restartTimeout = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    ScreenReveal._current = this;
  }

  @override
  void dispose() {
    if (ScreenReveal._current == this) ScreenReveal._current = null;
    _controller.dispose();
    _image?.dispose();
    super.dispose();
  }

  Future<void> _run(
    RevealStyle style,
    Offset? origin,
    FutureOr<void> Function() change,
    bool Function()? isApplied,
    bool awaitContentReady,
  ) async {
    final boundary = _boundaryKey.currentContext?.findRenderObject();
    // A second change while one is animating just applies — queueing them
    // would replay a stale picture.
    if (_busy || boundary is! RenderRepaintBoundary || !boundary.hasSize) {
      await change();
      return;
    }
    final ui.Image image;
    try {
      image = boundary.toImageSync(
        pixelRatio: View.of(context).devicePixelRatio,
      );
    } catch (_) {
      await change();
      return;
    }

    _busy = true;
    if (awaitContentReady) _contentReady = Completer<void>();
    setState(() {
      _image = image;
      _style = style;
      _origin = origin ?? boundary.size.center(Offset.zero);
      _controller.value = 0;
    });
    try {
      // The picture must be on screen before anything underneath changes,
      // or the new theme flashes for a frame first.
      await WidgetsBinding.instance.endOfFrame;
      await change();
      await _settle(isApplied);
      if (_contentReady case final ready?) {
        await ready.future.timeout(_restartTimeout, onTimeout: () {});
      }
      // One more frame so the new screen is painted under the picture.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      _controller.duration = switch (style) {
        RevealStyle.circle => AppMotion.circleReveal,
        RevealStyle.pageTurn => AppMotion.pageTurn,
        RevealStyle.fade => AppMotion.reduced,
      };
      await _controller.forward(from: 0).orCancel;
    } on TickerCanceled {
      // Disposed mid-animation; nothing left to uncover.
    } finally {
      _contentReady = null;
      _busy = false;
      if (mounted) setState(() => _image = null);
      // The last frame that drew the picture may still be in flight.
      WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
    }
  }

  Future<void> _settle(bool Function()? isApplied) async {
    if (isApplied == null) return;
    final deadline = DateTime.now().add(_settleTimeout);
    while (mounted && !isApplied() && DateTime.now().isBefore(deadline)) {
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Stack(
      textDirection: TextDirection.ltr,
      fit: StackFit.expand,
      children: [
        RepaintBoundary(key: _boundaryKey, child: widget.child),
        if (image != null)
          Positioned.fill(
            // Taps land on the picture, not the app changing beneath it.
            child: AbsorbPointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => _overlay(image, _controller.value),
              ),
            ),
          ),
      ],
    );
  }

  Widget _overlay(ui.Image image, double t) {
    switch (_style) {
      case RevealStyle.circle:
        return CustomPaint(
          painter: _CircleRevealPainter(
            image: image,
            origin: _origin,
            progress: AppMotion.reveal.transform(t),
          ),
        );
      case RevealStyle.fade:
        return CustomPaint(
          painter: _ImagePainter(image: image, opacity: 1 - t),
        );
      case RevealStyle.pageTurn:
        final e = AppMotion.reveal.transform(t);
        final angle = e * 100 * math.pi / 180;
        return Stack(
          textDirection: TextDirection.ltr,
          fit: StackFit.expand,
          children: [
            // The page's shadow on the new screen, lifting as it turns away.
            ColoredBox(
              color: const Color(0xFF000000).withValues(alpha: 0.28 * (1 - e)),
            ),
            if (angle < math.pi / 2)
              Transform(
                alignment: Alignment.centerLeft,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateY(angle),
                child: CustomPaint(
                  painter: _ImagePainter(image: image, shade: e),
                ),
              ),
          ],
        );
    }
  }
}

/// The old screen with a growing circular hole at [origin].
class _CircleRevealPainter extends CustomPainter {
  _CircleRevealPainter({
    required this.image,
    required this.origin,
    required this.progress,
  });

  final ui.Image image;
  final Offset origin;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Far enough to clear the corner furthest from the tap.
    final reach = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ].map((corner) => (corner - origin).distance).reduce(math.max);
    final hole = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect)
      ..addOval(Rect.fromCircle(center: origin, radius: reach * progress));
    canvas.clipPath(hole);
    _drawImage(canvas, image, rect);
  }

  @override
  bool shouldRepaint(_CircleRevealPainter old) =>
      old.progress != progress || old.image != image || old.origin != origin;
}

/// The old screen, optionally faded, with an optional darkening towards the
/// right edge for the page turn.
class _ImagePainter extends CustomPainter {
  _ImagePainter({required this.image, this.opacity = 1, this.shade = 0});

  final ui.Image image;
  final double opacity;
  final double shade;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    _drawImage(canvas, image, rect, opacity: opacity);
    if (shade > 0) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(rect.centerLeft, rect.centerRight, [
            const Color(0x00000000),
            Color.fromRGBO(0, 0, 0, 0.35 * math.min(1, shade * 1.6)),
          ]),
      );
    }
  }

  @override
  bool shouldRepaint(_ImagePainter old) =>
      old.opacity != opacity || old.shade != shade || old.image != image;
}

void _drawImage(Canvas canvas, ui.Image image, Rect dst, {double opacity = 1}) {
  final src = Rect.fromLTWH(
    0,
    0,
    image.width.toDouble(),
    image.height.toDouble(),
  );
  canvas.drawImageRect(
    image,
    src,
    dst,
    Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Color.fromRGBO(0, 0, 0, opacity.clamp(0, 1)),
  );
}

/// The style to actually use for a transition that wants [wanted]: reduced
/// motion — the phone's or the app's own — and the "Transition effects"
/// setting both collapse it to a fade.
RevealStyle revealStyleOf(
  BuildContext context,
  WidgetRef ref,
  RevealStyle wanted,
) {
  if (MediaQuery.of(context).disableAnimations) return RevealStyle.fade;
  if (!ref.read(settingsProvider).transitionEffectsEnabled) {
    return RevealStyle.fade;
  }
  return wanted;
}

/// The centre of [context]'s widget in global coordinates — where a reveal
/// from that control should start.
Offset? globalCenterOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize || !box.attached) return null;
  return box.localToGlobal(box.size.center(Offset.zero));
}
