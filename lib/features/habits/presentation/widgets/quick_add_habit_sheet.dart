import 'package:flutter/material.dart';

class QuickAddHabitResult {
  const QuickAddHabitResult({
    required this.name,
    this.reminderEnabled = false,
    this.reminderHour,
    this.reminderMinute,
  });

  final String name;
  final bool reminderEnabled;

  /// Only set when [reminderEnabled] is true.
  final int? reminderHour;
  final int? reminderMinute;
}

Future<QuickAddHabitResult?> showQuickAddHabitSheet(BuildContext context) {
  return showModalBottomSheet<QuickAddHabitResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _QuickAddHabitSheet(),
  );
}

class _QuickAddHabitSheet extends StatefulWidget {
  const _QuickAddHabitSheet();

  @override
  State<_QuickAddHabitSheet> createState() => _QuickAddHabitSheetState();
}

class _QuickAddHabitSheetState extends State<_QuickAddHabitSheet> {
  final _nameController = TextEditingController();
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _reminderTime);
    if (picked != null) setState(() => _reminderTime = picked);
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
          Text('New habit', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'e.g. Morning workout'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Remind me'),
            subtitle: const Text('Daily notification for this habit'),
            value: _reminderEnabled,
            onChanged: (v) => setState(() => _reminderEnabled = v),
          ),
          if (_reminderEnabled)
            TextButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.schedule_rounded, size: 16),
              label: Text(_reminderTime.format(context)),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _nameController.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(
                      QuickAddHabitResult(
                        name: _nameController.text.trim(),
                        reminderEnabled: _reminderEnabled,
                        reminderHour: _reminderEnabled ? _reminderTime.hour : null,
                        reminderMinute: _reminderEnabled ? _reminderTime.minute : null,
                      ),
                    ),
              child: const Text('Add habit'),
            ),
          ),
        ],
      ),
    );
  }
}
