import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/scheduling/repeat_schedule.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../application/tasks_providers.dart';
import '../../domain/task_priority.dart';

class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId});
  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final state = ref.watch(allTasksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Task details')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not load task')),
        data: (tasks) {
          final task = tasks.where((t) => t.id == taskId).firstOrNull;
          if (task == null) return const Center(child: Text('Task not found'));
          final head = tasks
              .where((t) => t.id == task.recurrenceId)
              .firstOrNull;
          final schedule = RepeatSchedule.decode(
            head?.schedule ?? task.schedule,
          );
          final categories =
              ref.watch(taskCategoriesProvider).value ?? const [];
          final category = task.categoryId == null
              ? null
              : categories.where((c) => c.id == task.categoryId).firstOrNull;
          final accent = category == null
              ? colors.tasks
              : _categoryColor(category.colorHex, colors.tasks);
          final icon = category == null
              ? Icons.checklist_rounded
              : resolveIcon(category.icon);
          final done = task.status == 'done';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  style: theme.textTheme.titleMedium,
                                ),
                                Text(
                                  category?.name ?? 'Uncategorized',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (task.description?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 12),
                        Text(task.description!),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            done
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 18,
                            color: done
                                ? accent
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            done ? 'Completed' : 'Open',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: done
                                  ? accent
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _PriorityBadge(
                            priority: TaskPriorityX.fromValue(task.priority),
                          ),
                          if (task.recurrenceId != null) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.repeat_rounded,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      ref.read(tasksControllerProvider).toggleDone(task),
                  icon: Icon(done ? Icons.undo_rounded : Icons.check_rounded),
                  label: Text(done ? 'Mark as open' : 'Mark complete'),
                ),
              ),
              const SizedBox(height: 20),
              Text('Task details', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              if (task.description?.isNotEmpty ?? false) ...[
                _DetailTile(
                  icon: Icons.notes_rounded,
                  title: 'Description',
                  value: task.description!,
                ),
              ],
              _DetailTile(
                icon: Icons.schedule_rounded,
                title: 'Date and time',
                value: task.dueDate == null
                    ? 'Not set'
                    : DateFormat.yMMMEd().add_jm().format(task.dueDate!),
              ),
              _DetailTile(
                icon: Icons.repeat_rounded,
                title: 'Repeat',
                value: _repeatLabel(schedule),
              ),
              _DetailTile(
                icon: Icons.label_outline_rounded,
                title: 'Category',
                value: category?.name ?? 'Uncategorized',
              ),
              _DetailTile(
                icon: Icons.flag_outlined,
                title: 'Priority',
                value: TaskPriorityX.fromValue(task.priority).label,
              ),
              _DetailTile(
                icon: Icons.notifications_none_rounded,
                title: 'Reminder',
                value: task.reminderEnabled && task.dueDate != null
                    ? '${task.reminderMode} at due time'
                    : 'Off',
              ),
            ],
          );
        },
      ),
    );
  }

  static Color _categoryColor(String value, Color fallback) {
    try {
      return Color(int.parse(value.replaceFirst('#', '0xFF')));
    } catch (_) {
      return fallback;
    }
  }

  static String _repeatLabel(RepeatSchedule? schedule) {
    if (schedule == null || schedule.frequency == 'none') {
      return 'Does not repeat';
    }
    if (schedule.frequency != 'weekly') {
      return '${schedule.frequency[0].toUpperCase()}${schedule.frequency.substring(1)}';
    }
    final weekdays =
        (schedule.weekdays.isEmpty
                ? [schedule.start.weekday]
                : schedule.weekdays)
            .map(
              (d) => const [
                'Mon',
                'Tue',
                'Wed',
                'Thu',
                'Fri',
                'Sat',
                'Sun',
              ][d - 1],
            )
            .join(', ');
    return 'Weekly · $weekdays';
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, size: 20),
    title: Text(title),
    subtitle: Text(value),
  );
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});
  final TaskPriority priority;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(priority.label, style: Theme.of(context).textTheme.labelSmall),
  );
}
