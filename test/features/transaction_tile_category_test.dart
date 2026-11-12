import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/utils/icon_lookup.dart';
import 'package:life_manager/features/finance/presentation/widgets/transaction_tile.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// A category can carry a colourful emoji, but the tile used to look the icon
/// up with `resolveIcon`, which only knows the flat Lucide names — so every
/// emoji category showed the default tag glyph in the transaction list.
void main() {
  final when = DateTime(2026, 10, 1);

  Transaction transaction() => Transaction(
    id: 't',
    accountId: 'a',
    categoryId: 'c',
    merchant: 'Cafe',
    amountMinor: -25000,
    date: when,
    createdAt: when,
    paymentMode: 'card',
  );

  Category category({required String icon, required String colorHex}) =>
      Category(
        id: 'c',
        name: 'Eating out',
        icon: icon,
        colorHex: colorHex,
        kind: 'expense',
        position: 0,
        createdAt: when,
      );

  Future<void> pump(
    WidgetTester tester,
    Category? category, {
    Account? account,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TransactionTile(
            transaction: transaction(),
            currencyCode: 'INR',
            category: category,
            account: account,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a category with an emoji icon shows that emoji', (tester) async {
    await pump(tester, category(icon: '🍽️', colorHex: '#E0475A'));

    expect(find.text('🍽️'), findsOneWidget);
    // Not the fallback tag glyph the bug used to show.
    expect(find.byIcon(resolveIcon(defaultCategoryIcon)), findsNothing);
  });

  testWidgets('a category with a Lucide icon still shows that icon', (
    tester,
  ) async {
    await pump(tester, category(icon: 'restaurant', colorHex: '#E0475A'));

    expect(find.byIcon(LucideIcons.utensils), findsOneWidget);
  });

  testWidgets('a category with no colour renders without throwing', (
    tester,
  ) async {
    await pump(tester, category(icon: '🍽️', colorHex: ''));

    expect(tester.takeException(), isNull);
    expect(find.text('🍽️'), findsOneWidget);
    expect(find.text('Cafe'), findsOneWidget);
  });

  testWidgets('the second line names the account, not the date or mode', (
    tester,
  ) async {
    final account = Account(
      id: 'a',
      name: 'HDFC Savings',
      type: 'Savings',
      balanceMinor: 0,
      openingBalanceMinor: 0,
      currencyCode: 'INR',
      isActive: true,
      position: 0,
      isDefault: false,
      createdAt: when,
      updatedAt: when,
    );
    await pump(
      tester,
      category(icon: 'restaurant', colorHex: '#E0475A'),
      account: account,
    );

    expect(find.text('Eating out · HDFC Savings'), findsOneWidget);
    expect(find.textContaining('Oct'), findsNothing);
    expect(find.byIcon(LucideIcons.creditCard), findsNothing);
  });
}
