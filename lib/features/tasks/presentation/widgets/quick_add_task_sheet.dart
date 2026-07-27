import 'package:flutter/material.dart';

import '../../domain/task_priority.dart';

class QuickAddTaskResult {
  const QuickAddTaskResult({
    required this.title,
    required this.priority,
    this.dueDate,
  });

  final String title;
  final TaskPriority priority;
  final DateTime? dueDate;
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
