import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/router/app_shell.dart';
import 'package:life_manager/app/theme/app_colors.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The bottom nav's highlight capsule: it should sit behind the selected tab,
/// stretch across the gap on a tab change, and — when the platform asks for
/// reduced motion — move without stretching.
void main() {
  late AppDatabase db;
  late ValueNotifier<int> selected;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    selected = ValueNotifier(0);
  });

  tearDown(() => db.close());

  const destinations = [
    AppNavDestination(
      LucideIcons.layoutDashboard,
      LucideIcons.layoutDashboard,
      'Home',
    ),
    AppNavDestination(LucideIcons.wallet, LucideIcons.wallet, 'Finance'),
    AppNavDestination(LucideIcons.listChecks, LucideIcons.listChecks, 'Tasks'),
    AppNavDestination(LucideIcons.calendar, LucideIcons.calendar, 'Calendar'),
  ];

  Future<void> pumpNav(WidgetTester tester, {bool reducedMotion = false}) async {
    tester.view.physicalSize = const Size(392, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reducedMotion,
            ),
            child: child!,
          ),
          home: Scaffold(
            bottomNavigationBar: ValueListenableBuilder<int>(
              valueListenable: selected,
              builder: (context, index, _) => AppFloatingNavBar(
                destinations: destinations,
                selectedIndex: index,
                onSelected: (i) => selected.value = i,
                onAdd: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder highlight(WidgetTester tester) {
    final soft = tester.element(find.byType(AppFloatingNavBar)).appColors
        .accentSoft;
    return find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == soft,
    );
  }

  double iconCentreX(WidgetTester tester, IconData icon) =>
      tester.getCenter(find.byIcon(icon)).dx;

  Future<void> disposeCleanly(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('the highlight starts behind the selected tab', (tester) async {
    await pumpNav(tester);

    expect(highlight(tester), findsOneWidget);
    expect(
      tester.getCenter(highlight(tester)).dx,
      closeTo(iconCentreX(tester, LucideIcons.layoutDashboard), 0.5),
    );
    // And vertically behind the icon, not the label. The label's line height
    // differs by font, so allow a few px.
    expect(
      tester.getCenter(highlight(tester)).dy,
      closeTo(tester.getCenter(find.byIcon(LucideIcons.layoutDashboard)).dy, 3),
    );
    await disposeCleanly(tester);
  });

  testWidgets('a tab change stretches the highlight, then lands on the tab', (
    tester,
  ) async {
    await pumpNav(tester);
    final restingWidth = tester.getSize(highlight(tester)).width;

    selected.value = 3;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    // Mid-flight the leading edge is well ahead of the trailing one.
    expect(tester.getSize(highlight(tester)).width, greaterThan(restingWidth));

    await tester.pumpAndSettle();
    expect(tester.getSize(highlight(tester)).width, closeTo(restingWidth, 0.5));
    expect(
      tester.getCenter(highlight(tester)).dx,
      closeTo(iconCentreX(tester, LucideIcons.calendar), 0.5),
    );
    await disposeCleanly(tester);
  });

  testWidgets('a tab change to the left lands on the tab too', (tester) async {
    selected.value = 3;
    await pumpNav(tester);

    selected.value = 1;
    await tester.pumpAndSettle();

    expect(
      tester.getCenter(highlight(tester)).dx,
      closeTo(iconCentreX(tester, LucideIcons.wallet), 0.5),
    );
    await disposeCleanly(tester);
  });

  testWidgets('a second tap mid-flight redirects without jumping back', (
    tester,
  ) async {
    await pumpNav(tester);

    selected.value = 3;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final midway = tester.getCenter(highlight(tester)).dx;

    selected.value = 1;
    await tester.pump();
    // The first frame after the redirect starts from where it was, not from
    // the tab it was leaving.
    expect(
      tester.getCenter(highlight(tester)).dx,
      closeTo(midway, 1),
    );

    await tester.pumpAndSettle();
    expect(
      tester.getCenter(highlight(tester)).dx,
      closeTo(iconCentreX(tester, LucideIcons.wallet), 0.5),
    );
    await disposeCleanly(tester);
  });

  testWidgets('reduced motion moves the highlight without stretching it', (
    tester,
  ) async {
    await pumpNav(tester, reducedMotion: true);
    final restingWidth = tester.getSize(highlight(tester)).width;

    selected.value = 3;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(tester.getSize(highlight(tester)).width, closeTo(restingWidth, 0.5));

    await tester.pumpAndSettle();
    expect(
      tester.getCenter(highlight(tester)).dx,
      closeTo(iconCentreX(tester, LucideIcons.calendar), 0.5),
    );
    await disposeCleanly(tester);
  });
}
