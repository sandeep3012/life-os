import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Animated skeleton loader (shimmer-like fade in/out)
class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 0.7).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

/// Animated fade-in for content that's loading
class AnimatedContentLoader extends StatelessWidget {
  const AnimatedContentLoader({
    super.key,
    required this.isLoading,
    required this.child,
    this.placeholder,
  });

  final bool isLoading;
  final Widget child;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      firstChild: placeholder ??
          Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
      secondChild: child,
      crossFadeState: isLoading ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      duration: const Duration(milliseconds: 300),
    );
  }
}

/// Animated list loader with skeleton items
class SkeletonListLoader extends StatelessWidget {
  const SkeletonListLoader({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 60,
    this.spacing = 8,
  });

  final int itemCount;
  final double itemHeight;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: itemCount,
      separatorBuilder: (_, _) => SizedBox(height: spacing),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLoader(height: itemHeight * 0.4),
              SizedBox(height: spacing),
              SkeletonLoader(width: MediaQuery.of(context).size.width * 0.7),
            ],
          ),
        );
      },
    );
  }
}

/// Animated progress indicator with label
class AnimatedProgressIndicator extends StatelessWidget {
  const AnimatedProgressIndicator({
    super.key,
    this.value,
    this.label,
  });

  final double? value;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(value: value),
        if (label != null) ...[
          const SizedBox(height: 12),
          Text(label!).animate().fadeIn(duration: 200.ms),
        ],
      ],
    );
  }
}

/// Pulse animation for loading states
class PulseAnimation extends StatefulWidget {
  const PulseAnimation({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
      ),
      child: widget.child,
    );
  }
}
