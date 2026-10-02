import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/utils/category_color.dart';

/// "No color" is stored as a blank hex, and a blank string throws if anything
/// `int.parse`s it — so every renderer reads colours through this helper.
void main() {
  test('parses a stored #RRGGBB hex colour', () {
    expect(categoryColor('#2E9E63'), const Color(0xFF2E9E63));
    expect(categoryColor('#E0475A'), const Color(0xFFE0475A));
  });

  test('"No color" is blank and yields null instead of throwing', () {
    expect(noCategoryColorHex, isEmpty);
    expect(categoryColor(noCategoryColorHex), isNull);
    expect(categoryColor(''), isNull);
    expect(categoryColor(null), isNull);
  });

  test('a value that is not a hex colour yields null', () {
    expect(categoryColor('not-a-colour'), isNull);
    expect(categoryColor('#ZZZZZZ'), isNull);
    // Stored colours always carry the '#', as every swatch and demo row does.
    expect(categoryColor('2E9E63'), isNull);
  });
}
