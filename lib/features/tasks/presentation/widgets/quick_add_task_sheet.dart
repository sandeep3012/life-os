import 'package:flutter/material.dart';

import '../../../../core/reminders/reminder_mode.dart';
import '../../domain/task_priority.dart';

class QuickAddTaskResult {
  const QuickAddTaskResult({
    required this.title,
    required this.priority,
    this.dueDate,
    this.reminderEnabled = true,
    this.reminderMode = ReminderMode.notification,
  });

  final String title;
  final TaskPriority priority;
  final DateTime? dueDate;

  /// Only meaningful when [dueDate] is set.
  final bool reminderEnabled;

  /// Only meaningful when [reminderEnabled] is true.
  final ReminderMode reminderMode;
}

Future<QuickAddTaskResult?> showQuickAddTaskSheet(BuildContext context) {
  return showModalBottomSheet<QuickAddTaskResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _QuickAddTaskSheet(),
  );
}

class _QuickAddTaskSheet extends StatefulWidget {
  const _QuickAddTaskSheet();

  @override
  State<_QuickAddTaskSheet> createState() => _QuickAddTaskSheetState();
}

class _QuickAddTaskSheetState extends State<_QuickAddTaskSheet> {
  final _titleController = TextEditingController();
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _dueDate;
  bool _reminderEnabled = true;
  ReminderMode _reminderMode = ReminderMode.notification;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (!mounted) return;
    setState(() {
      _dueDate = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 9,
        time?.minute ?? 0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New task', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Task title'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final p in TaskPriority.values)
                ChoiceChip(
                  label: Text(p.label),
                  selected: _priority == p,
                  onSelected: (_) => setState(() => _priority = p),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _pickDueDate,
            icon: const Icon(Icons.calendar_today_rounded, size: 16),
            label: Text(
              _dueDate == null
                  ? 'Set due date'
                  : _dueDate!.toLocal().toString().substring(0, 16),
            ),
          ),
          if (_dueDate != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Remind me'),
              subtitle: const Text('Notify at the due time'),
              value: _reminderEnabled,
              onChanged: (v) => setState(() => _reminderEnabled = v),
            ),
          if (_dueDate != null && _reminderEnabled)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SegmentedButton<ReminderMode>(
                segments: const [
                  ButtonSegment(
                    value: ReminderMode.notification,
                    label: Text('Notification'),
                    icon: Icon(Icons.notifications_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: ReminderMode.alarm,
                    label: Text('Alarm'),
                    icon: Icon(Icons.alarm_rounded, size: 16),
                  ),
                ],
                selected: {_reminderMode},
                onSelectionChanged: (s) => setState(() => _reminderMode = s.first),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _titleController.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(
                      QuickAddTaskResult(
                        title: _titleController.text.trim(),
                        priority: _priority,
                        dueDate: _dueDate,
                        reminderEnabled: _reminderEnabled,
                        reminderMode: _reminderMode,
                      ),
                    ),
              child: const Text('Add task'),
            ),
          ),
        ],
      ),
    );
  }
}
