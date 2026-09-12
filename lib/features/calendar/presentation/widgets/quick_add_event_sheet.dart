import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/reminders/reminder_mode.dart';
import '../../../../core/scheduling/repeat_schedule.dart';
import '../../../../core/scheduling/schedule_fields.dart';
import '../../../../core/widgets/compact_editor_sheet.dart';

class QuickAddEventResult {
  const QuickAddEventResult({
    required this.title,
    required this.startTime,
    this.endTime,
    this.description,
    this.schedule,
    this.frequency = 'none',
    this.recurrenceEndDate,
    this.reminderEnabled = false,
    this.reminderMode = ReminderMode.notification,
    this.reminderMinutesBefore = 0,
    this.editFollowing = false,
  });

  final String title;
  final String? description;
  final RepeatSchedule? schedule;
  final DateTime startTime;
  final DateTime? endTime;

  /// none | daily | weekly | monthly | yearly.
  final String frequency;
  final DateTime? recurrenceEndDate;
  final bool reminderEnabled;
  final ReminderMode reminderMode;
  final int reminderMinutesBefore;
  final bool editFollowing;
}

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
  bool editFollowing = false,
  RepeatSchedule? seriesRule,
}) {
  return showCompactEditorSheet<QuickAddEventResult>(
    context: context,
    builder: (context) => _QuickAddEventSheet(
      initialDate: initialDate,
      initial: initial,
      onDelete: onDelete,
      editFollowing: editFollowing,
      seriesRule: seriesRule,
    ),
  );
}

class _QuickAddEventSheet extends StatefulWidget {
  const _QuickAddEventSheet({
    required this.initialDate,
    this.initial,
    this.onDelete,
    this.editFollowing = false,
    this.seriesRule,
  });

  final DateTime initialDate;
  final Event? initial;
  final VoidCallback? onDelete;
  final bool editFollowing;
  final RepeatSchedule? seriesRule;

  @override
  State<_QuickAddEventSheet> createState() => _QuickAddEventSheetState();
}

class _QuickAddEventSheetState extends State<_QuickAddEventSheet> {
  late final _titleController = TextEditingController(
    text: widget.initial?.title ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.initial?.description,
  );
  late List<int> _weekdays = widget.seriesRule?.weekdays ?? [];
  late DateTime _baseDate = widget.initial != null
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

  late String _frequency =
      widget.seriesRule?.frequency ?? widget.initial?.frequency ?? 'none';
  late DateTime? _recurrenceEndDate =
      widget.seriesRule?.end ?? widget.initial?.recurrenceEndDate;
  late bool _reminderEnabled = widget.initial?.reminderEnabled ?? false;
  late ReminderMode _reminderMode = ReminderMode.fromStorage(
    widget.initial?.reminderMode ?? 'notification',
  );
  late int _reminderMinutesBefore = widget.initial?.reminderMinutesBefore ?? 0;

  bool get _isEditMode => widget.initial != null;

  /// A series' shape (frequency/end date) can't be changed once created —
  /// only the option to set it up exists at create time.
  bool get _isPartOfSeries =>
      !widget.editFollowing &&
      _isEditMode &&
      (widget.initial!.frequency != 'none' ||
          widget.initial!.recurrenceId != null);

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

  DateTime _combine(TimeOfDay time) {
    return DateTime(
      _baseDate.year,
      _baseDate.month,
      _baseDate.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? _startTime,
    );
    if (picked != null) setState(() => _endTime = picked);
  }

  Future<void> _saveEvent() async {
    final startTime = _combine(_startTime);
    final endTime = _endTime == null ? null : _combine(_endTime!);
    final endBeforeStart = endTime != null && !endTime.isAfter(startTime);
    final validSchedule =
        _isPartOfSeries ||
        RepeatSchedule(
          start: startTime,
          frequency: _frequency,
          weekdays: _weekdays,
          end: _recurrenceEndDate,
        ).hasOccurrence;
    if (_titleController.text.trim().isEmpty ||
        endBeforeStart ||
        !validSchedule) {
      return;
    }

    var editFollowing = widget.editFollowing;
    if (_isEditMode &&
        widget.initial!.recurrenceId != null &&
        !widget.editFollowing) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Edit repeating event'),
          content: const Text(
            'Choose which occurrences to update. Past events will stay unchanged.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('This occurrence only'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('This and future occurrences'),
            ),
          ],
        ),
      );
      if (choice == null || !mounted) return;
      editFollowing = choice;
      if (editFollowing && widget.seriesRule == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This older series has no saved repeat rule. Please create a new series.',
            ),
          ),
        );
        return;
      }
    }

    Navigator.of(context).pop(
      QuickAddEventResult(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        schedule: editFollowing && widget.seriesRule != null
            ? widget.seriesRule
            : _isPartOfSeries
            ? RepeatSchedule.decode(widget.initial!.schedule)
            : RepeatSchedule(
                start: startTime,
                frequency: _frequency,
                weekdays: _weekdays,
                end: _recurrenceEndDate,
              ),
        startTime: startTime,
        endTime: endTime,
        frequency: editFollowing && widget.seriesRule != null
            ? widget.seriesRule!.frequency
            : _isPartOfSeries
            ? widget.initial!.frequency
            : _frequency,
        recurrenceEndDate: editFollowing && widget.seriesRule != null
            ? widget.seriesRule!.end
            : _isPartOfSeries
            ? widget.initial!.recurrenceEndDate
            : (_frequency == 'none' ? null : _recurrenceEndDate),
        reminderEnabled: _reminderEnabled,
        reminderMode: _reminderMode,
        reminderMinutesBefore: _reminderMinutesBefore,
        editFollowing: editFollowing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final startTime = _combine(_startTime);
    final endTime = _endTime == null ? null : _combine(_endTime!);
    final endBeforeStart = endTime != null && !endTime.isAfter(startTime);
    final validSchedule =
        _isPartOfSeries ||
        RepeatSchedule(
          start: startTime,
          frequency: _frequency,
          weekdays: _weekdays,
          end: _recurrenceEndDate,
        ).hasOccurrence;
    final canSubmit =
        _titleController.text.trim().isNotEmpty &&
        !endBeforeStart &&
        validSchedule;

    return CompactEditorSheet(
      title: widget.editFollowing
          ? 'Edit this and future events'
          : _isEditMode
          ? 'Edit event'
          : 'New event',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            autofocus: !_isEditMode,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Event title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 1,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
            ),
          ),
          ScheduleFields(
            firstDate: widget.editFollowing ? widget.initialDate : null,
            value: RepeatSchedule(
              start: _combine(_startTime),
              frequency: _frequency,
              weekdays: _weekdays,
              end: _recurrenceEndDate,
            ),
            allowRepeatChanges: !_isPartOfSeries,
            onChanged: (value) => setState(() {
              _baseDate = value.start;
              _startTime = TimeOfDay.fromDateTime(value.start);
              _frequency = value.frequency;
              _weekdays = value.weekdays;
              _recurrenceEndDate = value.end;
            }),
          ),
          if (_isPartOfSeries)
            const Text(
              'Repeating event — changes affect this occurrence only.',
            ),
          const SizedBox(height: 12),
          Row(
            children: [
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
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
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
              onSelectionChanged: (s) =>
                  setState(() => _reminderMode = s.first),
            ),
          ],
          if (!validSchedule)
            const Text('No scheduled day falls in this date range.'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canSubmit ? _saveEvent : null,
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
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                label: Text(
                  'Delete event',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
