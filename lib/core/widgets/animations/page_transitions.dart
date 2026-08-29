import 'package:flutter/material.dart';

/// Custom page route with fade + slide animation
class AnimatedPageRoute<T> extends PageRoute<T> {
  AnimatedPageRoute({
    required this.builder,
    this.duration = const Duration(milliseconds: 300),
  });

  final WidgetBuilder builder;
  final Duration duration;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return builder(context);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.05, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => duration;
}

/// Custom page route for modal bottom sheets with smooth animation
class AnimatedBottomSheetRoute<T> extends PageRoute<T> {
  AnimatedBottomSheetRoute({
    required this.builder,
    required this.isScrollControlled,
  });

  final WidgetBuilder builder;
  final bool isScrollControlled;

  @override
  Color? get barrierColor => Colors.black54;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  bool get barrierDismissible => true;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return builder(context);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    );
  }

  @override
  bool get maintainState => false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 350);
}

/// Animated dialog route with scale + fade animation
class AnimatedDialogRoute<T> extends PageRoute<T> {
  AnimatedDialogRoute({
    required this.builder,
  });

  final WidgetBuilder builder;

  @override
  Color? get barrierColor => Colors.black54;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  bool get barrierDismissible => true;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return builder(context);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.9, end: 1.0)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }

  @override
  bool get maintainState => false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 250);
}
