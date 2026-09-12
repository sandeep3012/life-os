import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart' hide isSameDay;

import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/scheduling/repeat_schedule.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../application/tasks_providers.dart';
import '../../domain/task_priority.dart';
import '../widgets/quick_add_task_sheet.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});
  final String taskId;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen>
    with SingleTickerProviderStateMixin {
  DateTime _focusedMonth = DateTime.now();
  bool _detailsExpanded = false;
  late final AnimationController _arrowController;

  @override
  void initState() {
    super.initState();
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _arrowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final state = ref.watch(allTasksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Task details')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not load task')),
        data: (tasks) {
          final task = tasks.where((t) => t.id == widget.taskId).firstOrNull;
          if (task == null) return const Center(child: Text('Task not found'));

          final seriesId = task.recurrenceId;
          final occurrences = seriesId == null
              ? const <Task>[]
              : tasks
                    .where(
                      (t) => t.recurrenceId == seriesId && t.dueDate != null,
                    )
                    .toList();
          final head = seriesId == null
              ? null
              : tasks.where((t) => t.id == seriesId).firstOrNull;
          final schedule = RepeatSchedule.decode(
            head?.schedule ?? task.schedule,
          );
          final recurring =
              seriesId != null &&
              schedule != null &&
              schedule.frequency != 'none';
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
                          const SizedBox(width: 20),
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
                          if (recurring) ...[
                            const SizedBox(width: 18),
                            Icon(
                              Icons.repeat_rounded,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeInOut,
                        child: _detailsExpanded
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(height: 1),
                                  const SizedBox(height: 8),
                                  if (task.description?.isNotEmpty ?? false)
                                    _DetailTile(
                                      icon: Icons.notes_rounded,
                                      title: 'Description',
                                      value: task.description!,
                                    ),
                                  _DetailTile(
                                    icon: Icons.schedule_rounded,
                                    title: 'Date and time',
                                    value: task.dueDate == null
                                        ? 'Not set'
                                        : DateFormat.yMMMEd().add_jm().format(
                                            task.dueDate!,
                                          ),
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
                                    value: TaskPriorityX.fromValue(
                                      task.priority,
                                    ).label,
                                  ),
                                  _DetailTile(
                                    icon: Icons.notifications_none_rounded,
                                    title: 'Reminder',
                                    value:
                                        task.reminderEnabled &&
                                            task.dueDate != null
                                        ? '${task.reminderMode} at due time'
                                        : 'Off',
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: AnimatedBuilder(
                          animation: _arrowController,
                          builder: (context, child) {
                            final phase = _arrowController.value * math.pi * 2;
                            return Transform.translate(
                              offset: Offset(
                                math.sin(phase) * 1.5,
                                math.cos(phase) * 1.5,
                              ),
                              child: Opacity(
                                opacity: 0.45 + (_arrowController.value * 0.55),
                                child: child,
                              ),
                            );
                          },
                          child: IconButton(
                            tooltip: _detailsExpanded
                                ? 'Hide task details'
                                : 'Show task details',
                            onPressed: () => setState(
                              () => _detailsExpanded = !_detailsExpanded,
                            ),
                            icon: AnimatedRotation(
                              turns: _detailsExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 220),
                              child: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                              ),
                            ),
                          ),
                        ),
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
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _editTask(context, ref, task),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit task'),
                ),
              ),
              if (recurring) ...[
                const SizedBox(height: 24),
                _TaskHistory(
                  occurrences: occurrences,
                  accent: accent,
                  critical: colors.critical,
                ),
                const SizedBox(height: 24),
                _TaskCalendar(
                  occurrences: occurrences,
                  today: dateOnly(DateTime.now()),
                  focusedMonth: _focusedMonth,
                  onPageChanged: (day) => setState(() => _focusedMonth = day),
                  accent: accent,
                  critical: colors.critical,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _editTask(BuildContext context, WidgetRef ref, Task task) async {
    final result = await showQuickAddTaskSheet(context, initial: task);
    if (result == null || !context.mounted) return;
    await ref
        .read(tasksControllerProvider)
        .updateTask(
          task: task,
          title: result.title,
          description: result.description,
          categoryId: result.categoryId,
          dueDate: result.dueDate,
          priority: result.priority,
          reminderEnabled: result.reminderEnabled,
          reminderMode: result.reminderMode,
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

class _TaskHistory extends StatelessWidget {
  const _TaskHistory({
    required this.occurrences,
    required this.accent,
    required this.critical,
  });
  final List<Task> occurrences;
  final Color accent;
  final Color critical;

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final byDay = {
      for (final task in occurrences) dateOnly(task.dueDate!): task,
    };
    final days = [
      for (var i = 6; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Last 7 days', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final day in days)
          _TaskHistoryTile(
            task: byDay[day],
            day: day,
            today: today,
            accent: accent,
            critical: critical,
          ),
      ],
    );
  }
}

class _TaskHistoryTile extends StatelessWidget {
  const _TaskHistoryTile({
    required this.task,
    required this.day,
    required this.today,
    required this.accent,
    required this.critical,
  });
  final Task? task;
  final DateTime day;
  final DateTime today;
  final Color accent;
  final Color critical;

  @override
  Widget build(BuildContext context) {
    final scheduled = task != null;
    final done = task?.status == 'done';
    final pending = scheduled && !done && isSameDay(day, today);
    final missed = scheduled && !done && day.isBefore(today);
    final label = !scheduled
        ? 'Not scheduled'
        : done
        ? 'Completed'
        : pending
        ? 'Pending'
        : missed
        ? 'Missed'
        : 'Scheduled';
    final color = done
        ? accent
        : missed
        ? critical
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        done
            ? Icons.check_circle_rounded
            : missed
            ? Icons.cancel_outlined
            : pending
            ? Icons.circle_outlined
            : Icons.remove_circle_outline_rounded,
        color: color,
      ),
      title: Text(DateFormat.yMMMEd().format(day)),
      subtitle: Text(label),
    );
  }
}

class _TaskCalendar extends StatelessWidget {
  const _TaskCalendar({
    required this.occurrences,
    required this.today,
    required this.focusedMonth,
    required this.onPageChanged,
    required this.accent,
    required this.critical,
  });
  final List<Task> occurrences;
  final DateTime today;
  final DateTime focusedMonth;
  final ValueChanged<DateTime> onPageChanged;
  final Color accent;
  final Color critical;

  @override
  Widget build(BuildContext context) {
    final dates = occurrences.map((task) => dateOnly(task.dueDate!)).toList()
      ..sort();
    final firstDay = dates.isEmpty ? today : dates.first;
    final lastDay = dates.isEmpty ? today : dates.last;
    final byDay = {
      for (final task in occurrences) dateOnly(task.dueDate!): task,
    };
    final safeFocused = focusedMonth.isBefore(firstDay)
        ? firstDay
        : focusedMonth.isAfter(lastDay)
        ? lastDay
        : focusedMonth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Completion calendar',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        TableCalendar<void>(
          firstDay: firstDay,
          lastDay: lastDay,
          focusedDay: safeFocused,
          startingDayOfWeek: StartingDayOfWeek.monday,
          calendarFormat: CalendarFormat.month,
          availableGestures: AvailableGestures.horizontalSwipe,
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          calendarStyle: const CalendarStyle(outsideDaysVisible: false),
          onPageChanged: onPageChanged,
          calendarBuilders: CalendarBuilders<void>(
            defaultBuilder: (context, day, _) => _day(context, day, byDay),
            todayBuilder: (context, day, _) => _day(context, day, byDay),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Text('✓ Completed', style: TextStyle(color: accent)),
            Text('× Missed', style: TextStyle(color: critical)),
            const Text('○ Pending / scheduled'),
          ],
        ),
      ],
    );
  }

  Widget _day(BuildContext context, DateTime day, Map<DateTime, Task> byDay) {
    final date = dateOnly(day);
    final task = byDay[date];
    final done = task?.status == 'done';
    final missed = task != null && !done && date.isBefore(today);
    final color = done
        ? accent
        : missed
        ? critical
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      label:
          '${DateFormat.yMMMEd().format(date)}: ${task == null
              ? 'Not scheduled'
              : done
              ? 'Completed'
              : missed
              ? 'Missed'
              : 'Scheduled'}',
      child: Container(
        margin: const EdgeInsets.all(3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: done || missed
              ? color.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: date == today ? Border.all(color: color) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${day.day}', style: TextStyle(color: color)),
            if (done || missed)
              Icon(
                done ? Icons.check_rounded : Icons.close_rounded,
                size: 13,
                color: color,
              ),
          ],
        ),
      ),
    );
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
