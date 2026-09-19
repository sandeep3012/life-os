import 'package:flutter/material.dart';

/// Navigator keys for the stateful shell branches. Keeping modal sheets on a
/// branch navigator leaves the shell scaffold (including the floating nav)
/// visible underneath, matching sheets opened from the branch screen itself.
final branchNavigatorKeys = List<GlobalKey<NavigatorState>>.generate(
  5,
  (_) => GlobalKey<NavigatorState>(),
);
