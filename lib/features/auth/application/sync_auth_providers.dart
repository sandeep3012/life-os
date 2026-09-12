import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What a sign-in / sign-up attempt produced.
sealed class SyncAuthOutcome {
  const SyncAuthOutcome();
}

/// The backend isn't wired up in this build.
///
/// Sync is a paid, opt-in feature: free use stays entirely local with no account,
/// so nothing on the offline path depends on this. Reaching a real result needs
/// three things this build doesn't have — the `supabase_flutter` dependency, a
/// project URL plus anon key, and the OAuth deep-link setup on both platforms
/// (an iOS URL scheme and Apple Sign-In capability, an Android intent filter).
///
/// The auth screens surface this verbatim rather than pretending to sign in:
/// a form that appears to succeed and silently does nothing is worse than one
/// that says it isn't connected.
class SyncAuthNotConfigured extends SyncAuthOutcome {
  const SyncAuthNotConfigured();

  static const message =
      'Sync isn\'t connected yet. Your data is saved on this device.';
}

class SyncAuthFailure extends SyncAuthOutcome {
  const SyncAuthFailure(this.message);

  final String message;
}

class SyncAuthSuccess extends SyncAuthOutcome {
  const SyncAuthSuccess();
}

/// The single seam the auth screens talk to.
///
/// Swap this implementation for a Supabase-backed one when the dependency and
/// credentials land; the screens need no changes, because they only ever branch on
/// [SyncAuthOutcome].
class SyncAuthController {
  const SyncAuthController();

  Future<SyncAuthOutcome> signIn({
    required String email,
    required String password,
  }) async {
    return const SyncAuthNotConfigured();
  }

  Future<SyncAuthOutcome> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    return const SyncAuthNotConfigured();
  }

  Future<SyncAuthOutcome> signInWithProvider(String provider) async {
    return const SyncAuthNotConfigured();
  }
}

final syncAuthControllerProvider = Provider<SyncAuthController>((ref) {
  return const SyncAuthController();
});
