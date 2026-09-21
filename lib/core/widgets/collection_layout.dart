import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum CollectionLayout { list, grid }

enum CollectionScreen { goals, notes, documents }

class CollectionLayouts
    extends Notifier<Map<CollectionScreen, CollectionLayout>> {
  @override
  Map<CollectionScreen, CollectionLayout> build() => {
    CollectionScreen.goals: CollectionLayout.list,
    CollectionScreen.notes: CollectionLayout.grid,
    CollectionScreen.documents: CollectionLayout.list,
  };

  void select(CollectionScreen screen, CollectionLayout layout) =>
      state = {...state, screen: layout};
}

// Retain independent choices across routes, like the Planner layout settings.
final collectionLayoutsProvider =
    NotifierProvider<
      CollectionLayouts,
      Map<CollectionScreen, CollectionLayout>
    >(CollectionLayouts.new);

class CollectionLayoutButton extends ConsumerWidget {
  const CollectionLayoutButton({super.key, required this.screen});
  final CollectionScreen screen;

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    tooltip: 'Layout settings',
    icon: const Icon(LucideIcons.slidersVertical),
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            final selected = ref.watch(collectionLayoutsProvider)[screen]!;
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Layout', style: Theme.of(context).textTheme.titleLarge),
                  for (final layout in CollectionLayout.values)
                    ListTile(
                      leading: Icon(
                        layout == CollectionLayout.list
                            ? LucideIcons.list
                            : LucideIcons.layoutGrid,
                      ),
                      title: Text(
                        layout == CollectionLayout.list ? 'List' : 'Grid',
                      ),
                      selected: selected == layout,
                      trailing: selected == layout
                          ? const Icon(LucideIcons.check)
                          : null,
                      onTap: () {
                        ref
                            .read(collectionLayoutsProvider.notifier)
                            .select(screen, layout);
                        Navigator.of(context).pop();
                      },
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

/// Lazy rows with content-sized cards, avoiding fixed-height grid overflows
/// for large text, long titles and linked-goal labels.
class CollectionView extends StatelessWidget {
  const CollectionView({
    super.key,
    required this.layout,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 100),
    this.footer,
  });
  final CollectionLayout layout;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsets padding;

  /// Full-width row appended after the last item in either layout.
  final Widget? footer;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = layout == CollectionLayout.list
          ? 1
          : ((constraints.maxWidth - padding.horizontal + 12) /
                    (160 * scale + 12))
                .floor()
                .clamp(1, 4);
      final rows = (itemCount / columns).ceil();
      return ListView.separated(
        key: ValueKey(layout),
        padding: padding,
        itemCount: rows + (footer == null ? 0 : 1),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, row) => row == rows
            ? footer!
            : columns == 1
            ? itemBuilder(context, row)
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var column = 0; column < columns; column++) ...[
                      if (column > 0) const SizedBox(width: 12),
                      Expanded(
                        child: row * columns + column < itemCount
                            ? itemBuilder(context, row * columns + column)
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
      );
    },
  );
}
