import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../application/finance_providers.dart';

class AccountTypeManagementScreen extends ConsumerWidget {
  const AccountTypeManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = ref.watch(accountTypesProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Account types')),
      body: types.isEmpty
          ? const Center(child: Text('No account types yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: types.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final t = types[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Icon(resolveIcon(t.icon))),
                  title: Text(t.name),
                  onTap: () => _openEditor(context, ref, existing: t),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _delete(context, ref, t),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add type'),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref, {AccountType? existing}) async {
    final result = await showModalBottomSheet<_AccountTypeEditorResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AccountTypeEditorSheet(existing: existing),
    );
    if (result == null) return;

    final controller = ref.read(financeControllerProvider);
    if (existing == null) {
      await controller.addAccountType(name: result.name, icon: result.icon);
    } else {
      await controller.updateAccountType(id: existing.id, name: result.name, icon: result.icon);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, AccountType type) async {
    final controller = ref.read(financeControllerProvider);
    final usage = await controller.accountTypeUsageCount(type.name);
    if (!context.mounted) return;

    if (usage > 0) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Can't delete this type"),
          content: Text(
            '${usage == 1 ? '1 account uses' : '$usage accounts use'} this type. Change their type first, or leave it in place.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this account type?'),
        content: Text('"${type.name}" will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteAccountType(type.id);
  }
}

class _AccountTypeEditorResult {
  const _AccountTypeEditorResult({required this.name, required this.icon});

  final String name;
  final String icon;
}

class _AccountTypeEditorSheet extends StatefulWidget {
  const _AccountTypeEditorSheet({this.existing});

  final AccountType? existing;

  @override
  State<_AccountTypeEditorSheet> createState() => _AccountTypeEditorSheetState();
}

class _AccountTypeEditorSheetState extends State<_AccountTypeEditorSheet> {
  late final _nameController = TextEditingController(text: widget.existing?.name);
  late String _icon = widget.existing?.icon ?? pickableIcons.first;

  bool get _isEditing => widget.existing != null;

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
    final theme = Theme.of(context);
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
          Text(_isEditing ? 'Edit account type' : 'New account type', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Type name'),
          ),
          const SizedBox(height: 12),
          Text('Icon', style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in pickableIcons)
                InkWell(
                  onTap: () => setState(() => _icon = name),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _icon == name
                          ? theme.colorScheme.primaryContainer
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _icon == name ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                        width: _icon == name ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      resolveIcon(name),
                      size: 20,
                      color: _icon == name ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _nameController.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(
                      _AccountTypeEditorResult(name: _nameController.text.trim(), icon: _icon),
                    ),
              child: Text(_isEditing ? 'Save changes' : 'Add type'),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
