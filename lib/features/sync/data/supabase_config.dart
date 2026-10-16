/// Where sync's server is. The key is passed at build time and never
/// committed:
///
///   `flutter run --dart-define=SUPABASE_PUBLISHABLE_KEY=...`
///
/// or put both values in a gitignored `supabase.json` and pass
/// `--dart-define-from-file=supabase.json` (see `supabase.example.json`).
/// Without a key the app is exactly the local-only app it always was.
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://hxqvkhtulmmocfwpzeiv.supabase.co',
  );

  /// The project's publishable key (`sb_publishable_…`, or the legacy
  /// `anon` key) — safe in an app, since row-level security decides what it
  /// can reach. Never the secret or service-role key.
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_DqILynDEuaGXnSQaUjZZfQ_KRFYoaet'
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  /// Sign in with Apple needs an Apple Developer membership and its own
  /// setup (supabase/README.md). Until then the button is hidden rather than
  /// offered and failing. Note: once the iOS app offers Google, App Store
  /// review requires Apple too.
  static const appleSignIn = false;

  /// Where email confirmation and Google/Apple sign-in come back to. Must be
  /// listed under Authentication → URL Configuration → Redirect URLs.
  static const authRedirect = 'lifeos://auth-callback';
}
