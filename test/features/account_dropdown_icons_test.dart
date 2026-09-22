import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/utils/icon_lookup.dart';
import 'package:life_manager/features/finance/presentation/widgets/account_card.dart'
    show accountIconValueFor;
import 'package:life_manager/features/finance/presentation/widgets/account_option_row.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Account pickers used to repeat one static bank glyph on the field, which
/// said nothing about the account you were choosing. Each row now carries its
/// own account-type icon, falling back to the bank glyph only when the type
/// has none.
void main() {
  final epoch = DateTime(2026);

  test('an account resolves its type icon, or the bank glyph', () {
    final types = [
      AccountType(id: 't1', name: 'Savings', icon: 'savings', createdAt: epoch),
      AccountType(id: 't2', name: 'Card', icon: '💳', createdAt: epoch),
    ];

    expect(accountIconValueFor('Savings', types), 'savings');
    expect(
      resolveIcon(accountIconValueFor('Savings', types)),
      LucideIcons.piggyBank,
    );

    // Emoji icons survive the lookup untouched.
    expect(accountIconValueFor('Card', types), '💳');
    expect(isEmojiIcon(accountIconValueFor('Card', types)), isTrue);

    // A type with no icon of its own, and a type not in the list at all.
    expect(accountIconValueFor('Cash', types), 'account_balance');
    expect(
      resolveIcon(accountIconValueFor('Cash', types)),
      LucideIcons.landmark,
    );
  });

  testWidgets('a dropdown row shows its glyph and keeps the shared gap', (
    tester,
  ) async {
    final account = Account(
      id: 'a1',
      name: 'Everyday',
      type: 'Savings',
      balanceMinor: 0,
      currencyCode: 'INR',
      isActive: true,
      createdAt: epoch,
      updatedAt: epoch,
    );
    final types = [
      AccountType(id: 't1', name: 'Savings', icon: 'savings', createdAt: epoch),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: OptionRow.account(account, types)),
      ),
    );

    expect(find.text('Everyday'), findsOneWidget);
    expect(find.byIcon(LucideIcons.piggyBank), findsOneWidget);
    // Not the old static bank glyph that every row used to show.
    expect(find.byIcon(LucideIcons.landmark), findsNothing);

    // Measure the laid-out gap rather than trusting the constant: the icon's
    // right edge to the label's left edge.
    final iconRight = tester.getTopRight(find.byType(Icon)).dx;
    final labelLeft = tester.getTopLeft(find.text('Everyday')).dx;
    expect(labelLeft - iconRight, dropdownIconGap);
    expect(dropdownIconGap, greaterThan(8), reason: 'wider than the old gap');
  });
}
