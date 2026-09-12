import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/haptics.dart';
import '../../app/motion.dart';
import '../../app/theme/app_spacing.dart';

/// Which haptic a [Tappable] fires, from the handoff's haptics map.
enum TapHaptic {
  none,

  /// Keypad keys, chips, category/account/frequency selects, to-do toggles.
  selection,

  /// Opening a form, closing a sheet, incrementing a habit.
  light,

  /// The add FAB, toggling the recurring switch.
  medium,
}

/// A tap target with the press response the design applies to *everything*:
/// `scale → 0.94` over 130ms on `cubic-bezier(.2,.7,.3,1)`, released on tap-up
/// or cancel.
///
/// The comp puts its `.tap` class on every interactive element, so this is the
/// default wrapper for a tappable in this app rather than a special case. Pass
/// [haptic] to also fire the intent that matches the control — it is gated on the
/// user's haptics setting via [LifeHaptics], so call sites don't check it.
///
/// This is a bare gesture target, not a Material [InkWell]: the design has no
/// ripple anywhere, and scale *replaces* it as the press affordance.
class Tappable extends ConsumerStatefulWidget {
  const Tappable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.haptic = TapHaptic.none,
    this.semanticLabel,
    this.selected,
    this.small = false,
    this.enforceMinTouchTarget = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final TapHaptic haptic;

  /// Exposed to assistive tech. Set this when [child] is icon-only.
  final String? semanticLabel;

  /// Set for controls with a selected state (nav items, chips, tabs) so screen
  /// readers announce it.
  final bool? selected;

  /// Small square controls press further — kit §5: `scale(.94)` rather than
  /// `.97`.
  final bool small;

  /// Grows the hit area to the kit's 44px floor around a smaller visual.
  ///
  /// Kit §6 rule 1 is "44px minimum touch target, always — regardless of the
  /// visual size". Opt in on controls whose visual is under 44 (icon buttons,
  /// chips, the reader's star); it shrink-wraps the child, so do NOT set it on
  /// a full-width row, which already clears the floor anyway.
  final bool enforceMinTouchTarget;

  @override
  ConsumerState<Tappable> createState() => _TappableState();
}

class _TappableState extends ConsumerState<Tappable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  /// Deliberately synchronous, and deliberately does not await the haptic.
  ///
  /// A haptic is a side effect of a tap, never a precondition for it. Awaiting it
  /// made every control in the app depend on the platform channel succeeding:
  /// one throw — a device with no vibrator, a test with no channel handler — and
  /// `onTap` was never reached, so the tap silently did nothing. The action fires
  /// first; the buzz is fire-and-forget.
  void _handleTap() {
    final haptics = ref.read(hapticsProvider);
    switch (widget.haptic) {
      case TapHaptic.none:
        break;
      case TapHaptic.selection:
        haptics.selection();
      case TapHaptic.light:
        haptics.light();
      case TapHaptic.medium:
        haptics.medium();
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;

    return Semantics(
      button: enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _handleTap : null,
        onLongPress: widget.onLongPress,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        child: AnimatedScale(
          scale: _pressed
              ? AppMotion.pressScaleOf(context, small: widget.small)
              : 1.0,
          duration: AppMotion.of(context, AppMotion.tap),
          curve: AppMotion.curveOf(context, AppMotion.standard),
          child: widget.enforceMinTouchTarget
              ? ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: AppSpacing.minTouchTarget,
                    minHeight: AppSpacing.minTouchTarget,
                  ),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: widget.child,
                  ),
                )
              : widget.child,
        ),
      ),
    );
  }
}
