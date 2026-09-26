import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'launch_timeline.dart';

/// Holds the native launch screen until the first screen is ready to show.
///
/// Flutter's first frame is deferred, so the OS splash stays up while the app
/// reads its settings and the landing screen fetches its data. Without this
/// the launch was: native splash, a Flutter-drawn copy of it (whose logo
/// decodes a frame late, so it visibly blinked), then a near-empty home screen
/// until its queries answered.
abstract final class SplashGate {
  /// Release no matter what after this long. Held longer than a few seconds,
  /// a launch looks hung, and a screen still filling in beats a frozen splash.
  static const maxHold = Duration(seconds: 5);

  static bool _held = false;
  static Timer? _ceiling;

  static void hold(WidgetsBinding binding) {
    if (_held) return;
    _held = true;
    FlutterNativeSplash.preserve(widgetsBinding: binding);
    _ceiling = Timer(maxHold, () => release(reason: 'ceiling'));
    binding.waitUntilFirstFrameRasterized.then(
      (_) => LaunchTimeline.mark('first frame on screen'),
    );
  }

  /// Idempotent, and a no-op if [hold] never ran (tests, in-app restarts).
  static void release({String reason = 'ready'}) {
    if (!_held) return;
    LaunchTimeline.mark('splash released ($reason)');
    _held = false;
    _ceiling?.cancel();
    _ceiling = null;
    FlutterNativeSplash.remove();
  }
}
