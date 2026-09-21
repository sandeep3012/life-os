import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/router/app_sidebar.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/inline_add_button.dart';
import '../../../../core/widgets/progress_ring.dart';
import '../../../../core/widgets/save_feedback.dart';
import '../../../../core/widgets/tab_rail.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../habits/application/habits_providers.dart';
import '../../../habits/domain/habit_progress.dart';
import '../../../habits/presentation/widgets/habit_tile.dart';
import '../../../habits/presentation/widgets/quick_add_habit_sheet.dart';
import '../../application/tasks_providers.dart';
import '../widgets/quick_add_task_sheet.dart';
import '../widgets/planner_tasks_pane.dart';
import '../../application/planner_view_providers.dart';
import 'planner_categories_screen.dart';

enum _Section { tasks, habits }

class TasksHabitsScreen extends ConsumerStatefulWidget {
  const TasksHabitsScreen({super.key, this.initialHabitsTab = false});

  /// Set by the Planner's `?tab=habits` route so menu navigation can arrive
  /// directly on the Habits tab without creating a second habits screen.
  final bool initialHabitsTab;

  @override
  ConsumerState<TasksHabitsScreen> createState() => _TasksHabitsScreenState();
}

class _TasksHabitsScreenState extends ConsumerState<TasksHabitsScreen> {
  late _Section _section;

  /// Whether the list's inline "Build a new …" row is on screen; the FAB
  /// shows only while it is not.
  bool _inlineAddVisible = false;

  void _onInlineAddVisibility(bool visible) {
    if (!mounted || _inlineAddVisible == visible) return;
    setState(() => _inlineAddVisible = visible);
  }

  @override
  void initState() {
    super.initState();
    _section = widget.initialHabitsTab ? _Section.habits : _Section.tasks;
  }

  @override
  void didUpdateWidget(covariant TasksHabitsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialHabitsTab != widget.initialHabitsTab) {
      _section = widget.initialHabitsTab ? _Section.habits : _Section.tasks;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppSidebar(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: Builder(
                builder: (context) => AppTopBar(
                  centerText: 'Planner',
                  centerIsTitle: true,
                  onMenu: () => Scaffold.of(context).openDrawer(),
                  trailingIcon: LucideIcons.slidersVertical,
                  trailingLabel: 'Layout and categories',
                  onTrailing: _showViewOptions,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppTabRail<_Section>(
                value: _section,
                labels: const {
                  _Section.tasks: 'Tasks',
                  _Section.habits: 'Habits',
                },
                icons: const {
                  _Section.tasks: LucideIcons.circleCheckBig,
                  _Section.habits: LucideIcons.sprout,
                },
                onChanged: (value) => setState(() => _section = value),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _section == _Section.tasks
                  ? PlannerTasksPane(
                      onAdd: _addTask,
                      onAddVisibilityChanged: _onInlineAddVisibility,
                    )
                  : _HabitsPane(
                      onAdd: _addHabit,
                      onAddVisibilityChanged: _onInlineAddVisibility,
                    ),
            ),
          ],
        ),
      ),
      // One add affordance at a time: the dashed row at the end of the list
      // while it is on screen, the FAB once it has scrolled away.
      floatingActionButton: _inlineAddVisible
          ? null
          : FloatingActionButton(
              tooltip: _section == _Section.tasks ? 'New task' : 'New habit',
              onPressed: () =>
                  _section == _Section.tasks ? _addTask() : _addHabit(),
              child: const Icon(LucideIcons.plus),
            ),
    );
  }

  Future<void> _addTask() async {
    final result = await showQuickAddTaskSheet(
      context,
      initialDueDate: ref.read(selectedTaskDayProvider),
    );
    if (result == null) return;
    await ref
        .read(tasksControllerProvider)
        .addTask(
          title: result.title,
          description: result.description,
          categoryId: result.categoryId,
          schedule: result.schedule,
          priority: result.priority,
          dueDate: result.dueDate,
          reminderEnabled: result.reminderEnabled,
          reminderMode: result.reminderMode,
        );
    if (!mounted) return;
    await showSaveFeedback(
      context,
      ref,
      title: 'Task saved',
      message: '“${result.title}” is ready to do.',
    );
  }

  Future<void> _showViewOptions() async {
    final habits = _section == _Section.habits;
    final manage = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final taskLayout = ref.watch(taskLayoutProvider);
          final habitLayout = ref.watch(habitLayoutProvider);
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      habits ? 'Habit view' : 'Task view',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (habits)
                    for (final layout in HabitLayout.values)
                      ListTile(
                        title: Text(
                          layout == HabitLayout.categories
                              ? 'By category'
                              : 'Pending and completed',
                        ),
                        subtitle: Text(
                          layout == HabitLayout.categories
                              ? 'Group habits by category'
                              : 'Today’s pending, completed, and not scheduled',
                        ),
                        trailing: habitLayout == layout
                            ? const Icon(LucideIcons.check)
                            : null,
                        onTap: () {
                          ref.read(habitLayoutProvider.notifier).select(layout);
                          Navigator.pop(sheetContext);
                        },
                      )
                  else
                    for (final layout in TaskLayout.values)
                      ListTile(
                        title: Text(
                          layout == TaskLayout.list
                              ? 'Date sections'
                              : 'Priority board',
                        ),
                        subtitle: Text(
                          layout == TaskLayout.list
                              ? 'Overdue, Today, Upcoming, No date, Completed'
                              : 'High, Medium, and Low priority cards',
                        ),
                        trailing: taskLayout == layout
                            ? const Icon(LucideIcons.check)
                            : null,
                        onTap: () {
                          ref.read(taskLayoutProvider.notifier).select(layout);
                          Navigator.pop(sheetContext);
                        },
                      ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(LucideIcons.tags),
                    title: Text(
                      habits
                          ? 'Manage habit categories'
                          : 'Manage task categories',
                    ),
                    onTap: () => Navigator.pop(sheetContext, true),
                  ),
                  if (habits)
                    ListTile(
                      leading: const Icon(LucideIcons.package),
                      title: const Text('Archived habits'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        this.context.push(RoutePaths.archivedHabits);
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (manage != true || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PlannerCategoriesScreen(kind: habits ? 'habit' : 'task'),
      ),
    );
  }

  Future<void> _addHabit() async {
    final categories = ref.read(habitCategoriesProvider).value ?? const [];
    final result = await showQuickAddHabitSheet(
      context,
      categories: categories,
    );
    if (result == null) return;
    await ref
        .read(habitsControllerProvider)
        .addHabit(
          result.name,
          targetAmount: result.targetAmount,
          targetUnit: result.targetUnit,
          description: result.description,
          schedule: result.schedule,
          categoryId: result.categoryId,
          reminderEnabled: result.reminderEnabled,
          reminderHour: result.reminderHour,
          reminderMinute: result.reminderMinute,
          reminderMode: result.reminderMode,
        );
    if (!mounted) return;
    await showSaveFeedback(
      context,
      ref,
      title: 'Habit saved',
      message: '“${result.name}” is ready to track.',
    );
  }
}

class _HabitsPane extends ConsumerStatefulWidget {
  const _HabitsPane({
    required this.onAdd,
    required this.onAddVisibilityChanged,
  });

  final VoidCallback onAdd;
  final ValueChanged<bool> onAddVisibilityChanged;

  @override
  ConsumerState<_HabitsPane> createState() => _HabitsPaneState();
}

class _HabitsPaneState extends ConsumerState<_HabitsPane> {
  String? _selectedCategory;
  static const _uncategorized = '__uncategorized__';

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsListProvider);
    if (habits.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (habits.hasError) {
      return const Center(child: Text('Could not load habits.'));
    }
    final progress = ref.watch(habitsWithProgressProvider);
    final categories = ref.watch(habitCategoriesProvider).value ?? const [];
    final layout = ref.watch(habitLayoutProvider);
    if (progress.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          const _EmptyState(
            icon: LucideIcons.flame,
            message: 'No habits yet — add one to start a streak.',
          ),
          InlineAddButton(
            label: 'Build a new habit',
            onTap: widget.onAdd,
            onVisibilityChanged: widget.onAddVisibilityChanged,
          ),
        ],
      );
    }
    final selected =
        _selectedCategory == _uncategorized ||
            categories.any((c) => c.id == _selectedCategory)
        ? _selectedCategory
        : null;
    final visible = progress
        .where(
          (item) =>
              selected == null ||
              (selected == _uncategorized
                  ? item.category == null
                  : item.category?.id == selected),
        )
        .toList();
    final groups = <String, List<HabitProgress>>{};
    if (layout == HabitLayout.categories) {
      for (final category in categories) {
        final items = visible
            .where((item) => item.category?.id == category.id)
            .toList();
        if (items.isNotEmpty) groups[category.id] = items;
      }
      final uncategorized = visible
          .where((item) => item.category == null)
          .toList();
      if (uncategorized.isNotEmpty) groups[_uncategorized] = uncategorized;
    } else {
      bool done(HabitProgress item) =>
          item.weekCompletion[DateTime.now().weekday] ?? false;
      groups['Today’s pending'] = visible
          .where((item) => item.isScheduledToday && !done(item))
          .toList();
      groups['Completed today'] = visible.where(done).toList();
      groups['Not scheduled today'] = visible
          .where((item) => !item.isScheduledToday && !done(item))
          .toList();
    }
    final completed = progress.fold<int>(
      0,
      (sum, item) =>
          sum + item.weekCompletion.values.where((done) => done).length,
    );
    final total = progress.fold<int>(
      0,
      (sum, item) => sum + item.weekCompletion.length,
    );
    return ListView(
      key: PageStorageKey('habits-${layout.name}'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _WeekSummary(completed: completed, total: total, progress: progress),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 12),
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
                        setState(() => _selectedCategory = entry.key),
                  ),
                ),
            ],
          ),
        ),
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No habits in this category.'),
          ),
        for (final group in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '${layout == HabitLayout.completion
                  ? group.key
                  : group.key == _uncategorized
                  ? 'Uncategorized'
                  : categories.firstWhere((c) => c.id == group.key).name} (${group.value.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (group.value.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'No habits here.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          for (final item in group.value) ...[
            HabitTile(
              key: ValueKey(item.habit.id),
              progress: item,
              onToggleToday: (completed) => ref
                  .read(habitsControllerProvider)
                  .toggleToday(item.habit, completed),
              onTap: () => context.push(RoutePaths.habitDetail(item.habit.id)),
            ),
            const Divider(height: 1, indent: 56),
          ],
        ],
        InlineAddButton(
          label: 'Build a new habit',
          onTap: widget.onAdd,
          onVisibilityChanged: widget.onAddVisibilityChanged,
        ),
      ],
    );
  }
}

class _WeekSummary extends StatelessWidget {
  const _WeekSummary({
    required this.completed,
    required this.total,
    required this.progress,
  });

  final int completed;
  final int total;
  final List<HabitProgress> progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = total == 0 ? 0.0 : completed / total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ProgressRing(
              progress: ratio,
              size: 64,
              strokeWidth: 7,
              color: theme.colorScheme.primary,
              trackColor: theme.colorScheme.onSurface.withValues(alpha: 0.18),
              child: Text(
                '${(ratio * 100).round()}%',
                style: theme.textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This week’s habits',
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$completed / $total check-ins',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    progress.isEmpty
                        ? 'Add a habit to get started'
                        : 'Keep going, you’re doing great!',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (var day = 1; day <= 7; day++) ...[
                        _WeekdayDot(
                          label: const [
                            'M',
                            'T',
                            'W',
                            'T',
                            'F',
                            'S',
                            'S',
                          ][day - 1],
                          active: progress.any(
                            (item) => item.weekCompletion[day] ?? false,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.flame, color: context.appColors.warning),
          ],
        ),
      ),
    );
  }
}

class _WeekdayDot extends StatelessWidget {
  const _WeekdayDot({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: active
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: colors.tasks),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
