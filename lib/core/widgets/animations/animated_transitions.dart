import 'dart:math' show sin, pi;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Fade-in entrance animation (200ms)
Widget fadeInAnimation(Widget child) {
  return child.animate().fadeIn(duration: 200.ms);
}

/// Slide-in from the right entrance animation (200ms)
Widget slideInRightAnimation(Widget child) {
  return child.animate().slideX(begin: 0.03, end: 0, duration: 200.ms);
}

/// Slide-in from below entrance animation (220ms)
Widget slideInBottomAnimation(Widget child) {
  return child.animate().fadeIn(duration: 220.ms).slideY(begin: 0.08, end: 0, duration: 220.ms);
}

/// Scale-pop entrance animation (150ms)
Widget scalePopAnimation(Widget child) {
  return child.animate().scale(
        begin: const Offset(0.92, 0.92),
        end: const Offset(1.0, 1.0),
        duration: 150.ms,
        curve: Curves.easeOutBack,
      );
}

/// Staggered list item animation (used for item builders)
Widget listItemAnimation(Widget child, int index) {
  return child
      .animate(delay: (index * 30).ms)
      .fadeIn(duration: 200.ms)
      .slideY(begin: 0.05, end: 0, duration: 200.ms, curve: Curves.easeOutQuad);
}

/// Item removal animation (cleanup animation before removal)
Animation<double> itemRemovalAnimation(AnimationController controller) {
  return Tween<double>(begin: 1.0, end: 0.0).animate(
    CurvedAnimation(parent: controller, curve: Curves.easeInQuad),
  );
}

/// Checkmark drawing animation for completion
Widget animatedCheckmark({
  required bool completed,
  required Color color,
  double size = 24,
}) {
  return AnimatedCrossFade(
    firstChild: Icon(Icons.check_rounded, size: size, color: color),
    secondChild: Icon(Icons.circle_outlined, size: size, color: color),
    crossFadeState: completed ? CrossFadeState.showFirst : CrossFadeState.showSecond,
    duration: 200.ms,
  );
}

/// Rotate animation for refresh/loading icons
class AnimatedRotatingIcon extends StatefulWidget {
  const AnimatedRotatingIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 24,
    this.isAnimating = true,
  });

  final IconData icon;
  final Color color;
  final double size;
  final bool isAnimating;

  @override
  State<AnimatedRotatingIcon> createState() => _AnimatedRotatingIconState();
}

class _AnimatedRotatingIconState extends State<AnimatedRotatingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    if (widget.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedRotatingIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isAnimating && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(widget.icon, size: widget.size, color: widget.color),
    );
  }
}

/// Bounce animation for interactive buttons
class AnimatedPressScale extends StatefulWidget {
  const AnimatedPressScale({
    super.key,
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<AnimatedPressScale> createState() => _AnimatedPressScaleState();
}

class _AnimatedPressScaleState extends State<AnimatedPressScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Shake animation for errors
class ShakeAnimation extends StatefulWidget {
  const ShakeAnimation({
    super.key,
    required this.child,
    this.isShaking = false,
  });

  final Widget child;
  final bool isShaking;

  @override
  State<ShakeAnimation> createState() => _ShakeAnimationState();
}

class _ShakeAnimationState extends State<ShakeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(ShakeAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isShaking) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final offset = sin(_controller.value * pi * 4) * 4.0;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
    );
  }
}
