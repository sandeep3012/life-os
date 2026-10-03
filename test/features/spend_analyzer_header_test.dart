import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/features/spend_analyzer/presentation/screens/spend_analyzer_screen.dart';
import 'package:life_manager/features/spend_analyzer/presentation/widgets/spend_comparison_card.dart';

/// "Total spent" with its weekly line, and the spent-vs-saved card, sit side by
/// side as swipeable cards instead of one under the other.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('the comparison card is beside Total spent, peeking in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(392, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SpendAnalyzerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final total = tester.getRect(
      find.ancestor(of: find.text('Total spent'), matching: find.byType(Card)),
    );
    final comparison = tester.getRect(find.byType(SpendComparisonCard));

    // Same row — not stacked.
    expect(comparison.top, closeTo(total.top, 1));
    expect(comparison.height, closeTo(total.height, 1));
    expect(comparison.left, greaterThan(total.right));
    expect(
      comparison.left,
      lessThan(392),
      reason: 'no peek: nothing says "swipe"',
    );

    // The old stacked card is gone, and the rest of the screen moved up.
    expect(find.text('Monthly spending'), findsNothing);
    expect(find.text('By category'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('By category')).dy,
      lessThan(total.top + 304 + 120),
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
