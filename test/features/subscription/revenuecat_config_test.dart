import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/subscription/data/revenuecat_config.dart';

void main() {
  String? key({
    bool android = true,
    bool ios = false,
    required bool debug,
    String androidKey = '',
    String iosKey = '',
    String testKey = 'test_abc',
  }) => RevenueCatConfig.keyFor(
    android: android,
    ios: ios,
    debug: debug,
    androidKey: androidKey,
    iosKey: iosKey,
    testKey: testKey,
  );

  test('a debug build with no store key uses the Test Store', () {
    expect(key(debug: true), 'test_abc');
  });

  test("a release build never gets the Test Store key: RevenueCat's SDK "
      'stops the app if it does', () {
    expect(key(debug: false), isNull);
    expect(key(debug: false, androidKey: 'test_abc'), isNull);
  });

  test("the store's own key is used when the build has one", () {
    expect(key(debug: false, androidKey: 'goog_live'), 'goog_live');
    expect(key(debug: true, androidKey: 'goog_live'), 'goog_live');
    expect(
      key(android: false, ios: true, debug: false, iosKey: 'appl_live'),
      'appl_live',
    );
  });

  test('desktop and web builds sell nothing', () {
    expect(key(android: false, debug: true, androidKey: 'goog_live'), isNull);
  });
}
