import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/widgets/collection_layout.dart';

void main() {
  test('layout choices are independent and preserve current defaults', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(collectionLayoutsProvider)[CollectionScreen.notes],
      CollectionLayout.grid,
    );
    expect(
      container.read(collectionLayoutsProvider)[CollectionScreen.goals],
      CollectionLayout.list,
    );
    container
        .read(collectionLayoutsProvider.notifier)
        .select(CollectionScreen.goals, CollectionLayout.grid);
    expect(
      container.read(collectionLayoutsProvider)[CollectionScreen.goals],
      CollectionLayout.grid,
    );
    expect(
      container.read(collectionLayoutsProvider)[CollectionScreen.documents],
      CollectionLayout.list,
    );
    container
        .read(collectionLayoutsProvider.notifier)
        .select(CollectionScreen.notes, CollectionLayout.list);
    expect(
      container.read(collectionLayoutsProvider)[CollectionScreen.notes],
      CollectionLayout.list,
    );
    expect(
      container.read(collectionLayoutsProvider)[CollectionScreen.goals],
      CollectionLayout.grid,
    );
  });

  testWidgets('layout settings switches between list and grid', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            appBar: AppBar(
              actions: const [
                CollectionLayoutButton(screen: CollectionScreen.documents),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Layout settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grid'));
    await tester.pumpAndSettle();
    expect(
      container.read(collectionLayoutsProvider)[CollectionScreen.documents],
      CollectionLayout.grid,
    );
    await tester.tap(find.byTooltip('Layout settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    expect(
      container.read(collectionLayoutsProvider)[CollectionScreen.documents],
      CollectionLayout.list,
    );
  });

  testWidgets('grid uses two columns on a phone and one with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(392, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget app(double scale) => MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: CollectionView(
            layout: CollectionLayout.grid,
            itemCount: 3,
            itemBuilder: (_, index) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Card $index with a long title that wraps onto several lines',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(1));
    final first = find.textContaining('Card 0');
    final second = find.textContaining('Card 1');
    expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
    expect(tester.getTopLeft(first).dx, lessThan(tester.getTopLeft(second).dx));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(app(2));
    expect(tester.getTopLeft(first).dy, lessThan(tester.getTopLeft(second).dy));
    expect(tester.takeException(), isNull);
  });
}
