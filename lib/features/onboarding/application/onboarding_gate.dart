import 'package:flutter/widgets.dart';

import '../../../app/splash_gate.dart';

/// Whether this launch may show the welcome screens and screen tours.
///
/// Only a real launch from `main` does — the same rule the launch animation
/// follows. Widget tests pump the app on a blank database, which is exactly
/// what a first launch looks like; without this every one of them would open
/// on the welcome screens instead of the screen it is testing.
abstract final class OnboardingGate {
  @visibleForTesting
  static bool debugOffer = false;

  static bool get offered => SplashGate.coldStart || debugOffer;
}

/// The controls a screen tour points at, shared because they live in
/// different widgets — the + button belongs to the app shell, not to Home.
abstract final class TourTargets {
  static final addButton = GlobalKey(debugLabel: 'tour: add button');
  static final menuButton = GlobalKey(debugLabel: 'tour: menu button');
  static final homeHero = GlobalKey(debugLabel: 'tour: home hero');
  static final homeStats = GlobalKey(debugLabel: 'tour: home stats');
}
