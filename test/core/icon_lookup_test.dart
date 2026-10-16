import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/utils/icon_lookup.dart';

void main() {
  test('an icon name is never drawn as text, known or not', () {
    // Sample data's UPI account type; it showed as "wall et".
    expect(isEmojiIcon('wallet'), isFalse);
    expect(resolveIcon('wallet'), resolveIcon('account_balance_wallet'));
    // A name from a newer version falls back to the default icon.
    expect(isEmojiIcon('some_future_icon'), isFalse);
    expect(resolveIcon('some_future_icon'), resolveIcon(defaultCategoryIcon));
    // Real emoji still are emoji.
    expect(isEmojiIcon('🍕'), isTrue);
    expect(isEmojiIcon(''), isFalse);
  });
}
