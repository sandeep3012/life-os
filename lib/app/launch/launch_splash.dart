import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/utils/currency_utils.dart';
import '../../features/settings/application/settings_providers.dart';
import '../boot_plate.dart';
import '../motion.dart';
import '../splash_gate.dart';
import '../theme/app_fonts.dart';

/// The animated launch screen that takes over from the static native splash.
///
/// It opens pixel-identical to the native splash (same plate, same 256pt mark,
/// same place), then lifts the logo and shows what the app does — an amount, a
/// task, a habit, an event, a document, a goal — one at a time while the data
/// loads. It ends once [ready] is true and the current item has finished, so a
/// fast launch sees a short version and a slow one sees more; it never runs
/// past [maxDuration]. A tap skips to the app once it's ready.
///
/// It uses the brand splash colours rather than the user's theme: it has to
/// match the native splash in its very first frame, before the theme — which
/// lives in the database — has been read.
class LaunchSplash extends ConsumerStatefulWidget {
  const LaunchSplash({
    super.key,
    required this.ready,
    required this.onFinished,
    this.onLeaving,
  });

  /// Whether the app underneath has its data and can be shown.
  final bool ready;

  /// Called once, as the splash starts fading, so the app underneath can be
  /// revealed and start animating in step with it rather than after it.
  final VoidCallback? onLeaving;

  /// Called once, after the splash has faded out.
  final VoidCallback onFinished;

  static const maxDuration = Duration(seconds: 20);

  // Beats of the sequence. Transitions pass through AppMotion (so reduced
  // motion collapses them); the hold is reading time, so it doesn't.
  static const handoff = Duration(milliseconds: 300);
  static const lift = Duration(milliseconds: 650);
  static const enter = Duration(milliseconds: 350);
  static const hold = Duration(milliseconds: 1250);
  static const exit = Duration(milliseconds: 350);
  static const fadeOut = Duration(milliseconds: 350);

  static const _plateAccent = Color(0xFFFFBB70); // the logo ring's orange

  @override
  ConsumerState<LaunchSplash> createState() => _LaunchSplashState();
}

class _LaunchSplashState extends ConsumerState<LaunchSplash> {
  static const _itemCount = 6;

  Timer? _step;
  Timer? _cap;
  bool _lifted = false;
  bool _leaving = false;
  bool _skipQueued = false;
  bool _capped = false;
  bool _precached = false;

  /// Index into the six items, or null between items / before the first.
  int? _item;
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    _cap = Timer(LaunchSplash.maxDuration, () {
      _capped = true;
      _leave();
    });
    _schedule(LaunchSplash.handoff, () {
      setState(() => _lifted = true);
      _schedule(LaunchSplash.lift, _nextItem);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    // Show nothing until the mark is decoded: an async image paints its first
    // frames empty, which reads as the splash blinking. Only then let the
    // native splash go, so the first visible frame already has the logo.
    precacheImage(
      const AssetImage(_logoAsset),
      context,
    ).whenComplete(() => SplashGate.release(reason: 'launch animation'));
  }

  @override
  void didUpdateWidget(covariant LaunchSplash old) {
    super.didUpdateWidget(old);
    if (!old.ready && widget.ready && _skipQueued) _leave();
  }

  @override
  void dispose() {
    _step?.cancel();
    _cap?.cancel();
    super.dispose();
  }

  void _schedule(Duration d, VoidCallback f) {
    _step?.cancel();
    _step = Timer(d, () {
      if (mounted) f();
    });
  }

  void _nextItem() {
    if (widget.ready || _capped) return _leave();
    setState(() {
      _item = _shown % _itemCount;
      _shown++;
    });
    _schedule(LaunchSplash.enter + LaunchSplash.hold, () {
      // Finish the current item, then go.
      if (widget.ready) return _leave();
      setState(() => _item = null);
      _schedule(LaunchSplash.exit, _nextItem);
    });
  }

  void _leave() {
    if (_leaving || !mounted) return;
    _step?.cancel();
    _cap?.cancel();
    setState(() => _leaving = true);
    widget.onLeaving?.call();
    _step = Timer(AppMotion.of(context, LaunchSplash.fadeOut), () {
      if (mounted) widget.onFinished();
    });
  }

  void _onTap() {
    if (_leaving) return;
    if (widget.ready) {
      _leave();
    } else {
      setState(() => _skipQueued = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness =
        MediaQuery.maybePlatformBrightnessOf(context) ??
        View.of(context).platformDispatcher.platformBrightness;
    final plate = brightness == Brightness.dark
        ? kSplashPlateDark
        : kSplashPlateLight;
    final currency = ref.watch(settingsProvider).currencyCode;
    Duration ms(Duration d) => AppMotion.of(context, d);
    final curve = AppMotion.curveOf(context, Curves.easeOutCubic);

    return AnimatedOpacity(
      opacity: _leaving ? 0 : 1,
      duration: ms(LaunchSplash.fadeOut),
      child: Semantics(
        label: 'LifeOS is opening',
        button: widget.ready,
        onTapHint: widget.ready ? 'Skip to the app' : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          child: ColoredBox(
            color: plate,
            child: LayoutBuilder(
              builder: (context, box) {
                // Starts exactly where the native splash draws its mark.
                final markSize = _lifted ? 84.0 : kSplashMarkSize;
                final markTop = _lifted
                    ? box.maxHeight * 0.12
                    : (box.maxHeight - kSplashMarkSize) / 2;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: ms(LaunchSplash.lift),
                      curve: curve,
                      top: markTop,
                      left: (box.maxWidth - markSize) / 2,
                      width: markSize,
                      height: markSize,
                      child: const RepaintBoundary(
                        child: Image(
                          image: AssetImage(_logoAsset),
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                    Positioned(
                      top: box.maxHeight * 0.12 + 92,
                      left: 0,
                      right: 0,
                      child: AnimatedOpacity(
                        opacity: _lifted ? 0.95 : 0,
                        duration: ms(LaunchSplash.lift),
                        child: const Text(
                          'LifeOS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppFonts.serif,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 36,
                      right: 36,
                      top: box.maxHeight * 0.34,
                      height: box.maxHeight * 0.34,
                      child: Center(
                        child: RepaintBoundary(
                          child: AnimatedSwitcher(
                            duration: ms(LaunchSplash.enter),
                            reverseDuration: ms(LaunchSplash.exit),
                            switchInCurve: curve,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween(
                                      begin:
                                          MediaQuery.of(
                                            context,
                                          ).disableAnimations
                                          ? Offset.zero
                                          : const Offset(0, 0.08),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                            child: _item == null
                                ? const SizedBox.shrink(key: ValueKey('gap'))
                                : KeyedSubtree(
                                    key: ValueKey('item$_shown'),
                                    child: _LaunchItem(
                                      index: _item!,
                                      currencyCode: currency,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: box.maxHeight * 0.12,
                      child: AnimatedOpacity(
                        opacity: _lifted ? 1 : 0,
                        duration: ms(LaunchSplash.lift),
                        child: _Dots(
                          count: _itemCount,
                          active: _item,
                          duration: ms(const Duration(milliseconds: 300)),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: box.maxHeight * 0.06,
                      child: AnimatedOpacity(
                        opacity: widget.ready || _skipQueued ? 0.75 : 0,
                        duration: ms(const Duration(milliseconds: 300)),
                        child: Text(
                          widget.ready
                              ? 'Tap to skip'
                              : 'Opening as soon as your data is ready',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

const _logoAsset = 'assets/icon/splash_logo.png';

class _Dots extends StatelessWidget {
  const _Dots({
    required this.count,
    required this.active,
    required this.duration,
  });

  final int count;
  final int? active;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: duration,
            margin: const EdgeInsets.symmetric(horizontal: 3.5),
            width: i == active ? 18 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: i == active ? 1 : 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

/// One vignette. Each owns a controller that plays its "action" (count up,
/// tick, fill…) once, over the item's hold.
class _LaunchItem extends StatefulWidget {
  const _LaunchItem({required this.index, required this.currencyCode});

  final int index;
  final String currencyCode;

  @override
  State<_LaunchItem> createState() => _LaunchItemState();
}

class _LaunchItemState extends State<_LaunchItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _act;

  @override
  void initState() {
    super.initState();
    _act = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_act.status != AnimationStatus.dismissed) return;
    // Reduced motion shows each item's finished state, not the motion.
    if (MediaQuery.of(context).disableAnimations) {
      _act.value = 1;
    } else {
      _act.forward();
    }
  }

  @override
  void dispose() {
    _act.dispose();
    super.dispose();
  }

  // Timing inside the act: a short beat, then the action.
  Animation<double> _phase(double begin, double end) => CurvedAnimation(
    parent: _act,
    curve: Interval(begin, end, curve: Curves.easeOutCubic),
  );

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: switch (widget.index) {
        0 => _amount(),
        1 => _task(),
        2 => _habit(),
        3 => _event(),
        4 => _document(),
        _ => _goal(),
      },
    );
  }

  Widget _amount() {
    final value = _phase(0.05, 0.85);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Label('Spent this month'),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: value,
          builder: (context, _) => Text(
            formatMinor(
              (1245000 * value.value).round(),
              currencyCode: widget.currencyCode,
              showDecimals: false,
            ),
            style: const TextStyle(
              fontFamily: AppFonts.serif,
              fontSize: 36,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontFeatures: AppFonts.tabular,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const _Sub('Every expense, tracked'),
      ],
    );
  }

  Widget _task() {
    final fill = _phase(0.35, 0.6);
    final tick = _phase(0.45, 0.75);
    final strike = _phase(0.65, 0.95);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Label("Today's to-dos"),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _act,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Color.lerp(
                    Colors.transparent,
                    LaunchSplash._plateAccent,
                    fill.value,
                  ),
                  border: Border.all(
                    color: Color.lerp(
                      Colors.white70,
                      LaunchSplash._plateAccent,
                      fill.value,
                    )!,
                    width: 2.5,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: CustomPaint(painter: _TickPainter(tick.value)),
              ),
              const SizedBox(width: 12),
              // Flexible: a Row can't shrink below its children, so a larger
              // text size would otherwise overflow the card.
              Flexible(
                child: CustomPaint(
                  foregroundPainter: _StrikePainter(strike.value),
                  child: const Text(
                    'Pay electricity bill',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _Sub('1 of 4 done'),
      ],
    );
  }

  Widget _habit() {
    final ring = _phase(0.15, 0.95);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Label('Habits'),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: ring,
          builder: (context, _) => SizedBox(
            width: 92,
            height: 92,
            child: CustomPaint(
              painter: _RingPainter(ring.value),
              child: const Center(
                child: Text(
                  '7/7',
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.flame, size: 14, color: Colors.white),
            SizedBox(width: 5),
            _Sub('12-day streak'),
          ],
        ),
      ],
    );
  }

  Widget _event() {
    final flip = _phase(0.1, 0.6);
    final now = DateTime.now();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Label('Calendar'),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: flip,
          builder: (context, child) => Transform(
            alignment: Alignment.topCenter,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateX((1 - flip.value) * math.pi / 2.4),
            child: child,
          ),
          child: Container(
            width: 74,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: LaunchSplash._plateAccent,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    DateFormat('MMM').format(now).toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: Color(0xFF3A2300),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 6),
                  child: Text(
                    '${now.day}',
                    style: const TextStyle(
                      fontFamily: AppFonts.serif,
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2A2340),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const _Sub('Team sync · 4:00 PM'),
      ],
    );
  }

  Widget _document() {
    final drop = _phase(0.25, 0.8);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Label('Documents'),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: drop,
          builder: (context, _) => SizedBox(
            width: 120,
            height: 86,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 38,
                  top: -6 + 40 * drop.value,
                  child: Opacity(
                    opacity: (1 - drop.value * 1.3).clamp(0, 1),
                    child: Transform.scale(
                      scale: 1 - 0.2 * drop.value,
                      child: const _DocShape(),
                    ),
                  ),
                ),
                const Positioned(left: 18, bottom: 0, child: _FolderShape()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const _Sub('Passport.pdf saved to Identity'),
      ],
    );
  }

  Widget _goal() {
    final bar = _phase(0.1, 0.9);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Label('Goals'),
        const SizedBox(height: 10),
        const Text(
          'Emergency fund',
          style: TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: AnimatedBuilder(
            animation: bar,
            builder: (context, _) => LinearProgressIndicator(
              value: bar.value,
              minHeight: 10,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(
                LaunchSplash._plateAccent,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const _Sub('Target reached'),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
      color: Colors.white.withValues(alpha: 0.8),
    ),
  );
}

class _Sub extends StatelessWidget {
  const _Sub(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: Colors.white.withValues(alpha: 0.85),
    ),
  );
}

class _DocShape extends StatelessWidget {
  const _DocShape();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 56,
      padding: const EdgeInsets.fromLTRB(9, 14, 9, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              height: 3,
              margin: const EdgeInsets.only(bottom: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFCFC8E8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}

class _FolderShape extends StatelessWidget {
  const _FolderShape();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 59,
      child: Stack(
        children: [
          Positioned(
            left: 8,
            top: 0,
            child: Container(
              width: 34,
              height: 14,
              decoration: const BoxDecoration(
                color: LaunchSplash._plateAccent,
                borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 50,
            child: Container(
              decoration: BoxDecoration(
                color: LaunchSplash._plateAccent,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  _TickPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.24, size.height * 0.52)
      ..lineTo(size.width * 0.43, size.height * 0.7)
      ..lineTo(size.width * 0.78, size.height * 0.32);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * t),
      Paint()
        ..color = const Color(0xFF3A2300)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.t != t;
}

class _StrikePainter extends CustomPainter {
  _StrikePainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final y = size.height * 0.55;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width * t, y),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_StrikePainter old) => old.t != t;
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final rect = Offset.zero & size;
    final ring = rect.deflate(stroke / 2);
    canvas.drawArc(
      ring,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = Colors.white24
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke,
    );
    canvas.drawArc(
      ring,
      -math.pi / 2,
      math.pi * 2 * t,
      false,
      Paint()
        ..color = LaunchSplash._plateAccent
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t;
}
