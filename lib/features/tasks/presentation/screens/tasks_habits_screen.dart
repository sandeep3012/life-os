import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/date_utils.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text('Tasks & Habits', style: theme.textTheme.headlineSmall),
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
                  : const _HabitsPane(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _section == _Section.tasks ? _addTask() : _addHabit(),
        icon: const Icon(Icons.add_rounded),
        label: Text(_section == _Section.tasks ? 'New task' : 'New habit'),
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
    );
  }

  Future<void> _addHabit() async {
    final name = await showQuickAddHabitSheet(context);
    if (name == null) return;
    await ref.read(habitsControllerProvider).addHabit(name);
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not load tasks: $e')),
            data: (tasks) {
              final filtered = _applyFilter(tasks, filter);
              if (filtered.isEmpty) {
                return const _EmptyState(
                  icon: Icons.checklist_rounded,
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

class _HabitsPane extends ConsumerWidget {
  const _HabitsPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        ).animate().fadeIn(duration: 200.ms);
      },
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
