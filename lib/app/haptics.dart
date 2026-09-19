import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/settings/application/settings_providers.dart';

/// App-wide haptics preference, persisted in Settings.
final hapticsEnabledProvider = Provider<bool>(
  (ref) => ref.watch(settingsProvider).hapticsEnabled,
);

/// Resolved haptics, with the user's setting already applied.
///
/// Read this rather than constructing [LifeHaptics] directly — as a provider it
/// works from both sides of Riverpod 3's split ref types: `ref.read(hapticsProvider)`
/// is valid for a widget's `WidgetRef` *and* a controller's `Ref`, which a
/// factory taking one or the other would not be.
final hapticsProvider = Provider<LifeHaptics>((ref) {
  return LifeHaptics(enabled: ref.watch(hapticsEnabledProvider));
});

/// The handoff's haptics map, as named intents rather than raw
/// [HapticFeedback] calls — so call sites read as *why* they buzz, and the
/// platform call stays in one place.
///
/// Obtain via [hapticsProvider] so the user's setting is respected; every method
/// is a no-op when haptics are off.
class LifeHaptics {
  const LifeHaptics({required this.enabled});

  final bool enabled;

  /// Keypad key, chip/category/account/frequency select, segmented switch,
  /// to-do toggle.
  Future<void> selection() => _fire(HapticFeedback.selectionClick);

  /// Opening a form from a tile or link, closing a sheet, habit increment.
  Future<void> light() => _fire(HapticFeedback.lightImpact);

  /// FAB tap (open add menu), recurring switch toggle.
  Future<void> medium() => _fire(HapticFeedback.mediumImpact);

  /// Invalid submit — e.g. tapping the CTA with an empty amount.
  Future<void> heavy() => _fire(HapticFeedback.heavyImpact);

  /// Successful save.
  Future<void> success() => _fire(HapticFeedback.vibrate);

  /// A short two-beat acknowledgement for a successful save or update.
  Future<void> save() async {
    if (!enabled) return;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await const MethodChannel(
          'com.sandeep.lifeos/haptics',
        ).invokeMethod<void>('save');
        return;
      } catch (_) {
        // Older builds and unsupported platforms retain the Flutter fallback.
      }
    }
    await light();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await medium();
  }

  /// Never rethrows. A haptic is cosmetic: a device without a vibrator, a
  /// platform that doesn't implement the channel, or a test with no handler must
  /// not turn into an error on the caller's path — callers fire these without
  /// awaiting, so a throw here would surface as an unhandled async error.
  Future<void> _fire(Future<void> Function() call) async {
    if (!enabled) return;
    try {
      await call();
    } catch (_) {
      // Intentionally swallowed; see above.
    }
  }
}
