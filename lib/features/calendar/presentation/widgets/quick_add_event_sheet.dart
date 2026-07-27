import 'package:flutter/material.dart';

class QuickAddEventResult {
  const QuickAddEventResult({required this.title, required this.startTime});

  final String title;
  final DateTime startTime;
}

Future<QuickAddEventResult?> showQuickAddEventSheet(
  BuildContext context, {
  required DateTime initialDate,
}) {
  return showModalBottomSheet<QuickAddEventResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _QuickAddEventSheet(initialDate: initialDate),
  );
}

class _QuickAddEventSheet extends StatefulWidget {
  const _QuickAddEventSheet({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_QuickAddEventSheet> createState() => _QuickAddEventSheetState();
}

class _QuickAddEventSheetState extends State<_QuickAddEventSheet> {
  final _titleController = TextEditingController();
  late TimeOfDay _time = TimeOfDay.now();

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

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
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
          Text('New event', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Event title'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _pickTime,
            icon: const Icon(Icons.access_time_rounded, size: 16),
            label: Text(_time.format(context)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _titleController.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(
                      QuickAddEventResult(
                        title: _titleController.text.trim(),
                        startTime: DateTime(
                          widget.initialDate.year,
                          widget.initialDate.month,
                          widget.initialDate.day,
                          _time.hour,
                          _time.minute,
                        ),
                      ),
                    ),
              child: const Text('Add event'),
            ),
          ),
        ],
      ),
    );
  }
}
