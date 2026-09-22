import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
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
}
