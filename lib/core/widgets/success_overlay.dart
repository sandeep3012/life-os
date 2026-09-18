import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/motion.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_fonts.dart';

/// The design's save confirmation. Comp: a dimmed, blurred backdrop behind a
/// 250px radius-26 card that pops in (scale .82 → 1.06 → 1 over 420ms), holding a
/// 72px accent circle whose tick draws itself over 400ms after a 120ms beat, with
/// an accent ring expanding out of it. Auto-dismisses after 1.9s.
///
/// Present it with [showSuccessOverlay].
class SuccessOverlay extends StatefulWidget {
  const SuccessOverlay({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  State<SuccessOverlay> createState() => _SuccessOverlayState();
}

class _SuccessOverlayState extends State<SuccessOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: AppMotion.successPop,
  );
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: AppMotion.successRingPulse,
  );
  late final AnimationController _tick = AnimationController(
    vsync: this,
    duration: AppMotion.successCheckDraw,
  );

  /// Comp `popIn`: overshoots to 1.06 at 60% before settling at 1.
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.82, end: 1.06).chain(CurveTween(curve: Curves.easeOut)),
      weight: 60,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.06, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
  ]).animate(_pop);

  @override
  void initState() {
    super.initState();
    _pop.forward();
    _ring.forward();
    Future<void>.delayed(AppMotion.successCheckDrawDelay, () {
      if (mounted) _tick.forward();
    });
  }

  @override
  void dispose() {
    _pop.dispose();
    _ring.dispose();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: ScaleTransition(
          scale: _scale,
          child: FadeTransition(
            opacity: _pop,
            child: Container(
              width: 250,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border.all(color: scheme.outline),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Comp `ringPulse`: scale .6 → 2.4 while fading .5 → 0.
                        AnimatedBuilder(
                          animation: _ring,
                          builder: (context, _) {
                            final t = _ring.value;
                            return Opacity(
                              opacity: (0.5 * (1 - t)).clamp(0.0, 1.0),
                              child: Transform.scale(
                                scale: 0.6 + (2.4 - 0.6) * t,
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colors.accentSoft,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.secondary,
                          ),
                          child: AnimatedBuilder(
                            animation: _tick,
                            builder: (context, _) => CustomPaint(
                              painter: _TickPainter(
                                progress: _tick.value,
                                color: scheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.serif,
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 13,
                      height: 1.4,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the comp's tick along its own path, so it appears to be written rather
/// than faded in — the CSS does this with `stroke-dasharray:36` and an offset
/// animating 36 → 0.
class _TickPainter extends CustomPainter {
  const _TickPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    // The comp's tick path, `M5 12l5 5L20 6`, scaled into this box.
    final s = size.width / 24;
    final points = [
      Offset(6 * s, 12.5 * s),
      Offset(10.5 * s, 17 * s),
      Offset(18 * s, 7.5 * s),
    ];

    final full = (points[1] - points[0]).distance + (points[2] - points[1]).distance;
    final target = full * progress.clamp(0.0, 1.0);

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    var drawn = 0.0;
    for (var i = 1; i < points.length; i++) {
      final segment = (points[i] - points[i - 1]).distance;
      if (drawn + segment <= target) {
        path.lineTo(points[i].dx, points[i].dy);
        drawn += segment;
      } else {
        final remaining = math.max(0.0, target - drawn);
        final t = segment == 0 ? 0.0 : remaining / segment;
        final partial = Offset.lerp(points[i - 1], points[i], t)!;
        path.lineTo(partial.dx, partial.dy);
        break;
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) =>
      old.progress != progress || old.color != color;
}

/// Shows [SuccessOverlay] and dismisses it after the comp's 1.9s dwell.
///
/// Returns once dismissed, so callers can await it before navigating.
Future<void> showSuccessOverlay(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: true,
    builder: (context) => SuccessOverlay(title: title, message: message),
  );

  navigator.push(route);
  await Future<void>.delayed(AppMotion.successDwell);
  if (route.isActive) {
    navigator.removeRoute(route);
  }
}
