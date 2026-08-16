import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_lock_service.dart';

final appLockServiceProvider = Provider<AppLockService>((ref) => AppLockService());

final canUseBiometricsProvider = FutureProvider<bool>((ref) {
  return ref.watch(appLockServiceProvider).canUseBiometrics();
});

/// Session-only "is the lock screen currently up" flag — always starts
/// `true` regardless of whether app lock is even enabled. Whether that
/// actually gates the UI is decided separately at render time by combining
/// this with `settingsProvider.appLockEnabled` (see `app.dart`), so this
/// provider never has to race the settings stream's first emission to know
/// if it should start locked.
class IsLocked extends Notifier<bool> {
  @override
  bool build() => true;

  void lock() => state = true;

  void unlock() => state = false;
}

final isLockedProvider = NotifierProvider<IsLocked, bool>(IsLocked.new);
