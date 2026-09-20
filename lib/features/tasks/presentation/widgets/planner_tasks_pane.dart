import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/date_utils.dart';
import '../../application/tasks_providers.dart';
import '../../application/planner_view_providers.dart';
import '../../domain/task_priority.dart';
import 'task_tile.dart';

/// Date groups are shared by the list and each independently scrolling column.
Map<String, List<Task>> groupPlannerTasks(List<Task> tasks, DateTime now) {
  final today = dateOnly(now);
  final groups = <String, List<Task>>{
    'Overdue': [],
    'Today': [],
    'Upcoming': [],
    'No date': [],
    'Completed': [],
  };
  for (final task in tasks) {
    final due = task.dueDate == null ? null : dateOnly(task.dueDate!);
    final group = task.status == 'done'
        ? 'Completed'
        : due == null
        ? 'No date'
        : due.isBefore(today)
        ? 'Overdue'
        : due == today
        ? 'Today'
        : 'Upcoming';
    groups[group]!.add(task);
  }
  for (final group in groups.values) {
    group.sort((a, b) {
      final date = (a.dueDate ?? DateTime(9999)).compareTo(
        b.dueDate ?? DateTime(9999),
      );
      return date != 0 ? date : a.title.compareTo(b.title);
    });
  }
  return groups;
}

class PlannerTasksPane extends ConsumerStatefulWidget {
  const PlannerTasksPane({super.key});
  @override
  ConsumerState<PlannerTasksPane> createState() => _PlannerTasksPaneState();
}

class _PlannerTasksPaneState extends ConsumerState<PlannerTasksPane> {
  String? _categoryId;
  static const _uncategorized = '__uncategorized__';

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(taskCategoriesProvider).value ?? <Category>[];
    final selected =
        _categoryId == _uncategorized ||
            categories.any((c) => c.id == _categoryId)
        ? _categoryId
        : null;
    final layout = ref.watch(taskLayoutProvider);
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(
            children: [
              for (final entry in <String?, String>{
                null: 'All',
                for (final c in categories) c.id: c.name,
                _uncategorized: 'Uncategorized',
              }.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: selected == entry.key,
                    onSelected: (_) => setState(() => _categoryId = entry.key),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ref
              .watch(allTasksProvider)
              .when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) =>
                    const Center(child: Text('Could not load tasks.')),
                data: (tasks) {
                  final visible = tasks
                      .where(
                        (t) =>
                            selected == null ||
                            (selected == _uncategorized
                                ? t.categoryId == null
                                : t.categoryId == selected),
                      )
                      .toList();
                  if (layout == TaskLayout.priorities) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        // Three real priorities, not an invented fourth quadrant.
                        // Narrow phones use vertically stacked cards to keep text usable.
                        final availableWidth =
                            constraints.maxWidth /
                            (MediaQuery.textScalerOf(context).scale(14) / 14);
                        final columns = availableWidth >= 700
                            ? 3
                            : availableWidth >= 380
                            ? 2
                            : 1;
                        final height =
                            (constraints.maxHeight - 24) /
                            (columns == 3 ? 1 : 2);
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                mainAxisExtent: height.clamp(240.0, 600.0),
                              ),
                          itemCount: TaskPriority.values.length,
                          itemBuilder: (context, index) {
                            final priority = TaskPriority.values[index];
                            final items = visible
                                .where(
                                  (t) =>
                                      TaskPriorityX.fromValue(t.priority) ==
                                      priority,
                                )
                                .toList();
                            final colors = context.appColors;
                            final color = switch (priority) {
                              TaskPriority.high => colors.critical,
                              TaskPriority.medium => colors.warning,
                              TaskPriority.low => colors.info,
                            };
                            return Card(
                              margin: EdgeInsets.zero,
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    color: color.withValues(alpha: 0.12),
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      '${['High', 'Medium', 'Low'][index]} priority (${items.length})',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(color: color),
                                    ),
                                  ),
                                  Expanded(
                                    child: _list(
                                      items,
                                      categories,
                                      compact: true,
                                      storageKey: 'priority-${priority.name}',
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  }
                  return _list(
                    visible,
                    categories,
                    storageKey: 'task-date-list',
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _list(
    List<Task> tasks,
    List<Category> categories, {
    bool compact = false,
    required String storageKey,
  }) {
    if (tasks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No tasks here.'),
        ),
      );
    }
    final entries = <Object>[];
    for (final group in groupPlannerTasks(tasks, DateTime.now()).entries) {
      if (group.value.isEmpty) continue;
      entries.add('${group.key} (${group.value.length})');
      entries.addAll(group.value);
    }
    return ListView.builder(
      key: PageStorageKey(storageKey),
      primary: false,
      padding: EdgeInsets.fromLTRB(
        compact ? 8 : 16,
        4,
        compact ? 8 : 16,
        compact ? 16 : 100,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        if (entry is String) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(entry, style: Theme.of(context).textTheme.titleSmall),
          );
        }
        final task = entry as Task;
        return TaskTile(
          key: ValueKey(task.id),
          task: task,
          compact: compact,
          categoryLabel: categories
              .where((c) => c.id == task.categoryId)
              .firstOrNull
              ?.name,
          onOpen: () => context.push(RoutePaths.taskDetail(task.id)),
          onToggle: () => ref.read(tasksControllerProvider).toggleDone(task),
          onDelete: () => ref.read(tasksControllerProvider).deleteTask(task),
        );
      },
    );
  }
}
