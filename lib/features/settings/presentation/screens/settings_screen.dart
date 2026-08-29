import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/demo_data_service.dart';
import '../../../../core/services/backup_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../finance/presentation/screens/account_type_management_screen.dart';
import '../../../finance/presentation/screens/category_management_screen.dart';
import '../../application/app_lock_providers.dart';
import '../../application/settings_providers.dart';
import '../widgets/pin_setup_sheet.dart';

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
                const Divider(height: 1),
                ListTile(
                  title: const Text('Currency'),
                  subtitle: Text('${currencySymbolFor(settings.currencyCode)} · ${settings.currencyCode}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pickCurrency(context, ref, settings.currencyCode),
                ),
              ],
            ),
          ),

          const _SectionTitle('Security'),
          const _SecuritySection(),

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
          if (kDebugMode) ...[
            const _SectionTitle('Developer tools'),
            const _DemoDataCard(),
          ],

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

class _DemoDataCard extends ConsumerStatefulWidget {
  const _DemoDataCard();

  @override
  ConsumerState<_DemoDataCard> createState() => _DemoDataCardState();
}

class _DemoDataCardState extends ConsumerState<_DemoDataCard> {
  bool _busy = false;
  bool? _hasDemoData;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final value = await ref.read(demoDataServiceProvider).hasDemoData;
    if (mounted) setState(() => _hasDemoData = value);
  }

  Future<void> _generate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate demo data?'),
        content: const Text(
          'This adds 24 months of synthetic finance, habit, task, goal, '
          'calendar, and note history. Your existing data will not be changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final result = await ref.read(demoDataServiceProvider).generate();
      if (!mounted) return;
      setState(() => _hasDemoData = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${result.transactions} transactions, '
            '${result.habitLogs} habit check-ins, ${result.tasks} tasks, '
            'and ${result.events} events.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate demo data: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove demo data?'),
        content: const Text(
          'Only synthetic records created by the demo generator will be '
          'removed. Your own records will remain untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(demoDataServiceProvider).remove();
      if (!mounted) return;
      setState(() => _hasDemoData = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo data removed.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove demo data: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDemoData = _hasDemoData;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: const Text('Demo history'),
            subtitle: Text(
              hasDemoData == null
                  ? 'Checking demo data…'
                  : hasDemoData
                      ? '24 months of removable synthetic data is installed'
                      : 'Add 24 months of synthetic data to explore the app',
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: hasDemoData == true
                  ? OutlinedButton.icon(
                      onPressed: _busy ? null : _remove,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Remove demo data'),
                    )
                  : FilledButton.icon(
                      onPressed: _busy || hasDemoData == null ? null : _generate,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Generate demo data'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _pickCurrency(BuildContext context, WidgetRef ref, String currentCode) async {
  final picked = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Currency'),
      children: [
        for (final option in supportedCurrencies)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(option.code),
            child: Row(
              children: [
                SizedBox(width: 32, child: Text(option.symbol)),
                Expanded(child: Text('${option.label} (${option.code})')),
                if (option.code == currentCode)
                  const Icon(Icons.check_rounded, size: 18),
              ],
            ),
          ),
      ],
    ),
  );
  if (picked != null) {
    await ref.read(settingsControllerProvider).setCurrencyCode(picked);
  }
}

class _SecuritySection extends ConsumerStatefulWidget {
  const _SecuritySection();

  @override
  ConsumerState<_SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends ConsumerState<_SecuritySection> {
  Future<bool> _confirmPin(BuildContext context) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter your PIN'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'PIN'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    return ref.read(appLockServiceProvider).verifyPin(controller.text.trim());
  }

  Future<void> _onAppLockChanged(bool enabled) async {
    final controller = ref.read(settingsControllerProvider);
    if (enabled) {
      final result = await showPinSetupSheet(context, mode: PinSetupMode.create);
      if (result != true) return;
      await controller.setAppLockEnabled(true);
      // Setting a PIN mid-session shouldn't immediately lock the user out
      // of the screen they're already on.
      ref.read(isLockedProvider.notifier).unlock();
    } else {
      final ok = await _confirmPin(context);
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
        }
        return;
      }
      await ref.read(appLockServiceProvider).clearPin();
      await controller.setAppLockEnabled(false);
      await controller.setBiometricEnabled(false);
    }
  }

  Future<void> _onChangePin() async {
    await showPinSetupSheet(context, mode: PinSetupMode.change);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final canUseBiometrics = ref.watch(canUseBiometricsProvider).value ?? false;
    final controller = ref.read(settingsControllerProvider);

    return Card(
      child: Column(
        children: [
          _SettingSwitch(
            title: 'App lock',
            subtitle: 'Require a PIN or biometrics to open the app',
            value: settings.appLockEnabled,
            onChanged: _onAppLockChanged,
          ),
          if (settings.appLockEnabled) ...[
            const Divider(height: 1),
            ListTile(
              title: const Text('Change PIN'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _onChangePin,
            ),
            const Divider(height: 1),
            _SettingSwitch(
              title: 'Use biometrics',
              subtitle: canUseBiometrics
                  ? 'Unlock with Face ID or fingerprint'
                  : 'Not available on this device',
              value: settings.biometricEnabled && canUseBiometrics,
              onChanged: canUseBiometrics ? controller.setBiometricEnabled : null,
            ),
          ],
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
  final ValueChanged<bool>? onChanged;

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
