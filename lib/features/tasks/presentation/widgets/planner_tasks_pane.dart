import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/inline_add_button.dart';
import '../../../../core/widgets/tab_rail.dart';
import '../../application/tasks_providers.dart';
import '../../application/planner_view_providers.dart';
import '../../domain/task_priority.dart';
import '../../domain/task_date_window.dart';
import 'task_tile.dart';

class PlannerTasksPane extends ConsumerStatefulWidget {
  const PlannerTasksPane({
    super.key,
    required this.onAdd,
    required this.onAddVisibilityChanged,
  });

  /// Opens the same quick-add sheet as the screen's FAB.
  final VoidCallback onAdd;

  /// Reports whether the inline add row is on screen (see [InlineAddButton]).
  final ValueChanged<bool> onAddVisibilityChanged;
  @override
  ConsumerState<PlannerTasksPane> createState() => _PlannerTasksPaneState();
}

class _PlannerTasksPaneState extends ConsumerState<PlannerTasksPane> {
  String? _categoryId;
  final _collapsedSections = <String>{};
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
    final day = ref.watch(selectedTaskDayProvider);
    final period = ref.watch(selectedTaskPeriodProvider);
    final window = taskDateWindow(day, period);
    final strip = taskStripWindow(day, period);
    final stripTasks = ref.watch(taskWindowTasksProvider(strip));
    final counts = <DateTime, int>{};
    for (final task in stripTasks.value ?? const <Task>[]) {
      if (!_matchesCategory(task, selected)) continue;
      final date = dateOnly(task.dueDate!);
      counts.update(date, (count) => count + 1, ifAbsent: () => 1);
    }
    return ref
        .watch(taskWindowTasksProvider(window))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('Could not load tasks.')),
          data: (tasks) {
            final visible = tasks
                .where((t) => _matchesCategory(t, selected))
                .toList();
            return CustomScrollView(
              key: PageStorageKey('task-pane-$period-$day-$selected-$layout'),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        child: AppTabRail<TaskPeriod>(
                          value: period,
                          labels: const {
                            TaskPeriod.day: 'Day',
                            TaskPeriod.week: 'Week',
                            TaskPeriod.month: 'Month',
                          },
                          icons: const {
                            TaskPeriod.day: LucideIcons.calendarDays,
                            TaskPeriod.week: LucideIcons.calendarRange,
                            TaskPeriod.month: LucideIcons.calendar,
                          },
                          onChanged: (value) => ref
                              .read(selectedTaskPeriodProvider.notifier)
                              .select(value),
                        ),
                      ),
                      _dateSelector(day, period, counts),
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
                                  onSelected: (_) =>
                                      setState(() => _categoryId = entry.key),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (layout == TaskLayout.priorities)
                  SliverToBoxAdapter(
                    child: LayoutBuilder(
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
                        final height = columns == 3 ? 360.0 : 420.0;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
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
                                      storageKey:
                                          'priority-${priority.name}-$period-$day-$selected',
                                      sectionScope: 'priority-${priority.name}',
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  )
                else
                  _taskSliver(visible, categories, sectionScope: 'list'),
                SliverToBoxAdapter(
                  child: InlineAddButton(
                    label: 'Build a new task',
                    onTap: widget.onAdd,
                    onVisibilityChanged: widget.onAddVisibilityChanged,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        );
  }

  SliverList _taskSliver(
    List<Task> tasks,
    List<Category> categories, {
    required String sectionScope,
  }) {
    if (tasks.isEmpty) {
      return SliverList(
        delegate: SliverChildListDelegate(const [
          Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('No tasks here.')),
          ),
        ]),
      );
    }
    final entries = _entriesFor(tasks, sectionScope);
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _entryWidget(
          entries[index],
          categories,
          sectionScope: sectionScope,
        ),
        childCount: entries.length,
        findChildIndexCallback: (key) => null,
      ),
    );
  }

  Widget _list(
    List<Task> tasks,
    List<Category> categories, {
    bool compact = false,
    required String storageKey,
    required String sectionScope,
  }) {
    if (tasks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No tasks here.'),
        ),
      );
    }
    final entries = _entriesFor(tasks, sectionScope);
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
        return _entryWidget(
          entries[index],
          categories,
          compact: compact,
          sectionScope: sectionScope,
        );
      },
    );
  }

  List<Object> _entriesFor(List<Task> tasks, String sectionScope) {
    final entries = <Object>[];
    for (final group in groupTasksByDueDate(tasks).entries) {
      entries.add((day: group.key, count: group.value.length));
      if (!_collapsedSections.contains('$sectionScope-${group.key}')) {
        entries.addAll(group.value);
      }
    }
    return entries;
  }

  Widget _entryWidget(
    Object entry,
    List<Category> categories, {
    bool compact = false,
    required String sectionScope,
  }) {
    if (entry is ({DateTime day, int count})) {
      final sectionKey = '$sectionScope-${entry.day}';
      final collapsed = _collapsedSections.contains(sectionKey);
      return Semantics(
        button: true,
        expanded: !collapsed,
        child: InkWell(
          onTap: () => setState(() {
            if (collapsed) {
              _collapsedSections.remove(sectionKey);
            } else {
              _collapsedSections.add(sectionKey);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_dateLabel(entry.day)} (${entry.count})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Icon(
                  collapsed
                      ? LucideIcons.chevronRight
                      : LucideIcons.chevronDown,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      );
    }
    final task = entry as Task;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16),
      child: TaskTile(
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
      ),
    );
  }

  bool _matchesCategory(Task task, String? selected) =>
      selected == null ||
      (selected == _uncategorized
          ? task.categoryId == null
          : task.categoryId == selected);

  String _dateLabel(DateTime day) {
    final today = dateOnly(DateTime.now());
    final date = DateFormat(
      day.year == today.year ? 'EEE, d MMM' : 'EEE, d MMM y',
    ).format(day);
    if (day == today) return 'Today · $date';
    if (day == DateTime(today.year, today.month, today.day + 1)) {
      return 'Tomorrow · $date';
    }
    return date;
  }

  void _selectDay(DateTime day) =>
      ref.read(selectedTaskDayProvider.notifier).select(day);

  void _movePeriod(DateTime day, TaskPeriod period, int direction) {
    if (period == TaskPeriod.month) {
      final first = DateTime(day.year, day.month + direction);
      final last = DateTime(first.year, first.month + 1, 0).day;
      _selectDay(DateTime(first.year, first.month, day.day.clamp(1, last)));
    } else {
      final step = period == TaskPeriod.week ? 7 : 1;
      _selectDay(DateTime(day.year, day.month, day.day + direction * step));
    }
  }

  Widget _dateSelector(
    DateTime selected,
    TaskPeriod period,
    Map<DateTime, int> counts,
  ) {
    final strip = taskStripWindow(selected, period);
    final window = taskDateWindow(selected, period);
    final last = DateTime(
      window.end.year,
      window.end.month,
      window.end.day - 1,
    );
    final theme = Theme.of(context);
    final heading = switch (period) {
      TaskPeriod.day => DateFormat.yMMMEd().format(selected),
      TaskPeriod.week =>
        '${DateFormat.MMMd().format(window.start)} – ${DateFormat.yMMMd().format(last)}',
      TaskPeriod.month => DateFormat.yMMMM().format(selected),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous ${period.name}',
                icon: const Icon(LucideIcons.chevronLeft),
                onPressed: () => _movePeriod(selected, period, -1),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selected,
                      firstDate: DateTime(
                        selected.year < 1900 ? selected.year : 1900,
                      ),
                      lastDate: DateTime(
                        selected.year > 2200 ? selected.year : 2200,
                        12,
                        31,
                      ),
                    );
                    if (picked != null && mounted) _selectDay(picked);
                  },
                  child: Text(
                    heading,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next ${period.name}',
                icon: const Icon(LucideIcons.chevronRight),
                onPressed: () => _movePeriod(selected, period, 1),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              // Equal width and height guarantee a circle, even on narrow phones.
              final diameter = ((constraints.maxWidth - 12) / 7).clamp(
                28.0,
                44.0,
              );
              return Row(
                children: [
                  for (var offset = 0; offset < 7; offset++)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final day = DateTime(
                            strip.start.year,
                            strip.start.month,
                            strip.start.day + offset,
                          );
                          final isSelected = selected == day;
                          final today = day == dateOnly(DateTime.now());
                          final count = counts[day] ?? 0;
                          return Semantics(
                            button: true,
                            selected: isSelected,
                            label:
                                '${DateFormat.yMMMMEEEEd().format(day)}, $count ${count == 1 ? 'task' : 'tasks'}',
                            child: InkWell(
                              onTap: () => _selectDay(day),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      DateFormat.E()
                                          .format(day)
                                          .substring(0, 1),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      width: diameter,
                                      height: diameter,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : today
                                            ? theme.colorScheme.primaryContainer
                                            : null,
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          '${day.day}',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: isSelected
                                                    ? theme
                                                          .colorScheme
                                                          .onPrimary
                                                    : today
                                                    ? theme
                                                          .colorScheme
                                                          .onPrimaryContainer
                                                    : theme
                                                          .colorScheme
                                                          .onSurface,
                                                fontWeight: isSelected
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      height: 5,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          for (
                                            var dot = 0;
                                            dot < count.clamp(0, 3);
                                            dot++
                                          )
                                            Container(
                                              width: 4,
                                              height: 4,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 1,
                                                  ),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
