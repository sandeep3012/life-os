import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/theme/app_colors.dart';
import 'dashed_action_button.dart';

/// The accent-tinted "Build a new …" row that closes a collection's list and
/// stands in for the screen's FAB while it is on screen.
///
/// The host screen keeps one add affordance visible at a time: it listens to
/// [onVisibilityChanged] and hides its FAB while this row is in view. Both
/// lazy and eager lists are handled — a lazily built list unmounts the row
/// once it leaves the cache extent (so [dispose] reports hidden), but inside
/// that extent, and in a non-lazy list, the row stays mounted while off
/// screen, so its position is also checked against the viewport after every
/// scroll.
class InlineAddButton extends StatefulWidget {
  const InlineAddButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.onVisibilityChanged,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 0),
  });

  final String label;
  final VoidCallback onTap;

  /// Fired outside the build phase (post-frame, or a microtask on unmount),
  /// so the host may call `setState` from it directly.
  final ValueChanged<bool> onVisibilityChanged;

  final EdgeInsets padding;

  @override
  State<InlineAddButton> createState() => _InlineAddButtonState();
}

class _InlineAddButtonState extends State<InlineAddButton> {
  ScrollPosition? _position;
  bool _checkScheduled = false;
  bool? _reported;

  /// Forces the next check to report even if the value hasn't changed from
  /// this row's point of view. Set on every rebuild, because the host may have
  /// been told something different in the meantime — on a tab switch the
  /// outgoing row's `dispose` microtask lands *after* the incoming row's
  /// post-frame check, overwriting a correct `true` with a stale `false`.
  /// Without this the incoming row would stay silent, believing it had already
  /// reported, and the FAB would be stuck on.
  bool _forceReport = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_scheduleCheck);
      _position = position;
      _position?.addListener(_scheduleCheck);
    }
    _scheduleCheck();
  }

  @override
  void dispose() {
    _position?.removeListener(_scheduleCheck);
    // The tree is mid-unmount, so the host can't rebuild synchronously; a
    // microtask lands before the next frame's own visibility check, which
    // lets a replacement button (tab switch, list rebuild) win.
    if (_reported == true) {
      final report = widget.onVisibilityChanged;
      scheduleMicrotask(() => report(false));
    }
    super.dispose();
  }

  void _scheduleCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (mounted) _check();
    });
  }

  void _check() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    // Both viewport render objects are RenderBoxes; the interface just
    // doesn't say so, hence the cast.
    final viewportBox = RenderAbstractViewport.maybeOf(box) as RenderBox?;
    var visible = true;
    if (viewportBox != null && viewportBox.hasSize) {
      final top = box.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
      final middle = top + box.size.height / 2;
      visible = middle >= 0 && middle <= viewportBox.size.height;
    }
    if (!_forceReport && _reported == visible) return;
    _forceReport = false;
    _reported = visible;
    widget.onVisibilityChanged(visible);
  }

  @override
  Widget build(BuildContext context) {
    // Scrolling is not the only thing that moves this row. The list above it
    // grows when its data stream emits — on Health and Learn the first frame
    // renders an empty list, so the row starts on screen and is pushed far
    // below the fold a frame later. Checking only on scroll left the FAB
    // hidden with no way to reach it. A rebuild is exactly when the content
    // above can have changed, so re-check then; the check is debounced to one
    // per frame and only reports on a change, so this cannot loop.
    _forceReport = true;
    _scheduleCheck();
    return Padding(
      padding: widget.padding,
      child: DashedActionButton(
        label: widget.label,
        onTap: widget.onTap,
        color: context.appColors.accentInk,
      ),
    );
  }
}
