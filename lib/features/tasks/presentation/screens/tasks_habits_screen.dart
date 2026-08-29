import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../../../core/widgets/animations/index.dart';
import '../../../habits/application/habits_providers.dart';
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
  bool _showArchivedHabits = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showFab = _section == _Section.tasks || !_showArchivedHabits;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Tasks & Habits', style: theme.textTheme.headlineSmall),
                  ),
                  if (_section == _Section.habits)
                    IconButton(
                      tooltip: _showArchivedHabits ? 'Show active habits' : 'Archived habits',
                      icon: Icon(
                        _showArchivedHabits
                            ? Icons.inventory_2_rounded
                            : Icons.inventory_2_outlined,
                      ),
                      onPressed: () => setState(() => _showArchivedHabits = !_showArchivedHabits),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SegmentedButton<_Section>(
                segments: const [
                  ButtonSegment(value: _Section.tasks, label: Text('Tasks')),
                  ButtonSegment(value: _Section.habits, label: Text('Habits')),
                ],
                selected: {_section},
                onSelectionChanged: (s) => setState(() => _section = s.first),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _section == _Section.tasks
                  ? _TasksPane(
                      filter: _taskFilter,
                      onFilterChanged: (f) => setState(() => _taskFilter = f),
                    )
                  : _HabitsPane(
                      showArchived: _showArchivedHabits,
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: showFab
          ? FloatingActionButton.extended(
              onPressed: () => _section == _Section.tasks ? _addTask() : _addHabit(),
              icon: const Icon(Icons.add_rounded),
              label: Text(_section == _Section.tasks ? 'New task' : 'New habit'),
            )
          : null,
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
  const _TasksPane({
    required this.filter,
    required this.onFilterChanged,
  });

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
          child: SegmentedButton<_TaskFilter>(
            segments: const [
              ButtonSegment(value: _TaskFilter.today, label: Text('Today')),
              ButtonSegment(value: _TaskFilter.upcoming, label: Text('Upcoming')),
              ButtonSegment(value: _TaskFilter.all, label: Text('All')),
            ],
            selected: {filter},
            onSelectionChanged: (s) => onFilterChanged(s.first),
          ),
        ),
        Expanded(
          child: tasksAsync.when(
            loading: () => const SkeletonListLoader(itemCount: 6, itemHeight: 44),
            error: (e, _) => Center(child: Text('Could not load tasks: $e')),
            data: (tasks) {
              final filtered = _applyFilter(tasks, filter);
              if (filtered.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () => _refresh(ref),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      _EmptyState(
                        icon: Icons.checklist_rounded,
                        message: 'Nothing here — add a task to get started.',
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () => _refresh(ref),
                child: ListView.builder(
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(allTasksProvider);
    await ref.read(allTasksProvider.future);
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

class _HabitsPane extends ConsumerWidget {
  const _HabitsPane({
    required this.showArchived,
  });

  final bool showArchived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (showArchived) {
      final archived = ref.watch(archivedHabitsProvider).value ?? const [];
      final categories = ref.watch(habitCategoriesProvider).value ?? const [];
      final categoriesById = {for (final c in categories) c.id: c};

      if (archived.isEmpty) {
        return const _EmptyState(
          icon: Icons.inventory_2_outlined,
          message: 'No archived habits.',
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: archived.length,
        itemBuilder: (context, index) {
          final habit = archived[index];
          return _ArchivedHabitTile(
            key: ValueKey(habit.id),
            habit: habit,
            category: habit.categoryId == null ? null : categoriesById[habit.categoryId],
            onUnarchive: () => ref.read(habitsControllerProvider).unarchiveHabit(habit),
            onTap: () => context.push(RoutePaths.habitDetail(habit.id)),
          ).animate().fadeIn(duration: 200.ms);
        },
      );
    }

    final progress = ref.watch(habitsWithProgressProvider);

    if (progress.isEmpty) {
      return const _EmptyState(
        icon: Icons.local_fire_department_rounded,
        message: 'No habits yet — add one to start a streak.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: progress.length,
      itemBuilder: (context, index) {
        final p = progress[index];
        return HabitTile(
          key: ValueKey(p.habit.id),
          progress: p,
          onToggleToday: (completed) =>
              ref.read(habitsControllerProvider).toggleToday(p.habit, completed),
          onTap: () => context.push(RoutePaths.habitDetail(p.habit.id)),
        ).animate().fadeIn(duration: 200.ms);
      },
    );
  }
}

class _ArchivedHabitTile extends StatelessWidget {
  const _ArchivedHabitTile({
    super.key,
    required this.habit,
    required this.category,
    required this.onUnarchive,
    required this.onTap,
  });

  final Habit habit;
  final Category? category;
  final VoidCallback onUnarchive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = category == null
        ? colors.habits
        : Color(int.parse(category!.colorHex.replaceFirst('#', '0xFF')));
    final icon = category == null ? Icons.local_fire_department_rounded : resolveIcon(category!.icon);

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.16),
        foregroundColor: color,
        child: Icon(icon, size: 20),
      ),
      title: Text(habit.name),
      subtitle: const Text('Archived'),
      trailing: TextButton(onPressed: onUnarchive, child: const Text('Unarchive')),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
  });

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
            Icon(icon, size: 48, color: colors.tasks)
                .animate()
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.0, 1.0),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                )
                .fadeIn(duration: const Duration(milliseconds: 250)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
                .animate(delay: 50.ms)
                .fadeIn(duration: const Duration(milliseconds: 250))
                .slideY(begin: 0.1, end: 0, duration: const Duration(milliseconds: 250)),
          ],
        ),
      ),
    );
  }
}
