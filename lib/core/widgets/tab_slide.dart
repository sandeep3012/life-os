import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/motion.dart';
import '../../features/settings/application/settings_providers.dart';

/// Slides a tab's content sideways when [index] changes, in step with the
/// [AppTabRail] pill above it: the old content leaves towards the side the
/// new tab came from while the new content arrives, with the pill's own
/// duration and overshoot.
///
/// Wrap whatever a tab rail swaps — a pane, a list, a column of cards. Use
/// [SliverTabSlide] when the swapped content is a sliver.
///
/// Reduced motion and the "Transition effects" setting both turn it into a
/// plain swap, which is what tabs did before.
class TabSlide extends ConsumerStatefulWidget {
  const TabSlide({super.key, required this.index, required this.child});

  /// The selected tab's position in its rail, so the direction can follow it.
  final int index;
  final Widget child;

  @override
  ConsumerState<TabSlide> createState() => _TabSlideState();
}

class _TabSlideState extends ConsumerState<TabSlide>
    with SingleTickerProviderStateMixin, _TabSlideMixin<TabSlide> {
  @override
  int get index => widget.index;

  @override
  void didUpdateWidget(TabSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    _onIndexChanged(oldWidget.index, oldWidget.child);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _progress;
        // One stable shape whether or not a slide is running, so the current
        // tab's subtree is never remounted when the old one leaves. Not
        // clipped: tab content sits in screen-wide panes or padded lists, and
        // clipping at the padding would cut the cards off short of the edge.
        return Stack(
          fit: StackFit.passthrough,
          children: [
            if (_outgoing case final outgoing?)
              _slot(_outgoingIndex, outgoing, -_direction * t, out: true),
            _slot(widget.index, widget.child, _direction * (1 - t)),
          ],
        );
      },
    );
  }

  Widget _slot(int key, Widget child, double shift, {bool out = false}) =>
      KeyedSubtree(
        key: ValueKey(key),
        child: IgnorePointer(
          ignoring: out,
          child: FractionalTranslation(
            translation: Offset(shift, 0),
            child: child,
          ),
        ),
      );
}

/// [TabSlide] for content that is a sliver in a [CustomScrollView].
class SliverTabSlide extends ConsumerStatefulWidget {
  const SliverTabSlide({super.key, required this.index, required this.sliver});

  final int index;
  final Widget sliver;

  @override
  ConsumerState<SliverTabSlide> createState() => _SliverTabSlideState();
}

class _SliverTabSlideState extends ConsumerState<SliverTabSlide>
    with SingleTickerProviderStateMixin, _TabSlideMixin<SliverTabSlide> {
  @override
  int get index => widget.index;

  @override
  void didUpdateWidget(SliverTabSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    _onIndexChanged(oldWidget.index, oldWidget.sliver);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _progress;
        final outgoing = _outgoing;
        return _SliverSlideStack(
          shifts: [if (outgoing != null) -_direction * t, _direction * (1 - t)],
          children: [
            if (outgoing != null) _slot(_outgoingIndex, outgoing, out: true),
            _slot(widget.index, widget.sliver),
          ],
        );
      },
    );
  }

  Widget _slot(int key, Widget sliver, {bool out = false}) => KeyedSubtree(
    key: ValueKey(key),
    child: SliverIgnorePointer(ignoring: out, sliver: sliver),
  );
}

/// The shared bookkeeping: which content is leaving, which way, and how far
/// through the slide it is.
mixin _TabSlideMixin<W extends ConsumerStatefulWidget>
    on ConsumerState<W>, SingleTickerProviderStateMixin<W> {
  int get index;

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: AppMotion.tabSlide)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _outgoing = null);
          }
        });

  Widget? _outgoing;
  int _outgoingIndex = -1;

  /// +1 when the new tab is to the right of the old one, so its content comes
  /// in from the right; −1 the other way.
  double _direction = 1;

  /// The slide's position: 0 at the start, 1 at rest — briefly past 1 at the
  /// overshoot.
  double get _progress => _outgoing == null
      ? 1
      : AppMotion.tabSlideCurve.transform(_controller.value);

  void _onIndexChanged(int oldIndex, Widget oldChild) {
    if (oldIndex == index) return;
    final animate =
        !MediaQuery.of(context).disableAnimations &&
        ref.read(settingsProvider).transitionEffectsEnabled;
    if (!animate) {
      // Stopped rather than jumped to the end: reaching "completed" here
      // would setState from inside didUpdateWidget.
      _controller.stop();
      _outgoing = null;
      return;
    }
    _outgoing = oldChild;
    _outgoingIndex = oldIndex;
    _direction = index > oldIndex ? 1 : -1;
    // Held at the start until the frame that first builds the new tab is
    // done. That frame is the expensive one — its lists, charts and queries —
    // and an animation already running through it loses most of its 340ms to
    // the stall, so on a phone the slide looked like an instant swap.
    _controller.value = 0;
    final generation = ++_generation;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _generation && _outgoing != null) {
        _controller.forward(from: 0);
      }
    });
  }

  /// Ignores a pending start once a newer tab change has superseded it.
  int _generation = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Lays its slivers over one another — the same scroll position, the same
/// space — and paints each shifted sideways by its fraction of the width; the
/// viewport clips whatever is off screen. Only the last (incoming) sliver
/// takes touches.
class _SliverSlideStack extends MultiChildRenderObjectWidget {
  const _SliverSlideStack({required this.shifts, required super.children});

  final List<double> shifts;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSliverSlideStack(shifts: shifts);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSliverSlideStack renderObject,
  ) {
    renderObject.shifts = shifts;
  }
}

class _RenderSliverSlideStack extends RenderSliver
    with
        ContainerRenderObjectMixin<
          RenderSliver,
          SliverPhysicalContainerParentData
        > {
  _RenderSliverSlideStack({required List<double> shifts}) : _shifts = shifts;

  List<double> _shifts;
  set shifts(List<double> value) {
    _shifts = value;
    markNeedsPaint();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! SliverPhysicalContainerParentData) {
      child.parentData = SliverPhysicalContainerParentData();
    }
  }

  double _dx(RenderSliver child) {
    var i = 0;
    for (var c = firstChild; c != null; c = childAfter(c), i++) {
      if (identical(c, child)) {
        return i < _shifts.length
            ? _shifts[i] * constraints.crossAxisExtent
            : 0;
      }
    }
    return 0;
  }

  @override
  void performLayout() {
    var scrollExtent = 0.0;
    var paintExtent = 0.0;
    var maxPaintExtent = 0.0;
    var layoutExtent = 0.0;
    var cacheExtent = 0.0;
    var overflow = false;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      child.layout(constraints, parentUsesSize: true);
      final g = child.geometry!;
      if (g.scrollOffsetCorrection != null) {
        geometry = SliverGeometry(
          scrollOffsetCorrection: g.scrollOffsetCorrection,
        );
        return;
      }
      scrollExtent = math.max(scrollExtent, g.scrollExtent);
      paintExtent = math.max(paintExtent, g.paintExtent);
      maxPaintExtent = math.max(maxPaintExtent, g.maxPaintExtent);
      layoutExtent = math.max(layoutExtent, g.layoutExtent);
      cacheExtent = math.max(cacheExtent, g.cacheExtent);
      overflow = overflow || g.hasVisualOverflow;
    }
    geometry = SliverGeometry(
      scrollExtent: scrollExtent,
      paintExtent: paintExtent,
      maxPaintExtent: maxPaintExtent,
      layoutExtent: math.min(layoutExtent, paintExtent),
      cacheExtent: cacheExtent,
      hasVisualOverflow: overflow,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (geometry == null || !geometry!.visible) return;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      if (child.geometry!.visible) {
        context.paintChild(child, offset + Offset(_dx(child), 0));
      }
    }
  }

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) {
    final child = lastChild;
    if (child == null || !child.geometry!.visible) return false;
    return child.hitTest(
      result,
      mainAxisPosition: mainAxisPosition,
      crossAxisPosition: crossAxisPosition - _dx(child),
    );
  }

  @override
  double childMainAxisPosition(RenderSliver child) => 0;

  @override
  double childCrossAxisPosition(RenderSliver child) => _dx(child);

  @override
  double childScrollOffset(RenderObject child) => 0;

  @override
  void applyPaintTransform(RenderSliver child, Matrix4 transform) {
    transform.translateByDouble(_dx(child), 0, 0, 1);
  }
}
