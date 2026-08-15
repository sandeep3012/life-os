import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/reminders/reminder_mode.dart';

class LinkOption {
  const LinkOption({required this.type, required this.id, required this.label});

  final String type;
  final String id;
  final String label;
}

class QuickAddGoalResult {
  const QuickAddGoalResult({
    required this.title,
    required this.type,
    required this.targetValue,
    this.link,
    this.targetDate,
    this.reminderEnabled = false,
    this.reminderMode = ReminderMode.notification,
    this.reminderDaysBefore = 0,
  });

  final String title;
  final String type;
  final double? targetValue;
  final LinkOption? link;
  final DateTime? targetDate;
  final bool reminderEnabled;
  final ReminderMode reminderMode;
  final int reminderDaysBefore;
}

const _reminderDaysOptions = [
  (0, 'On the deadline'),
  (1, '1 day before'),
  (3, '3 days before'),
  (7, '1 week before'),
];

Future<QuickAddGoalResult?> showQuickAddGoalSheet(
  BuildContext context, {
  required List<Habit> habits,
  required List<Account> accounts,
  Goal? initial,
}) {
  final linkOptions = [
    for (final h in habits) LinkOption(type: 'habit', id: h.id, label: h.name),
    for (final a in accounts) LinkOption(type: 'account', id: a.id, label: a.name),
  ];
  return showModalBottomSheet<QuickAddGoalResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _QuickAddGoalSheet(linkOptions: linkOptions, initial: initial),
  );
}

class _QuickAddGoalSheet extends StatefulWidget {
  const _QuickAddGoalSheet({required this.linkOptions, this.initial});

  final List<LinkOption> linkOptions;
  final Goal? initial;

  @override
  State<_QuickAddGoalSheet> createState() => _QuickAddGoalSheetState();
}

class _QuickAddGoalSheetState extends State<_QuickAddGoalSheet> {
  late final _titleController = TextEditingController(text: widget.initial?.title);
  late final _targetController = TextEditingController(
    text: widget.initial?.targetValue?.toString(),
  );
  late String _type = widget.initial?.type ?? 'generic';
  LinkOption? _link;
  late DateTime? _targetDate = widget.initial?.targetDate;
  late bool _reminderEnabled = widget.initial?.reminderEnabled ?? false;
  late ReminderMode _reminderMode = ReminderMode.fromStorage(
    widget.initial?.reminderMode ?? 'notification',
  );
  late int _reminderDaysBefore = widget.initial?.reminderDaysBefore ?? 0;

  bool get _isEditMode => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _pickTargetDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
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
            Text(
              _isEditMode ? 'Edit goal' : 'New goal',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              autofocus: !_isEditMode,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Goal title'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'financial', label: Text('₹')),
                ButtonSegment(value: 'habit', label: Text('Habit')),
                ButtonSegment(value: 'generic', label: Text('Generic')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _targetController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: _type == 'financial' ? 'Target amount (₹)' : 'Target count',
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickTargetDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Deadline (optional)'),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _targetDate == null ? 'No deadline' : DateFormat.yMMMd().format(_targetDate!),
                    ),
                    if (_targetDate != null) ...[
                      const Spacer(),
                      IconButton(
                        tooltip: 'Clear deadline',
                        onPressed: () => setState(() => _targetDate = null),
                        icon: const Icon(Icons.close_rounded, size: 16),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_targetDate != null) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Remind me'),
                subtitle: const Text('Nudge before the deadline'),
                value: _reminderEnabled,
                onChanged: (v) => setState(() => _reminderEnabled = v),
              ),
              if (_reminderEnabled) ...[
                DropdownButtonFormField<int>(
                  initialValue: _reminderDaysBefore,
                  decoration: const InputDecoration(labelText: 'Remind'),
                  items: [
                    for (final (value, label) in _reminderDaysOptions)
                      DropdownMenuItem(value: value, child: Text(label)),
                  ],
                  onChanged: (v) => setState(() => _reminderDaysBefore = v ?? 0),
                ),
                const SizedBox(height: 8),
                SegmentedButton<ReminderMode>(
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
              ],
            ],
            if (widget.linkOptions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('No link'),
                    selected: _link == null,
                    onSelected: (_) => setState(() => _link = null),
                  ),
                  for (final option in widget.linkOptions)
                    ChoiceChip(
                      label: Text(option.label),
                      selected: _link?.id == option.id,
                      onSelected: (_) => setState(() => _link = option),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _titleController.text.trim().isEmpty
                    ? null
                    : () => Navigator.of(context).pop(
                        QuickAddGoalResult(
                          title: _titleController.text.trim(),
                          type: _type,
                          targetValue: double.tryParse(_targetController.text.trim()),
                          link: _link,
                          targetDate: _targetDate,
                          reminderEnabled: _reminderEnabled,
                          reminderMode: _reminderMode,
                          reminderDaysBefore: _reminderDaysBefore,
                        ),
                      ),
                child: Text(_isEditMode ? 'Save changes' : 'Add goal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
