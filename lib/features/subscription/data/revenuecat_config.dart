import 'dart:io';

import 'package:flutter/foundation.dart';

/// Which RevenueCat key this build talks to the store with. These are
/// public SDK keys — safe in the app, like Supabase's publishable key. The
/// secret key (`sk_…`) never comes near the app.
///
/// Release builds get the store's own key at build time:
///
///     flutter build appbundle --dart-define=REVENUECAT_ANDROID_KEY=goog_…
///
/// Debug builds fall back to RevenueCat's **Test Store** key, which sells
/// pretend subscriptions with no Google Play involved. That key must never
/// reach a release build — RevenueCat's SDK stops the app on purpose if it
/// does — so it's only ever handed out when [kDebugMode] is true.
abstract final class RevenueCatConfig {
  static const _android = String.fromEnvironment('REVENUECAT_ANDROID_KEY');
  static const _ios = String.fromEnvironment('REVENUECAT_IOS_KEY');
  static const _testStore = String.fromEnvironment(
    'REVENUECAT_TEST_KEY',
    defaultValue: 'test_fVrmhqtRjkksHSyTJMXObGdbwgV',
  );

  /// What RevenueCat calls the thing a subscription unlocks. Must match the
  /// entitlement's identifier in the RevenueCat dashboard and the one the
  /// `revenuecat-webhook` function looks for.
  static const entitlement = 'plus';

  /// Null when this build can't sell anything: a desktop or web build, or
  /// a release build made without a store key.
  static String? get apiKey => keyFor(
    android: !kIsWeb && Platform.isAndroid,
    ios: !kIsWeb && Platform.isIOS,
    debug: kDebugMode,
    androidKey: _android,
    iosKey: _ios,
    testKey: _testStore,
  );

  @visibleForTesting
  static String? keyFor({
    required bool android,
    required bool ios,
    required bool debug,
    required String androidKey,
    required String iosKey,
    required String testKey,
  }) {
    if (!android && !ios) return null;
    final store = android ? androidKey : iosKey;
    // A test key passed as the store's key by mistake is as fatal in a
    // release build as the fallback would be.
    final usable = store.isNotEmpty && (debug || !store.startsWith('test_'));
    if (usable) return store;
    if (debug && testKey.isNotEmpty) return testKey;
    return null;
  }
}
