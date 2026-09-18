import 'package:flutter/material.dart';

/// Recreates the Flutter application from its root.
///
/// This is a full in-app restart: providers, screen state, and the router are
/// rebuilt without force-quitting the native process (which iOS forbids).
class AppRestartBoundary extends StatefulWidget {
  const AppRestartBoundary({super.key, required this.child});

  final Widget child;

  static void restart(BuildContext context) {
    final state = context.findAncestorStateOfType<_AppRestartBoundaryState>();
    state?.restart();
  }

  @override
  State<AppRestartBoundary> createState() => _AppRestartBoundaryState();
}

class _AppRestartBoundaryState extends State<AppRestartBoundary> {
  int _generation = 0;

  void restart() => setState(() => _generation++);

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: ValueKey(_generation), child: widget.child);
}
