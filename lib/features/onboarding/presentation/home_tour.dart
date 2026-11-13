import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/settings_providers.dart';
import '../application/onboarding_gate.dart';
import 'screen_tour.dart';

/// The tour Home plays on its first visit after onboarding — and again after
/// Settings → "Replay the tour".
abstract final class HomeTour {
  static const id = 'home';

  static bool _running = false;

  /// A tour left on screen when its test ended never finishes, which would
  /// keep every later one from starting.
  @visibleForTesting
  static void debugReset() => _running = false;

  static final steps = [
    TourStep(
      target: TourTargets.addButton,
      title: 'Add anything from here',
      body:
          'Tap for an expense, a task, a habit or an event. Hold it to say '
          'it instead.',
    ),
    TourStep(
      target: TourTargets.menuButton,
      title: 'Everything else lives here',
      body:
          'Health, Learn, Goals, Documents, Reports and Settings are in the '
          'side menu.',
    ),
    TourStep(
      target: TourTargets.homeHero,
      title: "What's next, at a glance",
      body: 'Your next workout, event or task shows here as the day goes on.',
    ),
    TourStep(
      target: TourTargets.homeStats,
      title: 'Your day in numbers',
      body: "This month's spending, today's to-dos and your goals.",
    ),
  ];

  /// The one-off tip for people who had already seen the tour before the +
  /// button learned to listen: nothing on a plus sign says "hold me".
  static const holdToSpeakId = 'hold_to_speak';

  static final holdToSpeakTip = [
    TourStep(
      target: TourTargets.addButton,
      title: 'Tap to add. Hold to speak.',
      body:
          'Hold the + button and just say it — "spent 250 on lunch", "call '
          'Mom at 6". Tap it for the full menu.',
    ),
  ];

  /// Starts the tour after this frame if it's due: onboarding is done, this
  /// launch may show tours, and Home's hasn't been seen. Someone who has
  /// seen it, but not the hold-to-speak tip, gets just that tip. Safe to
  /// call on every build.
  static void maybeStart(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsProvider);
    final tourDue = !settings.toursSeen.contains(id);
    final tipDue = !settings.toursSeen.contains(holdToSpeakId);
    // Home stays built in the background while another tab is open; its
    // tickers are off then. Checking also subscribes, so Home rebuilds — and
    // this runs again — the moment it's back on screen.
    final onScreen = TickerMode.valuesOf(context).enabled;
    if (_running ||
        !onScreen ||
        !OnboardingGate.offered ||
        !settings.onboardingCompleted ||
        (!tourDue && !tipDue)) {
      return;
    }
    _running = true;
    // The container outlives this build's ref, which the tour's await could.
    final container = ProviderScope.containerOf(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!context.mounted) return;
        await showScreenTour(context, tourDue ? steps : holdToSpeakTip);
        // The tour's first step says it too, so either way both are seen.
        await container.read(settingsControllerProvider).markTourSeen({
          ...container.read(settingsProvider).toursSeen,
          id,
        }, holdToSpeakId);
      } finally {
        _running = false;
      }
    });
  }
}
