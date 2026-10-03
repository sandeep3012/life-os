import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:life_manager/app/theme/app_colors.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/services/file_storage_service.dart';
import 'package:life_manager/features/finance/data/finance_repository.dart';
import 'package:life_manager/features/spend_analyzer/presentation/widgets/spend_comparison_card.dart';

void main() {
  late AppDatabase db;
  late FinanceRepository repo;
  late String accountId;
  final now = DateTime.now();

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FinanceRepository(db, FileStorageService());
    await repo.createAccount(name: 'Cash', type: 'Cash');
    accountId = (await db.select(db.accounts).get()).single.id;
  });

  tearDown(() => db.close());

  Future<void> add(DateTime date, int rupees, {String? mode}) =>
      repo.createTransaction(
        accountId: accountId,
        merchant: 'x',
        amountMinor: rupees * 100,
        date: date,
        paymentMode: mode,
      );

  Future<void> pump(WidgetTester tester, {bool reduceMotion = false}) async {
    tester.view.physicalSize = const Size(392, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(20),
              child: SizedBox(
                height: 304,
                child: SpendComparisonCard(currencyCode: 'INR'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> disposeCleanly(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// This month: ₹50,000 in, ₹23,000 out (saved ₹27,000). Last month: ₹9,000
  /// in, ₹26,000 out (overspent by ₹17,000). Chosen so no amount lands on an
  /// axis gridline, which would make the same text appear twice.
  Future<void> seedTwoMonths() async {
    await add(DateTime(now.year, now.month, 1, 12), 50000);
    await add(DateTime(now.year, now.month, 1, 13), -23000);
    await add(DateTime(now.year, now.month - 1, 2, 12), 9000);
    await add(DateTime(now.year, now.month - 1, 3, 12), -26000);
  }

  testWidgets('starts on six months, spent and saved, with a legend', (
    tester,
  ) async {
    await seedTwoMonths();
    await pump(tester);

    for (var back = 5; back >= 0; back--) {
      final m = DateTime(now.year, now.month - back);
      expect(find.text(DateFormat.MMM().format(m)), findsWidgets);
    }
    expect(find.text('Spending'), findsOneWidget);
    expect(find.text('Savings'), findsOneWidget);
    await disposeCleanly(tester);
  });

  testWidgets('the tabs say how far back each one goes', (tester) async {
    await pump(tester);

    expect(find.text('Weekly\n(4W)'), findsOneWidget);
    expect(find.text('Monthly\n(6M)'), findsOneWidget);
    expect(find.text('Yearly\n(3Y)'), findsOneWidget);
    await disposeCleanly(tester);
  });

  testWidgets('no summary line or caption under the chart: only the legend', (
    tester,
  ) async {
    await seedTwoMonths();
    await pump(tester);

    expect(find.textContaining('Spent ₹', findRichText: true), findsNothing);
    expect(find.textContaining('Last 6 months'), findsNothing);
    expect(find.textContaining('so far'), findsNothing);
    await disposeCleanly(tester);
  });

  testWidgets(
    'monthly puts no amounts on the bars (they collided) and no callout yet',
    (tester) async {
      await seedTwoMonths();
      await pump(tester);

      expect(find.text('₹23k'), findsNothing);
      expect(find.text('₹27k'), findsNothing);
      expect(
        find.text('Spent'),
        findsNothing,
        reason: 'a callout before any tap',
      );
      await disposeCleanly(tester);
    },
  );

  testWidgets('tapping a month shows a callout with its exact figures', (
    tester,
  ) async {
    await seedTwoMonths();
    await pump(tester);

    final last = DateTime(now.year, now.month - 1);
    await tester.tap(find.text(DateFormat.MMM().format(last)).last);
    await tester.pumpAndSettle();

    // Last month: ₹26,000 spent, overspent by ₹17,000.
    expect(find.text(DateFormat.yMMM().format(last)), findsOneWidget);
    expect(find.text('Spent'), findsOneWidget);
    expect(find.text('₹26,000'), findsOneWidget);
    expect(find.text('Overspent'), findsOneWidget);
    expect(find.text('₹17,000'), findsOneWidget);
    expect(find.text('Saved'), findsNothing);
    await disposeCleanly(tester);
  });

  testWidgets('a callout for a saving says Saved, with the amount', (
    tester,
  ) async {
    await seedTwoMonths();
    await pump(tester);

    await tester.tap(find.text(DateFormat.MMM().format(now)).last);
    await tester.pumpAndSettle();

    expect(find.text('₹23,000'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('₹27,000'), findsOneWidget);
    await disposeCleanly(tester);
  });

  testWidgets('the callout stays inside the card, even at the edges', (
    tester,
  ) async {
    await seedTwoMonths();
    await pump(tester);
    final card = tester.getRect(find.byType(Card));

    // First month in the window, then the last: both edges.
    for (final back in [5, 0]) {
      final m = DateTime(now.year, now.month - back);
      await tester.tap(find.text(DateFormat.MMM().format(m)).last);
      await tester.pumpAndSettle();

      final callout = tester.getRect(
        find
            .ancestor(
              of: find.text('Spent'),
              matching: find.byType(IgnorePointer),
            )
            .first,
      );
      expect(callout.left, greaterThanOrEqualTo(card.left));
      expect(callout.right, lessThanOrEqualTo(card.right));
      expect(callout.top, greaterThanOrEqualTo(card.top));
    }
    await disposeCleanly(tester);
  });

  testWidgets('the callout sits beside the tapped group, never over it', (
    tester,
  ) async {
    await seedTwoMonths();
    await pump(tester);

    for (final back in [5, 3, 2, 0]) {
      final m = DateTime(now.year, now.month - back);
      final label = find.text(DateFormat.MMM().format(m)).last;
      await tester.tap(label);
      await tester.pumpAndSettle();

      final callout = tester.getRect(
        find
            .ancestor(
              of: find.text('Spent'),
              matching: find.byType(IgnorePointer),
            )
            .first,
      );
      final groupCentre = tester.getCenter(label).dx;
      expect(
        callout.left <= groupCentre && groupCentre <= callout.right,
        isFalse,
        reason:
            'the callout covers the bar you tapped (${DateFormat.MMM().format(m)})',
      );
    }
    await disposeCleanly(tester);
  });

  testWidgets('tapping the same month again dismisses the callout', (
    tester,
  ) async {
    await seedTwoMonths();
    await pump(tester);

    final label = find.text(DateFormat.MMM().format(now)).last;
    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(find.text('Spent'), findsOneWidget);

    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(find.text('Spent'), findsNothing);
    await disposeCleanly(tester);
  });

  testWidgets('switching tab clears the callout', (tester) async {
    await seedTwoMonths();
    await pump(tester);

    await tester.tap(find.text(DateFormat.MMM().format(now)).last);
    await tester.pumpAndSettle();
    expect(find.text('Spent'), findsOneWidget);

    await tester.tap(find.text('Yearly\n(3Y)'));
    await tester.pumpAndSettle();
    expect(find.text('Spent'), findsNothing);
    await disposeCleanly(tester);
  });

  testWidgets('the axis is labelled in short amounts, with a sign below zero', (
    tester,
  ) async {
    await seedTwoMonths();
    await pump(tester);

    expect(find.text('₹0'), findsOneWidget);
    expect(find.textContaining('-₹'), findsWidgets);
    await disposeCleanly(tester);
  });

  testWidgets(
    'weekly shows spending only: no savings, and amounts on the bars',
    (tester) async {
      await add(DateTime(now.year, now.month, now.day, 12), -430);
      await add(DateTime(now.year, now.month, now.day, 11), 90000); // salary
      await pump(tester);

      await tester.tap(find.text('Weekly\n(4W)'));
      await tester.pumpAndSettle();

      expect(
        find.text('Savings'),
        findsNothing,
        reason: 'income is lumpy weekly',
      );
      expect(find.text('Spending'), findsOneWidget);
      expect(find.text('₹430'), findsWidgets, reason: 'amount over the bar');
      await disposeCleanly(tester);
    },
  );

  testWidgets('yearly shows only years with history', (tester) async {
    await add(DateTime(now.year - 1, 6, 1, 12), -3000);
    await add(DateTime(now.year, now.month, 1, 12), -1000);
    await pump(tester);

    await tester.tap(find.text('Yearly\n(3Y)'));
    await tester.pumpAndSettle();

    expect(find.text('${now.year - 1}'), findsWidgets);
    expect(find.text('${now.year}'), findsWidgets);
    expect(find.text('${now.year - 2}'), findsNothing, reason: 'an empty year');
    await disposeCleanly(tester);
  });

  /// The tallest spent bar's current height.
  double tallestSpentBar(WidgetTester tester) {
    final spend = tester
        .element(find.byType(SpendComparisonCard))
        .appColors
        .spend;
    final rods = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == spend &&
          (w.decoration as BoxDecoration).borderRadius == null,
    );
    var tallest = 0.0;
    for (final e in rods.evaluate()) {
      final h = tester.getSize(find.byWidget(e.widget)).height;
      if (h > tallest) tallest = h;
    }
    return tallest;
  }

  testWidgets(
    'switching period plays a transition: old bars leave, new ones arrive',
    (tester) async {
      await seedTwoMonths();
      await pump(tester);
      final month = DateFormat.MMM().format(DateTime(now.year, now.month - 1));

      await tester.tap(find.text('Yearly\n(3Y)'));
      await tester.pump(); // start the transition
      await tester.pump(const Duration(milliseconds: 90));

      // Part-way: the months are still on their way out, the years already here.
      expect(
        find.text(month),
        findsWidgets,
        reason: 'old chart vanished instantly',
      );
      expect(
        find.text('${now.year}'),
        findsWidgets,
        reason: 'new chart not arriving',
      );

      await tester.pumpAndSettle();
      expect(find.text(month), findsNothing, reason: 'old chart never left');
      expect(find.text('${now.year}'), findsWidgets);
      await disposeCleanly(tester);
    },
  );

  testWidgets('the new bars grow up from the baseline rather than appearing', (
    tester,
  ) async {
    await seedTwoMonths();
    await pump(tester);

    await tester.tap(find.text('Yearly\n(3Y)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final partway = tallestSpentBar(tester);

    await tester.pumpAndSettle();
    final grown = tallestSpentBar(tester);

    expect(grown, greaterThan(20));
    expect(partway, lessThan(grown), reason: 'bars were already full height');
    await disposeCleanly(tester);
  });

  testWidgets('the bars start flat and do not all grow at once', (
    tester,
  ) async {
    await seedTwoMonths();
    await pump(tester);

    await tester.tap(find.text('Weekly\n(4W)'));
    await tester.pump();
    // Just after the old chart has gone: the first bars are barely up.
    await tester.pump(const Duration(milliseconds: 240));
    final early = tallestSpentBar(tester);

    await tester.pumpAndSettle();
    expect(early, lessThan(tallestSpentBar(tester) * 0.8));
    await disposeCleanly(tester);
  });

  testWidgets('with reduced motion the new chart just appears', (tester) async {
    await seedTwoMonths();
    await pump(tester, reduceMotion: true);
    final month = DateFormat.MMM().format(DateTime(now.year, now.month - 1));

    await tester.tap(find.text('Yearly\n(3Y)'));
    await tester.pump();

    expect(
      find.text(month),
      findsNothing,
      reason: 'animated despite reduced motion',
    );
    expect(find.text('${now.year}'), findsWidgets);
    await disposeCleanly(tester);
  });

  testWidgets(
    'an unchanged chart runs no animation',
    (tester) async {
      await seedTwoMonths();
      await pump(tester);

      // Nothing changed, so no transition is running and no frame is pending.
      expect(tester.binding.hasScheduledFrame, isFalse);
      await disposeCleanly(tester);
    },
  );

  testWidgets('a transfer is not spending', (tester) async {
    await add(DateTime(now.year, now.month, 1, 12), -99000, mode: 'transfer');
    await add(DateTime(now.year, now.month, 1, 13), -130);
    await pump(tester);

    await tester.tap(find.text(DateFormat.MMM().format(now)).last);
    await tester.pumpAndSettle();

    // Spent ₹130, and with no income that month, overspent by the same.
    expect(find.text('₹130'), findsNWidgets(2));
    expect(find.text('₹99,000'), findsNothing);
    await disposeCleanly(tester);
  });

  testWidgets('bars are square-ended, like an ordinary bar chart', (
    tester,
  ) async {
    await seedTwoMonths();
    await pump(tester);

    final theme = Theme.of(tester.element(find.byType(SpendComparisonCard)));
    final spend = tester
        .element(find.byType(SpendComparisonCard))
        .appColors
        .spend;
    final rods = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == spend,
    );
    expect(rods, findsWidgets);
    for (final e in rods.evaluate()) {
      final d = (e.widget as DecoratedBox).decoration as BoxDecoration;
      expect(d.borderRadius, isNull, reason: 'a rounded bar top');
    }
    expect(theme, isNotNull);
    await disposeCleanly(tester);
  });

  testWidgets('the selected month sits on a faint highlight, not a block', (
    tester,
  ) async {
    await seedTwoMonths();
    await pump(tester);

    final scheme = Theme.of(
      tester.element(find.byType(SpendComparisonCard)),
    ).colorScheme;
    final highlights = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color?.toARGB32() ==
              scheme.surfaceContainer.withValues(alpha: 0.5).toARGB32(),
    );
    expect(highlights, findsOneWidget);
    await disposeCleanly(tester);
  });
}
