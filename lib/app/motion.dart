import 'package:flutter/widgets.dart';

/// Durations and curves transcribed from the design handoff's motion table.
///
/// These are specified values, not suggestions — the handoff marks timings as
/// final — so animation code should reference these rather than inlining its own
/// numbers. CSS `cubic-bezier(a,b,c,d)` maps directly onto Flutter's [Cubic].
class AppMotion {
  AppMotion._();

  // ---- curves ----

  /// `cubic-bezier(.2,.7,.3,1)` — screen enter, and the universal tap response.
  static const standard = Cubic(0.2, 0.7, 0.3, 1);

  /// `cubic-bezier(.2,.8,.2,1)` — drawer, FAB rotation, switch knob.
  static const emphasized = Cubic(0.2, 0.8, 0.2, 1);

  /// `cubic-bezier(.2,.86,.3,1)` — sheet open, which overshoots to −1.2% before
  /// settling. The overshoot itself needs a `TweenSequence`; this is its curve.
  static const sheetIn = Cubic(0.2, 0.86, 0.3, 1);

  /// `cubic-bezier(.4,0,1,1)` — sheet close: accelerates away, no overshoot.
  static const sheetOut = Cubic(0.4, 0, 1, 1);

  // ---- durations ----

  /// Screen enter: opacity 0→1 with translateY 10→0.
  static const screenEnter = Duration(milliseconds: 320);

  /// Sheet open: translateY 102% → −1.2% → 0.
  static const sheetOpen = Duration(milliseconds: 420);
  static const sheetClose = Duration(milliseconds: 190);

  static const scrimIn = Duration(milliseconds: 220);
  static const scrimOut = Duration(milliseconds: 190);

  /// Drawer: translateX −100% → 0.
  static const drawer = Duration(milliseconds: 300);

  /// Any tap target: scale → [pressedScale] while held. Kit §5: 120ms,
  /// scale(.97) — .94 on small square buttons (see [smallPressScale]).
  static const tap = Duration(milliseconds: 120);
  static const pressedScale = 0.97;

  /// The add-menu FAB's plus rotates to [fabRotationTurns] while a sheet is open.
  static const fabRotate = Duration(milliseconds: 300);

  /// 135°, expressed in turns for [AnimatedRotation].
  static const fabRotationTurns = 135 / 360;

  /// Add-menu tiles rise in sequence, [menuTileStagger] apart.
  static const menuTile = Duration(milliseconds: 340);
  static const menuTileStagger = Duration(milliseconds: 40);

  /// The recurring block's reveal when its switch turns on.
  static const recurringReveal = Duration(milliseconds: 260);

  /// Switch knob travel (3px ↔ 22px in the comp).
  static const switchKnob = Duration(milliseconds: 220);

  /// Success overlay: card pop, expanding accent ring, and the check-path draw.
  static const successPop = Duration(milliseconds: 420);
  static const successRingPulse = Duration(milliseconds: 900);
  static const successCheckDraw = Duration(milliseconds: 400);
  static const successCheckDrawDelay = Duration(milliseconds: 120);

  /// How long the success overlay stays before dismissing itself.
  static const successDwell = Duration(milliseconds: 1900);

  /// Light/dark cross-fade.
  static const themeChange = Duration(milliseconds: 400);

  /// What every transition collapses to when the platform asks for reduced
  /// motion. Kit §5: "every transition above collapses to a 160 ms cross-fade.
  /// No exceptions."
  static const reduced = Duration(milliseconds: 160);

  /// The duration to actually use for [duration] in [context].
  ///
  /// Returns [reduced] when the platform has animations disabled, so callers
  /// never have to remember the rule — pass every animation duration through
  /// this rather than using the constants directly in a widget.
  static Duration of(BuildContext context, Duration duration) {
    return MediaQuery.of(context).disableAnimations ? reduced : duration;
  }

  /// The curve to use in [context] — reduced motion wants a plain cross-fade,
  /// not an overshoot.
  static Curve curveOf(BuildContext context, Curve curve) {
    return MediaQuery.of(context).disableAnimations ? Curves.linear : curve;
  }

  /// Press scale, honouring reduced motion (no scale at all when disabled).
  static double pressScaleOf(BuildContext context, {bool small = false}) {
    if (MediaQuery.of(context).disableAnimations) return 1;
    return small ? smallPressScale : pressedScale;
  }

  /// Small square buttons press further than large ones. Kit §5.
  static const smallPressScale = 0.94;
}
