import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/router/app_sidebar.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/tab_rail.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../habits/application/habits_providers.dart';
import '../../../habits/domain/habit_progress.dart';
import '../../../habits/presentation/widgets/habit_tile.dart';
import '../../../habits/presentation/widgets/quick_add_habit_sheet.dart';
import '../../application/tasks_providers.dart';
import '../widgets/quick_add_task_sheet.dart';
import '../widgets/task_tile.dart';

enum _Section { tasks, habits }

enum _TaskFilter { today, upcoming, all }

class TasksHabitsScreen extends ConsumerStatefulWidget {
  const TasksHabitsScreen({super.key});

  @override
  ConsumerState<TasksHabitsScreen> createState() => _TasksHabitsScreenState();
}

class _TasksHabitsScreenState extends ConsumerState<TasksHabitsScreen> {
  _Section _section = _Section.tasks;
  _TaskFilter _taskFilter = _TaskFilter.today;
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
                  trailingIcon: _section == _Section.habits
                      ? LucideIcons.package
                      : null,
                  showTrailing: _section == _Section.habits,
                  onTrailing: () => context.push(RoutePaths.archivedHabits),
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
                onChanged: (value) => setState(() => _section = value),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _section == _Section.tasks
                  ? _TasksPane(
                      filter: _taskFilter,
                      onFilterChanged: (f) => setState(() => _taskFilter = f),
                    )
                  : const _HabitsPane(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: _section == _Section.tasks ? 'New task' : 'New habit',
        onPressed: () => _section == _Section.tasks ? _addTask() : _addHabit(),
        child: const Icon(LucideIcons.plus),
      ),
    );
  }

  Future<void> _addTask() async {
    final result = await showQuickAddTaskSheet(context);
    if (result == null) return;
    await ref.read(tasksControllerProvider).addTask(
      title: result.title,
      priority: result.priority,
      dueDate: result.dueDate,
      reminderEnabled: result.reminderEnabled,
      reminderMode: result.reminderMode,
    );
  }

  Future<void> _addHabit() async {
    final categories = ref.read(habitCategoriesProvider).value ?? const [];
    final result = await showQuickAddHabitSheet(context, categories: categories);
    if (result == null) return;
    await ref.read(habitsControllerProvider).addHabit(
      result.name,
      categoryId: result.categoryId,
      reminderEnabled: result.reminderEnabled,
      reminderHour: result.reminderHour,
      reminderMinute: result.reminderMinute,
      reminderMode: result.reminderMode,
    );
  }
}

class _TasksPane extends ConsumerWidget {
  const _TasksPane({required this.filter, required this.onFilterChanged});

  final _TaskFilter filter;
  final ValueChanged<_TaskFilter> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(allTasksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: AppTabRail<_TaskFilter>(
            value: filter,
            labels: const {
              _TaskFilter.today: 'Today',
              _TaskFilter.upcoming: 'Upcoming',
              _TaskFilter.all: 'All',
            },
            height: 36,
            fontSize: 12.5,
            onChanged: onFilterChanged,
          ),
        ),
        Expanded(
          child: tasksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not load tasks: $e')),
            data: (tasks) {
              final filtered = _applyFilter(tasks, filter);
              if (filtered.isEmpty) {
                return const _EmptyState(
                  icon: LucideIcons.listChecks,
                  message: 'Nothing here — add a task to get started.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final task = filtered[index];
                  return TaskTile(
                    key: ValueKey(task.id),
                    task: task,
                    onToggle: () => ref.read(tasksControllerProvider).toggleDone(task),
                    onDelete: () => ref.read(tasksControllerProvider).deleteTask(task),
                  ).animate().fadeIn(duration: 200.ms);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  List<Task> _applyFilter(List<Task> tasks, _TaskFilter filter) {
    final now = DateTime.now();
    switch (filter) {
      case _TaskFilter.today:
        // Status is deliberately ignored here: a task due today (or with no
        // due date at all) stays visible with a strikethrough once checked
        // off, matching the prototype's Home "Today" section — only tasks
        // due on a *different* day leave this view.
        return tasks
            .where((t) => t.dueDate == null || isSameDay(t.dueDate!, now))
            .toList();
      case _TaskFilter.upcoming:
        return tasks
            .where((t) => t.status == 'open')
            .where((t) => t.dueDate != null && t.dueDate!.isAfter(now) && !isSameDay(t.dueDate!, now))
            .toList();
      case _TaskFilter.all:
        return tasks;
    }
  }
}

class _HabitsPane extends ConsumerStatefulWidget {
  const _HabitsPane();

  @override
  ConsumerState<_HabitsPane> createState() => _HabitsPaneState();
}

class _HabitsPaneState extends ConsumerState<_HabitsPane> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(habitsWithProgressProvider);

    if (progress.isEmpty) {
      return const _EmptyState(
        icon: LucideIcons.flame,
        message: 'No habits yet — add one to start a streak.',
      );
    }

    final completedThisWeek = progress.fold<int>(
      0,
      (sum, item) => sum + item.weekCompletion.values.where((done) => done).length,
    );
    final totalThisWeek = progress.length * 7;
    final groups = <String, List<HabitProgress>>{};
    for (final item in progress) {
      final name = item.category?.name ?? _fallbackGroup(item.habit.name);
      groups.putIfAbsent(name, () => []).add(item);
    }
    // A removed/archived category must not leave an invisible active filter.
    final selectedCategory = groups.containsKey(_selectedCategory)
        ? _selectedCategory
        : null;
    final visible = selectedCategory == null ? progress : groups[selectedCategory]!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _WeekSummary(
          completed: completedThisWeek,
          total: totalThisWeek,
          progress: progress,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              ChoiceChip(
                label: const Text('All'),
                selected: selectedCategory == null,
                onSelected: (_) => setState(() => _selectedCategory = null),
              ),
              for (final category in groups.keys) ...[
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(category),
                  selected: selectedCategory == category,
                  onSelected: (_) => setState(() => _selectedCategory = category),
                ),
              ],
            ]),
          ),
        ),
        for (var index = 0; index < visible.length; index++) ...[
          HabitTile(
            key: ValueKey(visible[index].habit.id),
            progress: visible[index],
            onToggleToday: (completed) => ref.read(habitsControllerProvider)
                .toggleToday(visible[index].habit, completed),
            onTap: () => context.push(RoutePaths.habitDetail(visible[index].habit.id)),
          ),
          if (index != visible.length - 1)
            const Divider(height: 1, indent: 56),
        ],
      ],
    );
  }

  String _fallbackGroup(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('read') ||
        normalized.contains('meditat') ||
        normalized.contains('learn') ||
        normalized.contains('journal')) {
      return 'Personal growth';
    }
    if (normalized.contains('expense') || normalized.contains('finance')) {
      return 'Other habits';
    }
    return 'Daily habits';
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
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: ratio,
                    strokeWidth: 7,
                    color: context.appColors.habits,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  Text('${(ratio * 100).round()}%', style: theme.textTheme.labelLarge),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('This week’s habits', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text('$completed / $total check-ins', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    progress.isEmpty ? 'Add a habit to get started' : 'Keep going, you’re doing great!',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (var day = 1; day <= 7; day++) ...[
                        _WeekdayDot(
                          label: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][day - 1],
                          active: progress.any((item) => item.weekCompletion[day] ?? false),
                        ),
                        if (day != 7) const SizedBox(width: 4),
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
    final colors = context.appColors;
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? colors.habits : Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: active ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
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
