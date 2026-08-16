import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// PIN storage and biometric authentication for the app lock. The PIN is
/// stored directly in `flutter_secure_storage` (Keychain on iOS, a
/// Keystore-backed encrypted store on Android) rather than as a separate
/// hash — secure storage is already encrypted at rest, and this app's lock
/// is deterring casual physical access, not acting as a banking-grade
/// credential store, so a second layer of hashing wouldn't add a meaningful
/// threat-model benefit.
class AppLockService {
  AppLockService({FlutterSecureStorage? storage, LocalAuthentication? localAuth})
    : _storage = storage ?? const FlutterSecureStorage(),
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

  /// Best-effort: a missing platform channel or unsupported device must
  /// never crash the settings screen, so failures here just report "no
  /// biometrics available" instead of throwing.
  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock LifeOS',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}
