import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Wrapper for list items that provides staggered entrance animation
class AnimatedListItem extends StatelessWidget {
  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.staggerDelay = 30,
  });

  final Widget child;
  final int index;
  final int staggerDelay;

  @override
  Widget build(BuildContext context) {
    return child
        .animate(delay: (index * staggerDelay).ms)
        .fadeIn(duration: 200.ms)
        .slideY(begin: 0.05, end: 0, duration: 200.ms, curve: Curves.easeOutQuad);
  }
}

/// Animated dismissible item with coordinated animations
class AnimatedDismissibleItem<T> extends StatefulWidget {
  const AnimatedDismissibleItem({
    required Key super.key,
    required this.child,
    required this.onDismissed,
    this.dismissDirection = DismissDirection.endToStart,
    this.background,
    this.secondaryBackground,
  });

  final Widget child;
  final Function(DismissDirection) onDismissed;
  final DismissDirection dismissDirection;
  final Widget? background;
  final Widget? secondaryBackground;

  @override
  State<AnimatedDismissibleItem<T>> createState() =>
      _AnimatedDismissibleItemState<T>();
}

class _AnimatedDismissibleItemState<T> extends State<AnimatedDismissibleItem<T>>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _handleDismissed(DismissDirection direction) async {
    await _slideController.forward();
    widget.onDismissed(direction);
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-1.0, 0),
      ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeInQuad)),
      child: FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: 0.0)
            .animate(_slideController),
        child: Dismissible(
          key: widget.key!,
          direction: widget.dismissDirection,
          onDismissed: _handleDismissed,
          background: widget.background,
          secondaryBackground: widget.secondaryBackground,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Animated item for list updates (e.g., when item content changes)
class AnimatedUpdateItem extends StatefulWidget {
  const AnimatedUpdateItem({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
  });

  final Widget child;
  final Duration duration;

  @override
  State<AnimatedUpdateItem> createState() => _AnimatedUpdateItemState();
}

class _AnimatedUpdateItemState extends State<AnimatedUpdateItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedUpdateItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOutQuad),
      ),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.98, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Animated list insert animation (when item is added to list)
class AnimatedListInsert extends StatefulWidget {
  const AnimatedListInsert({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 350),
  });

  final Widget child;
  final Duration duration;

  @override
  State<AnimatedListInsert> createState() => _AnimatedListInsertState();
}

class _AnimatedListInsertState extends State<AnimatedListInsert>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.05),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic)),
      child: FadeTransition(
        opacity: _controller,
        child: widget.child,
      ),
    );
  }
}
