import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../sync/application/sync_providers.dart';
import '../../sync/data/supabase_config.dart';

/// What a sign-in / sign-up attempt produced.
sealed class SyncAuthOutcome {
  const SyncAuthOutcome();
}

/// The backend isn't wired up in this build — it has no Supabase key.
///
/// Sync is a paid, opt-in feature: free use stays entirely local with no
/// account, so nothing on the offline path depends on this. The auth screens
/// surface this verbatim rather than pretending to sign in: a form that
/// appears to succeed and silently does nothing is worse than one that says
/// it isn't connected.
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

/// Done for now, but finished outside the app: a confirmation or reset
/// email was sent, or the Google/Apple page opened in the browser.
class SyncAuthContinueElsewhere extends SyncAuthOutcome {
  const SyncAuthContinueElsewhere(this.message);

  final String message;
}

/// The single seam the auth screens talk to. The screens only ever branch
/// on [SyncAuthOutcome], so they're the same whether or not this build can
/// reach Supabase.
class SyncAuthController {
  const SyncAuthController(this._client);

  final SupabaseClient? _client;

  Future<SyncAuthOutcome> signIn({
    required String email,
    required String password,
  }) => _attempt((auth) async {
    if (email.isEmpty || password.isEmpty) {
      return const SyncAuthFailure('Enter your email and password.');
    }
    if (!_looksLikeEmail(email)) {
      return const SyncAuthFailure('That email address doesn\'t look right.');
    }
    await auth.signInWithPassword(email: email, password: password);
    return const SyncAuthSuccess();
  });

  Future<SyncAuthOutcome> signUp({
    required String name,
    required String email,
    required String password,
  }) => _attempt((auth) async {
    if (email.isEmpty || password.length < 8) {
      return const SyncAuthFailure(
        'Enter your email and a password of at least 8 characters.',
      );
    }
    if (!_looksLikeEmail(email)) {
      return const SyncAuthFailure('That email address doesn\'t look right.');
    }
    final response = await auth.signUp(
      email: email,
      password: password,
      data: {if (name.isNotEmpty) 'name': name},
      emailRedirectTo: SupabaseConfig.authRedirect,
    );
    // With email confirmation on, there's no session until the link in the
    // email is opened.
    if (response.session == null) {
      return SyncAuthContinueElsewhere(
        'Check $email for a link to confirm your account.',
      );
    }
    return const SyncAuthSuccess();
  });

  /// [provider] is `google` or `apple`. Opens the provider's page in the
  /// browser; the app picks the session up when it's sent back to
  /// [SupabaseConfig.authRedirect].
  Future<SyncAuthOutcome> signInWithProvider(String provider) =>
      _attempt((auth) async {
        final opened = await auth.signInWithOAuth(
          provider == 'apple' ? OAuthProvider.apple : OAuthProvider.google,
          redirectTo: SupabaseConfig.authRedirect,
          authScreenLaunchMode: LaunchMode.externalApplication,
        );
        return opened
            ? const SyncAuthContinueElsewhere(
                'Finish signing in in your browser.',
              )
            : const SyncAuthFailure("Couldn't open the sign-in page.");
      });

  Future<SyncAuthOutcome> resetPassword(String email) =>
      _attempt((auth) async {
        if (email.isEmpty) {
          return const SyncAuthFailure('Enter your email first.');
        }
        await auth.resetPasswordForEmail(
          email,
          redirectTo: SupabaseConfig.authRedirect,
        );
        return SyncAuthContinueElsewhere(
          'Check $email for a link to choose a new password.',
        );
      });

  /// After a reset link: sets the new password on the session it opened.
  Future<SyncAuthOutcome> updatePassword(String password) =>
      _attempt((auth) async {
        if (password.length < 8) {
          return const SyncAuthFailure(
            'Use a password of at least 8 characters.',
          );
        }
        await auth.updateUser(UserAttributes(password: password));
        return const SyncAuthSuccess();
      });

  Future<SyncAuthOutcome> _attempt(
    Future<SyncAuthOutcome> Function(GoTrueClient auth) action,
  ) async {
    final client = _client;
    if (client == null) return const SyncAuthNotConfigured();
    try {
      return await action(client.auth);
    } on AuthRetryableFetchException {
      // The request never reached the server — offline, or no network.
      return const SyncAuthFailure(_offline);
    } on AuthException catch (e) {
      return SyncAuthFailure(e.message);
    } on Object {
      return const SyncAuthFailure(
        _offline,
      );
    }
  }

  static const _offline =
      "Couldn't reach the server. Check your connection and try again.";

  static bool _looksLikeEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
}

final syncAuthControllerProvider = Provider<SyncAuthController>((ref) {
  return SyncAuthController(ref.watch(supabaseClientProvider));
});
