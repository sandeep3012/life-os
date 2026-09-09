import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart' hide isSameDay;

import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../application/habits_providers.dart';
import '../widgets/quick_add_habit_sheet.dart';

class HabitDetailScreen extends ConsumerStatefulWidget {
  const HabitDetailScreen({super.key, required this.habitId});

  final String habitId;

  @override
  ConsumerState<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends ConsumerState<HabitDetailScreen> {
  bool _busy = false;
  DateTime _focusedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final habit = ref.watch(habitByIdProvider(widget.habitId));

    if (habit == null) {
      return const Scaffold(body: Center(child: Text('Habit not found')));
    }

    final progress = ref
        .watch(habitsWithProgressProvider)
        .where((p) => p.habit.id == habit.id)
        .firstOrNull;
    // Resolved independently of `progress` (which is active-habits-only via
    // habitsWithProgressProvider) so an archived habit's category still
    // shows correctly rather than silently falling back to "Uncategorized".
    final categories = ref.watch(habitCategoriesProvider).value ?? const [];
    final category = habit.categoryId == null
        ? null
        : categories.where((c) => c.id == habit.categoryId).firstOrNull;
    final categoryColor = category == null
        ? null
        : Color(int.parse(category.colorHex.replaceFirst('#', '0xFF')));
    final accent = categoryColor ?? colors.habits;
    final icon = category == null ? Icons.local_fire_department_rounded : resolveIcon(category.icon);
    final historyState = ref.watch(habitLogHistoryProvider(widget.habitId));
    final history = historyState.value ?? const <HabitLog>[];
    final today = dateOnly(DateTime.now());
    final created = dateOnly(habit.createdAt);
    final byDay = {for (final log in history) dateOnly(log.date): log};
    final recentDays = [for (var i = 0; i < 7; i++) DateTime(today.year, today.month, today.day - i)]
        .where((day) => !day.isBefore(created)).toList();

    return Scaffold(
      appBar: AppBar(title: Text(habit.name)),
      body: ListView(
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
                            Text(habit.name, style: theme.textTheme.titleMedium),
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
                      Icon(Icons.local_fire_department_rounded, size: 16, color: accent),
                      const SizedBox(width: 4),
                      Text(
                        '${progress?.streakDays ?? 0} day streak',
                        style: TextStyle(fontWeight: FontWeight.w700, color: accent),
                      ),
                      if (progress?.isAtRisk ?? false) ...[
                        const SizedBox(width: 8),
                        Text(
                          '· at risk',
                          style: TextStyle(color: colors.critical, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                  if (habit.reminderEnabled && habit.reminderHour != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.notifications_active_rounded,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Reminds you daily at '
                          '${TimeOfDay(hour: habit.reminderHour!, minute: habit.reminderMinute ?? 0).format(context)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _editHabit(habit),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit habit'),
            ),
          ),
          const SizedBox(height: 10),
          if (habit.archived)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _unarchiveHabit(habit),
                icon: const Icon(Icons.unarchive_outlined),
                label: const Text('Restore habit'),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _busy ? null : () => _archiveHabit(habit),
                style: TextButton.styleFrom(foregroundColor: colors.critical),
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Archive habit'),
              ),
            ),
          const SizedBox(height: 24),
          Text('Last 7 days', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (historyState.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (historyState.hasError)
            const Text('Could not load habit history. Please try again.')
          else ...[
            for (final day in recentDays)
              if (byDay[day] case final log?)
                _HistoryTile(habit: habit, log: log)
              else
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(day == today ? Icons.circle_outlined : Icons.cancel_outlined,
                    color: day == today ? theme.colorScheme.onSurfaceVariant : colors.critical),
                  title: Text(DateFormat.yMMMEd().format(day)),
                  subtitle: Text(day == today ? 'Pending' : 'Absent'),
                ),
            const SizedBox(height: 24),
            Text('Completion calendar', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TableCalendar<void>(
              firstDay: DateTime(created.year, created.month),
              lastDay: DateTime(today.year, today.month + 1, 0),
              focusedDay: _focusedMonth.isBefore(created) ? created : _focusedMonth,
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarFormat: CalendarFormat.month,
              availableGestures: AvailableGestures.horizontalSwipe,
              headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
              calendarStyle: const CalendarStyle(outsideDaysVisible: false),
              onPageChanged: (day) => setState(() => _focusedMonth = day),
              calendarBuilders: CalendarBuilders<void>(
                defaultBuilder: (context, day, _) => _calendarDay(context, day, created, today, byDay),
                todayBuilder: (context, day, _) => _calendarDay(context, day, created, today, byDay),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 16, runSpacing: 8, children: [
              Text('✓ Done', style: TextStyle(color: colors.habits)),
              Text('× Absent', style: TextStyle(color: colors.critical)),
              const Text('○ Today: pending'),
            ]),
            const SizedBox(height: 8),
            Text('Dates before this habit was created and future dates are unmarked.', style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _calendarDay(BuildContext context, DateTime day, DateTime created, DateTime today, Map<DateTime, HabitLog> logs) {
    final date = dateOnly(day);
    final eligible = !date.isBefore(created) && !date.isAfter(today);
    final done = eligible && (logs[date]?.completed ?? false);
    final absent = eligible && date.isBefore(today) && !done;
    final colors = context.appColors;
    final color = done ? colors.habits : absent ? colors.critical : Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      label: '${DateFormat.yMMMEd().format(date)}: ${done ? 'Done' : absent ? 'Absent' : eligible ? 'Pending' : 'Not tracked'}',
      child: Container(
        margin: const EdgeInsets.all(3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: done || absent ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: date == today ? Border.all(color: color) : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${day.day}', style: TextStyle(color: color)),
          if (done || absent) Icon(done ? Icons.check_rounded : Icons.close_rounded, size: 13, color: color),
        ]),
      ),
    );
  }

  Future<void> _editHabit(Habit habit) async {
    final categories = ref.read(habitCategoriesProvider).value ?? const [];
    final result = await showQuickAddHabitSheet(context, categories: categories, initial: habit);
    if (result == null) return;
    await ref.read(habitsControllerProvider).updateHabit(
      habit: habit,
      name: result.name,
      categoryId: result.categoryId,
      reminderEnabled: result.reminderEnabled,
      reminderHour: result.reminderHour,
      reminderMinute: result.reminderMinute,
      reminderMode: result.reminderMode,
    );
  }

  Future<void> _archiveHabit(Habit habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive this habit?'),
        content: const Text(
          "It's hidden from the Tasks & Habits list and its reminder is cancelled. Its log history is kept.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    await ref.read(habitsControllerProvider).archiveHabit(habit);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _unarchiveHabit(Habit habit) async {
    setState(() => _busy = true);
    await ref.read(habitsControllerProvider).unarchiveHabit(habit);
    if (mounted) setState(() => _busy = false);
  }
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.habit, required this.log});

  final Habit habit;
  final HabitLog log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    final pending = !log.completed && isSameDay(log.date, DateTime.now());
    final status = log.completed ? 'Done' : pending ? 'Pending' : 'Absent';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        log.completed ? Icons.check_circle_rounded : pending ? Icons.circle_outlined : Icons.cancel_outlined,
        color: log.completed ? colors.habits : pending ? theme.colorScheme.onSurfaceVariant : colors.critical,
      ),
      title: Text(DateFormat.yMMMEd().format(log.date)),
      subtitle: Text(log.notes == null || log.notes!.isEmpty ? status : '$status · ${log.notes!}',
        style: theme.textTheme.bodySmall),
      trailing: IconButton(
        tooltip: 'Edit note',
        icon: const Icon(Icons.edit_note_rounded, size: 20),
        onPressed: () => _editNote(context, ref),
      ),
    );
  }

  Future<void> _editNote(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: log.notes ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(DateFormat.yMMMEd().format(log.date)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Note (optional)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await ref.read(habitsControllerProvider).setCompletedForDate(
      habit,
      log.date,
      log.completed,
      notes: result.isEmpty ? '' : result,
    );
  }
}
