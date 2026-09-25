import 'package:flutter/material.dart';

/// The native splash plate, redrawn in Flutter.
///
/// These must stay identical to `flutter_native_splash.color` and
/// `color_dark` in pubspec.yaml — the whole point is that the handoff from
/// the OS splash to the first Flutter frame is invisible. A conformance test
/// reads pubspec and fails if they drift apart.
const kSplashPlateLight = Color(0xFF6750E7);
const kSplashPlateDark = Color(0xFF14121F);

/// The mark's logical size. `flutter_native_splash` generated the Android
/// buckets from the 1024px source, and mdpi (1x) is 256px — so the OS draws
/// it at 256pt and anything else here would visibly jump.
const kSplashMarkSize = 256.0;

/// Shown instead of the app while the stored settings are still being read.
///
/// The colour theme lives in the database, so the first frames after launch
/// don't know it yet. Painting the real UI then would show it in the default
/// theme and repaint a moment later in the user's — the flash this exists to
/// remove. Continuing the splash instead means nothing wrong is ever drawn.
class BootPlate extends StatelessWidget {
  const BootPlate({super.key});

  @override
  Widget build(BuildContext context) {
    // This sits above the app's own MediaQuery, so there usually isn't one —
    // but read through the tree rather than PlatformDispatcher.instance, so
    // an enclosing override (and the test harness) is still honoured.
    final brightness =
        MediaQuery.maybePlatformBrightnessOf(context) ??
        View.of(context).platformDispatcher.platformBrightness;

    return ColoredBox(
      color: brightness == Brightness.dark
          ? kSplashPlateDark
          : kSplashPlateLight,
      child: const Center(
        child: Image(
          image: AssetImage('assets/icon/splash_logo.png'),
          width: kSplashMarkSize,
          height: kSplashMarkSize,
          // The mark carries nothing the next screen doesn't, so it stays
          // unlabelled rather than being announced on every launch.
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
