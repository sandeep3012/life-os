import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/icon_lookup.dart';

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

Future<QuickAddAccountResult?> showQuickAddAccountSheet(
  BuildContext context, {
  required List<AccountType> accountTypes,
  required String currencySymbol,
  Account? initial,
}) {
  return showModalBottomSheet<QuickAddAccountResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _QuickAddAccountSheet(accountTypes: accountTypes, currencySymbol: currencySymbol, initial: initial),
  );
}

class _QuickAddAccountSheet extends StatefulWidget {
  const _QuickAddAccountSheet({required this.accountTypes, required this.currencySymbol, this.initial});

  final List<AccountType> accountTypes;
  final String currencySymbol;
  final Account? initial;

  @override
  State<_QuickAddAccountSheet> createState() => _QuickAddAccountSheetState();
}

class _QuickAddAccountSheetState extends State<_QuickAddAccountSheet> {
  late final _nameController = TextEditingController(text: widget.initial?.name);
  late final _balanceController = TextEditingController(
    text: widget.initial == null ? '' : (widget.initial!.balanceMinor / 100).toStringAsFixed(2),
  );
  late String _type = widget.initial?.type ?? (widget.accountTypes.isEmpty ? '' : widget.accountTypes.first.name);

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
          Text(widget.initial == null ? 'New account' : 'Edit account', style: Theme.of(context).textTheme.titleLarge),
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
              for (final t in widget.accountTypes)
                ChoiceChip(
                  avatar: IconOrEmoji(value: t.icon, size: 16),
                  label: Text(t.name),
                  selected: _type == t.name,
                  onSelected: (_) => setState(() => _type = t.name),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _balanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(hintText: 'Balance (${widget.currencySymbol})'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _nameController.text.trim().isEmpty || _type.isEmpty
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
              child: Text(widget.initial == null ? 'Add account' : 'Save changes'),
            ),
          ),
        ],
      ),
    );
  }
}
