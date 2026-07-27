import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';

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
  });

  final String title;
  final String type;
  final double? targetValue;
  final LinkOption? link;
}

Future<QuickAddGoalResult?> showQuickAddGoalSheet(
  BuildContext context, {
  required List<Habit> habits,
  required List<Account> accounts,
}) {
  final linkOptions = [
    for (final h in habits) LinkOption(type: 'habit', id: h.id, label: h.name),
    for (final a in accounts) LinkOption(type: 'account', id: a.id, label: a.name),
  ];
  return showModalBottomSheet<QuickAddGoalResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _QuickAddGoalSheet(linkOptions: linkOptions),
  );
}

class _QuickAddGoalSheet extends StatefulWidget {
  const _QuickAddGoalSheet({required this.linkOptions});

  final List<LinkOption> linkOptions;

  @override
  State<_QuickAddGoalSheet> createState() => _QuickAddGoalSheetState();
}

class _QuickAddGoalSheetState extends State<_QuickAddGoalSheet> {
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  String _type = 'generic';
  LinkOption? _link;

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
          Text('New goal', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            autofocus: true,
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
                      ),
                    ),
              child: const Text('Add goal'),
            ),
          ),
        ],
      ),
    );
  }
}
