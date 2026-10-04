import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_lock_service.dart';

final appLockServiceProvider = Provider<AppLockService>(
  (ref) => AppLockService(),
);

/// Whether the phone has a screen lock (biometric or passcode) to unlock with.
final canUseDeviceAuthProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(appLockServiceProvider).canUseDeviceAuth();
});

/// Whether an app PIN has been set. Invalidate after setting or clearing one.
final hasPinProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(appLockServiceProvider).hasPin();
});

/// Session-only "is the lock screen currently up" flag — always starts
/// `true` regardless of whether app lock is even enabled. Whether that
/// actually gates the UI is decided separately at render time by combining
/// this with `settingsProvider.appLockEnabled` (see `app.dart`), so this
/// provider never has to race the settings stream's first emission to know
/// if it should start locked.
class IsLocked extends Notifier<bool> {
  /// Set just before an in-app restart (a colour theme change) by someone who
  /// was already unlocked, so the rebuilt app doesn't ask again. Consumed by
  /// the next [build], so it can't leak into a later launch.
  static bool _unlockedThroughRestart = false;

  static void keepUnlockedThroughRestart() => _unlockedThroughRestart = true;

  @override
  bool build() {
    if (_unlockedThroughRestart) {
      _unlockedThroughRestart = false;
      return false;
    }
    return true;
  }

  void lock() => state = true;

  void unlock() => state = false;
}

final isLockedProvider = NotifierProvider<IsLocked, bool>(IsLocked.new);

/// When coming back to the app should ask to unlock again: only after it has
/// been in the background for [grace] or longer, the way most apps behave. A
/// quick switch away and back, the notification shade, Control Centre or the
/// app switcher never re-lock it; a cold start always starts locked.
class RelockPolicy {
  RelockPolicy({DateTime Function()? now, this.grace = defaultGrace})
    : _now = now ?? DateTime.now;

  static const defaultGrace = Duration(minutes: 1);

  final DateTime Function() _now;
  final Duration grace;
  DateTime? _leftAt;

  /// The app went to the background. Only the first call counts, so a
  /// `hidden` followed by `paused` doesn't restart the clock.
  void left() => _leftAt ??= _now();

  /// The app is back in front. Returns whether it was away long enough that
  /// it should lock.
  bool returned() {
    final leftAt = _leftAt;
    _leftAt = null;
    return leftAt != null && _now().difference(leftAt) >= grace;
  }
}

final relockPolicyProvider = Provider<RelockPolicy>((ref) => RelockPolicy());
