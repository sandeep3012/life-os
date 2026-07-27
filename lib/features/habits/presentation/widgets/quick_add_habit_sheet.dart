import 'package:flutter/material.dart';

Future<String?> showQuickAddHabitSheet(BuildContext context) {
  return showModalBottomSheet<String>(
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _nameController.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(_nameController.text.trim()),
              child: const Text('Add habit'),
            ),
          ),
        ],
      ),
    );
  }
}
