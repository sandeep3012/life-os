import 'package:flutter/material.dart';

class QuickAddAccountResult {
  const QuickAddAccountResult({
    required this.name,
    required this.type,
    required this.startingBalanceMinor,
  });

  final String name;
  final String type;
  final int startingBalanceMinor;
}

const _accountTypes = [
  ('checking', 'Checking'),
  ('savings', 'Savings'),
  ('credit_card', 'Credit Card'),
  ('cash', 'Cash'),
  ('investment', 'Investment'),
];

Future<QuickAddAccountResult?> showQuickAddAccountSheet(BuildContext context) {
  return showModalBottomSheet<QuickAddAccountResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _QuickAddAccountSheet(),
  );
}

class _QuickAddAccountSheet extends StatefulWidget {
  const _QuickAddAccountSheet();

  @override
  State<_QuickAddAccountSheet> createState() => _QuickAddAccountSheetState();
}

class _QuickAddAccountSheetState extends State<_QuickAddAccountSheet> {
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  String _type = _accountTypes.first.$1;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
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
          Text('New account', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Account name'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (value, label) in _accountTypes)
                ChoiceChip(
                  label: Text(label),
                  selected: _type == value,
                  onSelected: (_) => setState(() => _type = value),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _balanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Starting balance (₹)'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _nameController.text.trim().isEmpty
                  ? null
                  : () {
                      final rupees = double.tryParse(_balanceController.text.trim()) ?? 0;
                      Navigator.of(context).pop(
                        QuickAddAccountResult(
                          name: _nameController.text.trim(),
                          type: _type,
                          startingBalanceMinor: (rupees * 100).round(),
                        ),
                      );
                    },
              child: const Text('Add account'),
            ),
          ),
        ],
      ),
    );
  }
}
