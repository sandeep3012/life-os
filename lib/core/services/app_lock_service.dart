import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';

/// PIN storage and the phone's own authentication (biometrics or device
/// passcode) for the app lock. The PIN is
/// stored directly in `flutter_secure_storage` (Keychain on iOS, a
/// Keystore-backed encrypted store on Android) rather than as a separate
/// hash — secure storage is already encrypted at rest, and this app's lock
/// is deterring casual physical access, not acting as a banking-grade
/// credential store, so a second layer of hashing wouldn't add a meaningful
/// threat-model benefit.
class AppLockService {
  AppLockService({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _localAuth = localAuth ?? LocalAuthentication();

  static const _pinKey = 'app_lock_pin';

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  Future<void> setPin(String pin) => _storage.write(key: _pinKey, value: pin);

  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _pinKey);
    return stored != null && stored == pin;
  }

  Future<bool> hasPin() async {
    final stored = await _storage.read(key: _pinKey);
    return stored != null;
  }

  Future<void> clearPin() => _storage.delete(key: _pinKey);

  /// Whether the phone has a screen lock the app can ask the OS to check:
  /// Face ID, Touch ID, a fingerprint, or the phone's own passcode, PIN or
  /// pattern. Best-effort — a missing platform channel or an unsupported device
  /// must never crash the settings screen, so a failure just reports "no".
  Future<bool> canUseDeviceAuth() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// True while the OS's own authentication dialog is up, and for a moment
  /// after. That dialog takes focus from the app — iOS reports `inactive`,
  /// Android `paused` — and the lifecycle observer re-locks on both, so without
  /// this, unlocking would lock the app again the instant it succeeded.
  bool get isAuthenticating =>
      _authenticating || DateTime.now().isBefore(_graceUntil);

  bool _authenticating = false;
  DateTime _graceUntil = DateTime.fromMillisecondsSinceEpoch(0);

  /// Asks the OS to confirm it's the phone's owner: biometrics first, and the
  /// phone's passcode, PIN or pattern when the biometric isn't available or
  /// fails. The app never sees the passcode, only the answer.
  Future<DeviceAuthResult> authenticateWithDevice({
    String reason = 'Unlock LifeOS',
  }) async {
    _authenticating = true;
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          // false is what lets the phone's passcode / PIN / pattern in; with
          // true only a biometric is accepted and nothing else can unlock.
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      return ok ? DeviceAuthResult.success : DeviceAuthResult.cancelled;
    } on PlatformException catch (e) {
      return switch (e.code) {
        auth_error.notAvailable ||
        auth_error.notEnrolled ||
        auth_error.passcodeNotSet ||
        auth_error.otherOperatingSystem => DeviceAuthResult.unavailable,
        auth_error.lockedOut ||
        auth_error.permanentlyLockedOut => DeviceAuthResult.lockedOut,
        _ => DeviceAuthResult.error,
      };
    } catch (_) {
      return DeviceAuthResult.error;
    } finally {
      _authenticating = false;
      _graceUntil = DateTime.now().add(const Duration(milliseconds: 800));
    }
  }
}

/// How an attempt to unlock with the phone's own lock ended.
enum DeviceAuthResult {
  /// The OS confirmed it.
  success,

  /// The person backed out, or it didn't match.
  cancelled,

  /// The phone has no screen lock set (or no biometrics and no passcode), so
  /// there is nothing to ask.
  unavailable,

  /// Too many failed attempts; the OS has paused further tries.
  lockedOut,

  /// Something else went wrong.
  error,
}
