import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_color_theme.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/widgets/surface_card.dart';
import 'package:life_manager/features/finance/domain/budget_progress.dart';
import 'package:life_manager/features/finance/domain/payment_mode.dart';
import 'package:life_manager/features/spend_analyzer/domain/payment_mode_spend.dart';
import 'package:life_manager/features/spend_analyzer/presentation/widgets/budget_bar.dart';
import 'package:life_manager/features/spend_analyzer/presentation/widgets/payment_mode_breakdown.dart';

/// "Budget vs actual" showed only a grey tick under each row: the bar's track
/// was `surfaceContainerHighest`, which this theme maps to the card's own
/// white, so with ₹0 spent there was nothing to see but the limit marker.
void main() {
  final now = DateTime(2026, 10, 1);

  BudgetProgress progress({int spent = 0}) => BudgetProgress(
    budget: Budget(
      id: 'b',
      categoryId: 'c',
      period: 'monthly',
      limitMinor: 3000000,
      startDate: now,
      effectiveMonth: now,
      active: true,
      createdAt: now,
    ),
    category: Category(
      id: 'c',
      name: 'Groceries',
      icon: 'shopping_cart',
      colorHex: '#2E9E63',
      kind: 'expense',
      createdAt: now,
    ),
    spentMinor: spent,
  );

  double luminance(Color c) => c.computeLuminance();
  double contrast(Color a, Color b) {
    final la = luminance(a), lb = luminance(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  Future<ThemeData> pump(WidgetTester tester, ThemeData theme, Widget child) async {
    tester.view.physicalSize = const Size(392, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SurfaceCard(child: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return theme;
  }

  for (final palette in AppColorTheme.values) {
    for (final dark in [false, true]) {
      final label = '${palette.name} ${dark ? 'dark' : 'light'}';
      final theme = dark ? AppTheme.dark(palette) : AppTheme.light(palette);

      testWidgets('budget bar track is visible on its card — $label', (tester) async {
        await pump(
          tester,
          theme,
          BudgetBar(progress: progress(), currencyCode: 'INR'),
        );

        final track = tester
            .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
            .backgroundColor!;
        final card = theme.colorScheme.surface;

        expect(track, isNot(card), reason: 'track is the card colour, so invisible');
        expect(
          contrast(track, card),
          greaterThanOrEqualTo(1.1),
          reason: 'track too faint against the card behind it',
        );
      });

      testWidgets('payment mode track is visible on its card — $label', (
        tester,
      ) async {
        await pump(
          tester,
          theme,
          PaymentModeBreakdown(
            currencyCode: 'INR',
            breakdown: [
              PaymentModeSpend(mode: paymentModes.first, totalMinor: 100000, share: 0.4),
            ],
          ),
        );

        final track = tester
            .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
            .backgroundColor!;
        final card = theme.colorScheme.surface;

        expect(track, isNot(card));
        expect(contrast(track, card), greaterThanOrEqualTo(1.1));
      });
    }
  }
}
