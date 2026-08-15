import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/reminders/reminder_mode.dart';

class QuickAddEventResult {
  const QuickAddEventResult({
    required this.title,
    required this.startTime,
    this.endTime,
    this.frequency = 'none',
    this.recurrenceEndDate,
    this.reminderEnabled = false,
    this.reminderMode = ReminderMode.notification,
    this.reminderMinutesBefore = 0,
  });

  final String title;
  final DateTime startTime;
  final DateTime? endTime;

  /// none | daily | weekly | monthly | yearly.
  final String frequency;
  final DateTime? recurrenceEndDate;
  final bool reminderEnabled;
  final ReminderMode reminderMode;
  final int reminderMinutesBefore;
}

const _frequencies = [
  ('none', 'Does not repeat'),
  ('daily', 'Daily'),
  ('weekly', 'Weekly'),
  ('monthly', 'Monthly'),
  ('yearly', 'Yearly'),
];

const _reminderPresets = [
  (0, 'At start time'),
  (5, '5 minutes before'),
  (15, '15 minutes before'),
  (30, '30 minutes before'),
  (60, '1 hour before'),
  (1440, '1 day before'),
];

/// Shows the add/edit sheet for a manual calendar event. Pass [initial] to
/// edit an existing event (prefills every field); omit it to create a new
/// one anchored to [initialDate]. [onDelete], when supplied alongside
/// [initial], surfaces a delete affordance that invokes the callback
/// directly rather than encoding deletion into [QuickAddEventResult] — the
/// result type stays purely about saving.
Future<QuickAddEventResult?> showQuickAddEventSheet(
  BuildContext context, {
  required DateTime initialDate,
  Event? initial,
  VoidCallback? onDelete,
}) {
  return showModalBottomSheet<QuickAddEventResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _QuickAddEventSheet(
      initialDate: initialDate,
      initial: initial,
      onDelete: onDelete,
    ),
  );
}

class _QuickAddEventSheet extends StatefulWidget {
  const _QuickAddEventSheet({required this.initialDate, this.initial, this.onDelete});

  final DateTime initialDate;
  final Event? initial;
  final VoidCallback? onDelete;

  @override
  State<_QuickAddEventSheet> createState() => _QuickAddEventSheetState();
}

class _QuickAddEventSheetState extends State<_QuickAddEventSheet> {
  late final _titleController = TextEditingController(text: widget.initial?.title ?? '');
  late final DateTime _baseDate = widget.initial != null
      ? DateTime(
          widget.initial!.startTime.year,
          widget.initial!.startTime.month,
          widget.initial!.startTime.day,
        )
      : widget.initialDate;

  late TimeOfDay _startTime = widget.initial != null
      ? TimeOfDay.fromDateTime(widget.initial!.startTime)
      : TimeOfDay.now();
  late TimeOfDay? _endTime = widget.initial?.endTime != null
      ? TimeOfDay.fromDateTime(widget.initial!.endTime!)
      : null;

  late String _frequency = widget.initial?.frequency ?? 'none';
  late DateTime? _recurrenceEndDate = widget.initial?.recurrenceEndDate;
  late bool _reminderEnabled = widget.initial?.reminderEnabled ?? false;
  late ReminderMode _reminderMode = ReminderMode.fromStorage(
    widget.initial?.reminderMode ?? 'notification',
  );
  late int _reminderMinutesBefore = widget.initial?.reminderMinutesBefore ?? 0;

  bool get _isEditMode => widget.initial != null;

  /// A series' shape (frequency/end date) can't be changed once created —
  /// only the option to set it up exists at create time.
  bool get _isPartOfSeries =>
      _isEditMode && (widget.initial!.frequency != 'none' || widget.initial!.recurrenceId != null);

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

  DateTime _combine(TimeOfDay time) {
    return DateTime(_baseDate.year, _baseDate.month, _baseDate.day, time.hour, time.minute);
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? _startTime,
    );
    if (picked != null) setState(() => _endTime = picked);
  }

  Future<void> _pickRecurrenceEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _recurrenceEndDate ?? _baseDate.add(const Duration(days: 30)),
      firstDate: _baseDate,
      lastDate: _baseDate.add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _recurrenceEndDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final startTime = _combine(_startTime);
    final endTime = _endTime == null ? null : _combine(_endTime!);
    final endBeforeStart = endTime != null && !endTime.isAfter(startTime);
    final canSubmit = _titleController.text.trim().isNotEmpty && !endBeforeStart;

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
              _isEditMode ? 'Edit event' : 'New event',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              autofocus: !_isEditMode,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Event title'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: _pickStartTime,
                    icon: const Icon(Icons.access_time_rounded, size: 16),
                    label: Text(_startTime.format(context)),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _pickEndTime,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(_endTime?.format(context) ?? 'Add end time'),
                  ),
                ),
                if (_endTime != null)
                  IconButton(
                    tooltip: 'Clear end time',
                    onPressed: () => setState(() => _endTime = null),
                    icon: const Icon(Icons.close_rounded, size: 16),
                  ),
              ],
            ),
            if (endBeforeStart)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  'End time must be after start time',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            Text('Repeats', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            if (_isPartOfSeries)
              Text(
                'Repeats: ${_frequencies.firstWhere((f) => f.$1 == _frequency, orElse: () => _frequencies.first).$2}',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Wrap(
                spacing: 8,
                children: [
                  for (final (value, label) in _frequencies)
                    ChoiceChip(
                      label: Text(label),
                      selected: _frequency == value,
                      onSelected: (_) => setState(() => _frequency = value),
                    ),
                ],
              ),
            if (!_isPartOfSeries && _frequency != 'none') ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickRecurrenceEndDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Ends (optional)'),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_busy_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _recurrenceEndDate == null
                            ? 'Never'
                            : DateFormat.yMMMd().format(_recurrenceEndDate!),
                      ),
                      if (_recurrenceEndDate != null) ...[
                        const Spacer(),
                        IconButton(
                          tooltip: 'Clear end date',
                          onPressed: () => setState(() => _recurrenceEndDate = null),
                          icon: const Icon(Icons.close_rounded, size: 16),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Remind me'),
              subtitle: const Text('Nudge before the event starts'),
              value: _reminderEnabled,
              onChanged: (v) => setState(() => _reminderEnabled = v),
            ),
            if (_reminderEnabled) ...[
              DropdownButtonFormField<int>(
                initialValue: _reminderMinutesBefore,
                decoration: const InputDecoration(labelText: 'Remind'),
                items: [
                  for (final (value, label) in _reminderPresets)
                    DropdownMenuItem(value: value, child: Text(label)),
                ],
                onChanged: (v) => setState(() => _reminderMinutesBefore = v ?? 0),
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canSubmit
                    ? () => Navigator.of(context).pop(
                        QuickAddEventResult(
                          title: _titleController.text.trim(),
                          startTime: startTime,
                          endTime: endTime,
                          frequency: _isPartOfSeries ? widget.initial!.frequency : _frequency,
                          recurrenceEndDate: _isPartOfSeries
                              ? widget.initial!.recurrenceEndDate
                              : (_frequency == 'none' ? null : _recurrenceEndDate),
                          reminderEnabled: _reminderEnabled,
                          reminderMode: _reminderMode,
                          reminderMinutesBefore: _reminderMinutesBefore,
                        ),
                      )
                    : null,
                child: Text(_isEditMode ? 'Save changes' : 'Add event'),
              ),
            ),
            if (_isEditMode && widget.onDelete != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onDelete!();
                  },
                  icon: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error),
                  label: Text(
                    'Delete event',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
