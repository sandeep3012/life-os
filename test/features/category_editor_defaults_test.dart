import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/utils/category_color.dart';
import 'package:life_manager/core/utils/icon_lookup.dart';
import 'package:life_manager/features/finance/presentation/screens/category_management_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The category editor is shared by every creation point (finance, planner,
/// habits, budgets, the entry sheet), so its defaults are worth pinning: a new
/// category should start green with the default tag glyph, not on whichever
/// swatch or icon happens to lead its list.
void main() {
  const greenHex = '#2E9E63';
  const redHex = '#E0475A';

  testWidgets('a new category defaults to green and the tag glyph', (
    tester,
  ) async {
    CategoryEditorResult? saved;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  saved = await showCategoryEditorSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Groceries');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Add category'));
    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();

    // The sheet's result is exactly what every caller persists.
    expect(saved, isNotNull);
    expect(saved!.colorHex, greenHex);
    expect(saved!.colorHex, isNot(redHex));
    expect(saved!.icon, defaultCategoryIcon);
    expect(resolveIcon(saved!.icon), LucideIcons.tag);
  });

  testWidgets('"No color" saves a blank colour instead of forcing a swatch', (
    tester,
  ) async {
    CategoryEditorResult? saved;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  saved = await showCategoryEditorSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Misc');
    await tester.pumpAndSettle();

    final none = find.bySemanticsLabel('No color');
    await tester.ensureVisible(none);
    await tester.tap(none);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Add category'));
    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.colorHex, noCategoryColorHex);
    expect(saved!.colorHex, isEmpty);
  });

  testWidgets('an emoji icon is laid out so it centres in its circle', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: IconOrEmoji(value: '🍽️', size: 18)),
      ),
    );

    // Line height 1 with even leading: the default line box is lopsided and
    // leaves emoji sitting low inside a centred circle.
    final style = tester.widget<Text>(find.text('🍽️')).style!;
    expect(style.height, 1);
    expect(style.leadingDistribution, TextLeadingDistribution.even);
    expect(style.fontSize, 18);
  });

  testWidgets('Apple platforms nudge the emoji up and right, others do not', (
    tester,
  ) async {
    Offset shift() {
      final t = tester
          .widget<Transform>(
            find.descendant(
              of: find.byType(EmojiGlyph),
              matching: find.byType(Transform),
            ),
          )
          .transform
          .getTranslation();
      return Offset(t.x, t.y);
    }

    Future<void> pump() => tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EmojiGlyph('🍽️', size: 20))),
    );

    // The pixel offset is measured on an iPhone: ~0.6pt left and ~1pt low of
    // a 20pt glyph. Pin the direction and scale, not the pixels.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await pump();
    expect(shift().dx, greaterThan(0));
    expect(shift().dy, lessThan(0));
    expect(shift().dy.abs(), lessThan(2));

    // Unmount first: an identical const tree would otherwise not rebuild.
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await pump();
    expect(shift().dx, 0);
    expect(shift().dy, 0);

    debugDefaultTargetPlatformOverride = null;
  });

  test('a blank or unknown icon falls back to the default tag glyph', () {
    expect(resolveIcon(null), LucideIcons.tag);
    expect(resolveIcon(''), LucideIcons.tag);
    expect(resolveIcon('an_icon_from_a_future_version'), LucideIcons.tag);
    expect(resolveIcon(defaultCategoryIcon), LucideIcons.tag);

    // Blank is "no icon", not an emoji — otherwise it renders as empty text.
    expect(isEmojiIcon(''), isFalse);
    expect(isEmojiIcon(null), isFalse);
    expect(isEmojiIcon('label'), isFalse);
    expect(isEmojiIcon('🍽️'), isTrue);
  });

  test('every picker choice is unique and resolves to itself', () {
    expect(pickableIcons.toSet(), hasLength(pickableIcons.length));
    expect(pickableEmojis.toSet(), hasLength(pickableEmojis.length));

    // A pickable name missing from the lookup would save fine and then
    // render as the fallback tag — and be misread as an emoji.
    for (final name in pickableIcons) {
      expect(isEmojiIcon(name), isFalse, reason: name);
      if (name != defaultCategoryIcon) {
        expect(resolveIcon(name), isNot(LucideIcons.tag), reason: name);
      }
    }
    for (final emoji in pickableEmojis) {
      expect(isEmojiIcon(emoji), isTrue, reason: emoji);
    }
  });
}
