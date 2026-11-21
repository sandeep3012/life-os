import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/features/subscription/application/plan_providers.dart';
import 'package:life_manager/features/subscription/data/purchase_service.dart';
import 'package:life_manager/features/subscription/domain/plan.dart';
import 'package:life_manager/features/subscription/presentation/paywall_sheet.dart';

import 'plan_fakes.dart';

/// A store that sells: two offers, and a purchase that goes through.
class _OpenStore implements PurchaseService {
  PlusOffer? bought;
  bool succeed = true;

  @override
  bool get available => true;

  @override
  Future<List<PlusOffer>> offers() async => const [
    PlusOffer(id: 'yearly', title: 'Yearly', price: '₹999', note: 'Best value'),
    PlusOffer(id: 'monthly', title: 'Monthly', price: '₹149'),
  ];

  bool cancel = false;

  @override
  Future<bool> buy(PlusOffer offer) async {
    bought = offer;
    if (cancel) throw const PurchaseCancelled();
    return succeed;
  }

  @override
  Future<bool> restore() async => false;

  @override
  Future<void> manage() async {}
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester, {
    required FixedPlan Function() plan,
    PurchaseService? store,
    PlusFeature? from,
  }) async {
    tester.view.physicalSize = const Size(392, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          planControllerProvider.overrideWith(plan),
          if (store != null) purchaseServiceProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: PaywallSheet(from: from)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('lists what Plus adds, the feature reached for first', (
    tester,
  ) async {
    await pump(tester, plan: FixedPlan.free, from: PlusFeature.fonts);
    for (final feature in PlusFeature.values) {
      expect(find.text(feature.title), findsOneWidget);
    }
    final fontsY = tester.getTopLeft(find.text(PlusFeature.fonts.title)).dy;
    final syncY = tester.getTopLeft(find.text(PlusFeature.sync.title)).dy;
    expect(fontsY, lessThan(syncY));
    expect(tester.takeException(), isNull);
    await dispose(tester);
  });

  testWidgets("before billing is connected it says so and sells nothing", (
    tester,
  ) async {
    await pump(tester, plan: FixedPlan.free);
    expect(find.textContaining("aren't open yet"), findsOneWidget);
    final subscribe = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Subscribe'),
    );
    expect(subscribe.onPressed, isNull, reason: 'no pretend purchase');
    expect(find.text('Restore purchases'), findsNothing);
    await dispose(tester);
  });

  testWidgets('signed out, it asks to sign in first', (tester) async {
    await pump(tester, plan: FixedPlan.signedOut);
    expect(find.text('Sign in to get Plus'), findsOneWidget);
    expect(find.text('Subscribe'), findsNothing);
    await dispose(tester);
  });

  testWidgets('with a store, an offer can be picked and bought', (
    tester,
  ) async {
    final store = _OpenStore();
    await pump(tester, plan: FixedPlan.free, store: store);
    expect(find.text('₹999'), findsOneWidget);
    expect(
      find.text(
        'Renews automatically until cancelled. Cancel any time in '
        'Google Play.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Monthly'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Subscribe'));
    await tester.pumpAndSettle();
    expect(store.bought?.id, 'monthly');
    // The store said yes, but Plus is the server's to give: until it
    // agrees, the sheet says so instead of pretending.
    expect(find.textContaining('Your purchase went through'), findsOneWidget);
    expect(find.text('Subscribe'), findsNothing);
    await dispose(tester);
  });

  testWidgets('backing out of the store sheet says nothing', (tester) async {
    final store = _OpenStore()..cancel = true;
    await pump(tester, plan: FixedPlan.free, store: store);
    await tester.tap(find.widgetWithText(FilledButton, 'Subscribe'));
    await tester.pumpAndSettle();
    expect(find.textContaining("haven't been charged"), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Subscribe'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('a purchase that fails says nothing was charged', (tester) async {
    final store = _OpenStore()..succeed = false;
    await pump(tester, plan: FixedPlan.free, store: store);
    await tester.tap(find.widgetWithText(FilledButton, 'Subscribe'));
    await tester.pumpAndSettle();
    expect(find.textContaining("haven't been charged"), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('on Plus it says so and offers nothing to buy', (tester) async {
    await pump(tester, plan: FixedPlan.plus);
    expect(find.textContaining("You're on PersonalOS Plus"), findsOneWidget);
    expect(find.text('Subscribe'), findsNothing);
    await dispose(tester);
  });
}
