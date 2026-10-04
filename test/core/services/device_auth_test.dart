import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/services/app_lock_service.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';

/// Stands in for the OS: what the phone supports and how a prompt ends.
class _FakeLocalAuth extends LocalAuthentication {
  bool supported = true;
  bool supportCheckThrows = false;
  bool result = true;
  String? failWithCode;
  AuthenticationOptions? lastOptions;
  String? lastReason;
  Future<void>? hold; // keeps the prompt "on screen" until completed

  @override
  Future<bool> isDeviceSupported() async {
    if (supportCheckThrows) throw PlatformException(code: 'boom');
    return supported;
  }

  @override
  Future<bool> authenticate({
    required String localizedReason,
    // Wider than the real parameter type (Iterable<AuthMessages>), which lives in
    // a transitive package; a wider type is a legal override.
    Iterable<dynamic> authMessages = const <dynamic>[],
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    lastOptions = options;
    lastReason = localizedReason;
    await hold;
    if (failWithCode != null) throw PlatformException(code: failWithCode!);
    return result;
  }
}

void main() {
  late _FakeLocalAuth os;
  late AppLockService service;

  setUp(() {
    os = _FakeLocalAuth();
    service = AppLockService(localAuth: os);
  });

  group('canUseDeviceAuth', () {
    test('is true when the phone has a screen lock', () async {
      os.supported = true;
      expect(await service.canUseDeviceAuth(), isTrue);
    });

    test('is false when it has none', () async {
      os.supported = false;
      expect(await service.canUseDeviceAuth(), isFalse);
    });

    test('is false, not a crash, when the platform check itself fails', () async {
      os.supportCheckThrows = true;
      expect(await service.canUseDeviceAuth(), isFalse);
    });
  });

  group('authenticateWithDevice', () {
    test('success', () async {
      expect(await service.authenticateWithDevice(), DeviceAuthResult.success);
    });

    test("accepts the phone's passcode, not only a biometric", () async {
      // biometricOnly: true is what used to leave a failed Face ID with no way
      // in except the app PIN.
      await service.authenticateWithDevice();
      expect(os.lastOptions!.biometricOnly, isFalse);
    });

    test('passes the reason the OS shows to the person', () async {
      await service.authenticateWithDevice(reason: 'Confirm to turn off app lock');
      expect(os.lastReason, 'Confirm to turn off app lock');
    });

    test('backing out or not matching is "cancelled"', () async {
      os.result = false;
      expect(await service.authenticateWithDevice(), DeviceAuthResult.cancelled);
    });

    for (final code in [
      auth_error.notAvailable,
      auth_error.notEnrolled,
      auth_error.passcodeNotSet,
      auth_error.otherOperatingSystem,
    ]) {
      test('$code means the phone has nothing to ask', () async {
        os.failWithCode = code;
        expect(await service.authenticateWithDevice(), DeviceAuthResult.unavailable);
      });
    }

    for (final code in [auth_error.lockedOut, auth_error.permanentlyLockedOut]) {
      test('$code means too many attempts', () async {
        os.failWithCode = code;
        expect(await service.authenticateWithDevice(), DeviceAuthResult.lockedOut);
      });
    }

    test('anything else is a plain error', () async {
      os.failWithCode = 'SomethingElse';
      expect(await service.authenticateWithDevice(), DeviceAuthResult.error);
    });
  });

  group('isAuthenticating (the guard against re-locking mid-prompt)', () {
    test('is false before any prompt', () {
      expect(service.isAuthenticating, isFalse);
    });

    test('is true while the OS dialog is up', () async {
      final prompt = Completer<void>();
      os.hold = prompt.future;

      final pending = service.authenticateWithDevice();
      await Future<void>.delayed(Duration.zero);
      expect(service.isAuthenticating, isTrue);

      prompt.complete();
      await pending;
    });

    test('stays true for a moment after, to cover the late lifecycle event', () async {
      await service.authenticateWithDevice();
      expect(service.isAuthenticating, isTrue);
    });

    test('and then clears', () async {
      await service.authenticateWithDevice();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(service.isAuthenticating, isFalse);
    });

    test('clears even when the prompt failed', () async {
      os.failWithCode = auth_error.lockedOut;
      await service.authenticateWithDevice();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(service.isAuthenticating, isFalse);
    });
  });
}
