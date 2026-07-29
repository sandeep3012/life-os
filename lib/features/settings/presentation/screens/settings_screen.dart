import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/backup_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../finance/presentation/screens/account_type_management_screen.dart';
import '../../../finance/presentation/screens/category_management_screen.dart';
import '../../application/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('This device', style: theme.textTheme.titleSmall),
                        Text(
                          'Everything is stored locally — sync coming later',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const _SectionTitle('Appearance'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                  ButtonSegment(value: ThemeMode.system, label: Text('System')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (selection) =>
                    controller.setThemeMode(selection.first),
              ),
            ),
          ),

          const _SectionTitle('Notifications'),
          Card(
            child: Column(
              children: [
                _SettingSwitch(
                  title: 'Task reminders',
                  subtitle: 'Alert before a task is due',
                  value: settings.taskReminders,
                  onChanged: controller.setTaskReminders,
                ),
                const Divider(height: 1),
                _SettingSwitch(
                  title: 'Habit reminders',
                  subtitle: 'Daily nudge for habits not yet logged',
                  value: settings.habitReminders,
                  onChanged: (enabled) async {
                    await controller.setHabitReminders(enabled);
                    final notifications = ref.read(notificationServiceProvider);
                    if (enabled) {
                      await notifications.scheduleDailyHabitReminder();
                    } else {
                      await notifications.cancelDailyHabitReminder();
                    }
                  },
                ),
                const Divider(height: 1),
                _SettingSwitch(
                  title: 'AI insight alerts',
                  subtitle: 'Notify when new insights appear',
                  value: settings.aiInsightAlerts,
                  onChanged: controller.setAiInsightAlerts,
                ),
              ],
            ),
          ),

          const _SectionTitle('Finance'),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Categories'),
                  subtitle: const Text('Add, edit, or remove transaction/budget categories'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Account types'),
                  subtitle: const Text('Add, edit, or remove account types'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AccountTypeManagementScreen()),
                  ),
                ),
              ],
            ),
          ),

          const _SectionTitle('Data'),
          const _BackupCard(),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Text(
              'Export includes every module and your saved documents. Importing replaces all data currently on this device.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          const _SectionTitle('More'),
          Card(
            child: ListTile(
              title: const Text('Multi-device sync'),
              subtitle: const Text('Not available yet'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'Soon',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupCard extends ConsumerStatefulWidget {
  const _BackupCard();

  @override
  ConsumerState<_BackupCard> createState() => _BackupCardState();
}

enum _BackupOp { none, exporting, importing }

class _BackupCardState extends ConsumerState<_BackupCard> {
  _BackupOp _op = _BackupOp.none;

  Future<void> _export() async {
    setState(() => _op = _BackupOp.exporting);
    try {
      final bytes = await ref.read(backupServiceProvider).exportBackup();
      final fileName = 'lifeos-backup-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.zip';
      final path = await FilePicker.saveFile(
        dialogTitle: 'Save LifeOS backup',
        fileName: fileName,
        bytes: bytes,
      );
      if (!mounted) return;
      if (path == null) {
        _showSnack('Export cancelled.');
      } else {
        _showSnack('Backup saved.');
      }
    } catch (e) {
      if (mounted) _showSnack('Could not export backup: $e', isError: true);
    } finally {
      if (mounted) setState(() => _op = _BackupOp.none);
    }
  }

  Future<void> _import() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final picked = result?.files.single;
    if (picked == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: const Text(
          'This replaces every task, habit, note, transaction, and document currently on this device with what\'s in the backup. This can\'t be undone.',
        ),
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
            child: const Text('Replace data'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _op = _BackupOp.importing);
    try {
      final bytes = picked.bytes ?? await File(picked.path!).readAsBytes();
      await ref.read(backupServiceProvider).importBackup(bytes);
      if (mounted) _showSnack('Backup restored.');
    } on InvalidBackupException catch (e) {
      if (mounted) _showSnack(e.message, isError: true);
    } catch (e) {
      if (mounted) _showSnack('Could not restore backup: $e', isError: true);
    } finally {
      if (mounted) setState(() => _op = _BackupOp.none);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _op != _BackupOp.none;
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text('Export data'),
            subtitle: const Text('Save everything as a backup file'),
            trailing: _op == _BackupOp.exporting
                ? const _MiniSpinner()
                : const Icon(Icons.chevron_right_rounded),
            onTap: busy ? null : _export,
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Import data'),
            subtitle: const Text('Restore from a backup file'),
            trailing: _op == _BackupOp.importing
                ? const _MiniSpinner()
                : const Icon(Icons.chevron_right_rounded),
            onTap: busy ? null : _import,
          ),
        ],
      ),
    );
  }
}

class _MiniSpinner extends StatelessWidget {
  const _MiniSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
