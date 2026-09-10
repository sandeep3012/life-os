import 'package:flutter/material.dart';
import '../../../../core/widgets/compact_editor_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/scheduling/repeat_schedule.dart';
import '../../../../core/scheduling/schedule_fields.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../../finance/presentation/screens/category_management_screen.dart';
import '../../../../core/database/app_database_provider.dart';
import 'package:drift/drift.dart' show Value;
import '../../application/tasks_providers.dart';

import '../../../../core/reminders/reminder_mode.dart';
import '../../domain/task_priority.dart';

class QuickAddTaskResult {
  const QuickAddTaskResult({
    required this.title,
    required this.priority,
    this.dueDate,
    this.description,
    this.categoryId,
    this.schedule,
    this.reminderEnabled = false,
    this.reminderMode = ReminderMode.notification,
  });

  final String title;
  final String? description;
  final String? categoryId;
  final RepeatSchedule? schedule;
  final TaskPriority priority;
  final DateTime? dueDate;

  /// Only meaningful when [dueDate] is set.
  final bool reminderEnabled;

  /// Only meaningful when [reminderEnabled] is true.
  final ReminderMode reminderMode;
}

Future<QuickAddTaskResult?> showQuickAddTaskSheet(BuildContext context) {
  return showCompactEditorSheet<QuickAddTaskResult>(
    context: context,
    builder: (context) => const _QuickAddTaskSheet(),
  );
}

class _QuickAddTaskSheet extends ConsumerStatefulWidget {
  const _QuickAddTaskSheet();

  @override
  ConsumerState<_QuickAddTaskSheet> createState() => _QuickAddTaskSheetState();
}

class _QuickAddTaskSheetState extends ConsumerState<_QuickAddTaskSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  RepeatSchedule _schedule = RepeatSchedule(start: DateTime.now());
  String? _categoryId;
  Category? _newCategory;
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _dueDate;
  bool _reminderEnabled = false;
  ReminderMode _reminderMode = ReminderMode.notification;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    final result = await showCategoryEditorSheet(context, fixedKind: 'task');
    if (result == null || !mounted) return;
    final db = ref.read(appDatabaseProvider);
    final category = await db.into(db.categories).insertReturning(CategoriesCompanion.insert(
      name: result.name, icon: Value(result.icon), colorHex: result.colorHex, kind: const Value('task')));
    if (mounted) setState(() { _newCategory = category; _categoryId = category.id; });
  }

  @override
  Widget build(BuildContext context) {
    final categories = [...(ref.watch(taskCategoriesProvider).value ?? <Category>[])];
    if (_newCategory != null && !categories.any((c) => c.id == _newCategory!.id)) categories.add(_newCategory!);
    return CompactEditorSheet(title: 'New task', child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Task title'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _descriptionController, maxLines: 1,
            decoration: const InputDecoration(labelText: 'Description (optional)')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(_categoryId), initialValue: _categoryId ?? '',
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              const DropdownMenuItem(value: '', child: Text('Uncategorized')),
              for (final c in categories) DropdownMenuItem(value: c.id,
                child: Row(children: [IconOrEmoji(value: c.icon, size: 18),
                  const SizedBox(width: 8), Text(c.name)])),
            ], onChanged: (id) => setState(() => _categoryId = id == '' ? null : id)),
          TextButton.icon(onPressed: _addCategory, icon: const Icon(Icons.add),
            label: const Text('Add category')),
          const Text('Priority'),
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
          SwitchListTile(contentPadding: EdgeInsets.zero,
            title: const Text('Date and time'), value: _dueDate != null,
            onChanged: (enabled) => setState(() {
              _dueDate = enabled ? _schedule.start : null;
              if (!enabled) {
                _schedule = _schedule.copyWith(frequency: 'none', clearEnd: true);
                _reminderEnabled = false;
              }
            })),
          if (_dueDate != null) ScheduleFields(value: _schedule,
            onChanged: (value) => setState(() { _schedule = value; _dueDate = value.start; })),
          if (_dueDate == null) const Text('Set a date and time to enable repeats and reminders.'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Remind me'),
              subtitle: Text(_dueDate == null ? 'Set a date and time to enable a reminder' : 'Notify at the due time'),
              value: _reminderEnabled,
              onChanged: _dueDate == null ? null : (v) => setState(() => _reminderEnabled = v),
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
          if (_dueDate != null && !_schedule.hasOccurrence) const Text('No scheduled day falls in this date range.'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _titleController.text.trim().isEmpty || (_dueDate != null && !_schedule.hasOccurrence)
                  ? null
                  : () => Navigator.of(context).pop(
                      QuickAddTaskResult(
                        title: _titleController.text.trim(),
                        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
                        categoryId: _categoryId,
                        schedule: _dueDate == null ? null : _schedule,
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
