import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_color_theme.dart';
import '../../../../app/app_restart.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/services/demo_data_service.dart';
import '../../../../core/services/backup_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../app/router/app_sidebar.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/initial_well.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/tab_rail.dart';
import '../../../finance/presentation/screens/account_type_management_screen.dart';
import '../../../finance/presentation/screens/category_management_screen.dart';
import '../../application/app_lock_providers.dart';
import '../../application/settings_providers.dart';
import '../widgets/pin_setup_sheet.dart';
import '../widgets/reminder_status_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsControllerProvider);

    return Scaffold(
      drawer: const AppSidebar(),
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  InitialWell(
                    color: context.appColors.accentInk,
                    size: 52,
                    radius: AppSpacing.tileRadius,
                    icon: LucideIcons.smartphone,
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
              child: AppTabRail<ThemeMode>(
                value: settings.themeMode,
                labels: const {
                  ThemeMode.light: 'Light',
                  ThemeMode.system: 'System',
                  ThemeMode.dark: 'Dark',
                },
                icons: const {
                  ThemeMode.light: LucideIcons.sun,
                  ThemeMode.system: LucideIcons.monitor,
                  ThemeMode.dark: LucideIcons.moon,
                },
                onChanged: controller.setThemeMode,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Color theme', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    'Changes the app accents and surfaces. Status colors stay consistent.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final colorTheme in AppColorTheme.values)
                        ChoiceChip(
                          avatar: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: colorTheme.previewColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          label: Text(colorTheme.label),
                          selected: settings.colorTheme == colorTheme,
                          onSelected: (_) => _previewAndApplyTheme(
                            context,
                            ref,
                            colorTheme,
                            settings.themeMode,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const _SectionTitle('Touch & feedback'),
          Card(
            child: Column(
              children: [
                _SettingSwitch(
                  icon: LucideIcons.vibrate,
                  title: 'Haptic feedback',
                  subtitle: 'Vibration for interactions and calendar saves',
                  value: settings.hapticsEnabled,
                  onChanged: controller.setHapticsEnabled,
                ),
                const Divider(height: 1),
                _SettingSwitch(
                  icon: LucideIcons.sparkles,
                  title: 'Save feedback',
                  subtitle: 'Show a visual response after a successful save',
                  value:
                      settings.saveAnimationsEnabled ||
                      settings.saveConfirmationsEnabled,
                  onChanged: controller.setSaveFeedbackEnabled,
                ),
                if (settings.saveAnimationsEnabled ||
                    settings.saveConfirmationsEnabled) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose how successful saves are acknowledged.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        AppTabRail<SaveFeedbackMode>(
                          value: settings.saveConfirmationsEnabled
                              ? SaveFeedbackMode.confirmation
                              : SaveFeedbackMode.animation,
                          labels: const {
                            SaveFeedbackMode.animation: 'Animation',
                            SaveFeedbackMode.confirmation: 'Confirmation',
                          },
                          icons: const {
                            SaveFeedbackMode.animation: LucideIcons.sparkles,
                            SaveFeedbackMode.confirmation:
                                LucideIcons.badgeCheck,
                          },
                          onChanged: controller.setSaveFeedbackMode,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const _SectionTitle('Notifications'),
          Card(
            child: Column(
              children: [
                _SettingSwitch(
                  icon: LucideIcons.bellRing,
                  title: 'Task reminders',
                  subtitle: 'Alert before a task is due',
                  value: settings.taskReminders,
                  onChanged: controller.setTaskReminders,
                ),
                const Divider(height: 1),
                _SettingSwitch(
                  icon: LucideIcons.sprout,
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
                  icon: LucideIcons.lightbulb,
                  title: 'AI insight alerts',
                  subtitle: 'Notify when new insights appear',
                  value: settings.aiInsightAlerts,
                  onChanged: controller.setAiInsightAlerts,
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Theme(
              // ExpansionTile draws its own top/bottom rules when open; the
              // card already provides the edge.
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: const ExpansionTile(
                leading: _IconWell(LucideIcons.clock3),
                title: Text('Reminder status'),
                subtitle: Text('Permission and queued alerts'),
                children: [ReminderStatusCard(embedded: true)],
              ),
            ),
          ),
          const _SectionTitle('Finance'),
          Card(
            child: Column(
              children: [
                _SettingRow(
                  icon: LucideIcons.tags,
                  title: 'Categories',
                  subtitle:
                      'Add, edit, or remove transaction/budget categories',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CategoryManagementScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                _SettingRow(
                  icon: LucideIcons.landmark,
                  title: 'Account types',
                  subtitle: 'Add, edit, or remove account types',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AccountTypeManagementScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                _SettingRow(
                  icon: LucideIcons.coins,
                  title: 'Currency',
                  subtitle:
                      '${currencySymbolFor(settings.currencyCode)} · ${settings.currencyCode}',
                  onTap: () =>
                      _pickCurrency(context, ref, settings.currencyCode),
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
              leading: const _IconWell(LucideIcons.cloudOff),
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

Future<void> _previewAndApplyTheme(
  BuildContext context,
  WidgetRef ref,
  AppColorTheme colorTheme,
  ThemeMode displayMode,
) async {
  final platformBrightness = MediaQuery.platformBrightnessOf(context);
  final brightness = switch (displayMode) {
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
    ThemeMode.system => platformBrightness,
  };
  final previewTheme = brightness == Brightness.dark
      ? AppTheme.dark(colorTheme)
      : AppTheme.light(colorTheme);
  final approved = await showDialog<bool>(
    context: context,
    builder: (context) => Theme(
      data: previewTheme,
      child: _ThemePreviewDialog(theme: colorTheme),
    ),
  );
  if (approved != true) return;

  await ref.read(settingsControllerProvider).setColorTheme(colorTheme);
  if (context.mounted) AppRestartBoundary.restart(context);
}

class _ThemePreviewDialog extends StatelessWidget {
  const _ThemePreviewDialog({required this.theme});

  final AppColorTheme theme;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Preview ${theme.label}', style: text.titleLarge),
            const SizedBox(height: 4),
            Text(
              'This is how the app will look with this color theme.',
              style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            _ThemePreviewCanvas(theme: theme),
            const SizedBox(height: 18),
            Text('Apply this theme?', style: text.titleSmall),
            const SizedBox(height: 4),
            Text(
              'The app will restart its interface so every screen uses the new colors.',
              style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Apply & restart'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemePreviewCanvas extends StatelessWidget {
  const _ThemePreviewCanvas({required this.theme});

  final AppColorTheme theme;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      height: 236,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  LucideIcons.sparkles,
                  size: 15,
                  color: colors.onPrimary,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(child: Text('Good morning', style: text.titleSmall)),
              Icon(LucideIcons.bell, size: 17, color: colors.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        LucideIcons.check,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Today’s focus', style: text.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            '2 tasks remaining',
                            style: text.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 7,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('60%', style: text.labelMedium),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _PreviewNavItem(
                icon: LucideIcons.house,
                label: 'Home',
                active: true,
              ),
              _PreviewNavItem(icon: LucideIcons.listChecks, label: 'Plan'),
              _PreviewNavItem(
                icon: LucideIcons.calendarDays,
                label: 'Calendar',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewNavItem extends StatelessWidget {
  const _PreviewNavItem({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = active ? colors.primary : colors.onSurfaceVariant;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Demo data removed.')));
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
            leading: const Icon(LucideIcons.flaskConical),
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
                      icon: const Icon(LucideIcons.trash2),
                      label: const Text('Remove demo data'),
                    )
                  : FilledButton.icon(
                      onPressed: _busy || hasDemoData == null
                          ? null
                          : _generate,
                      icon: const Icon(LucideIcons.sparkles),
                      label: const Text('Generate demo data'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _pickCurrency(
  BuildContext context,
  WidgetRef ref,
  String currentCode,
) async {
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
                  const Icon(LucideIcons.check, size: 18),
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
      final result = await showPinSetupSheet(
        context,
        mode: PinSetupMode.create,
      );
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
            icon: LucideIcons.lockKeyhole,
            title: 'App lock',
            subtitle: 'Require a PIN or biometrics to open the app',
            value: settings.appLockEnabled,
            onChanged: _onAppLockChanged,
          ),
          if (settings.appLockEnabled) ...[
            const Divider(height: 1),
            _SettingRow(
              icon: LucideIcons.keyRound,
              title: 'Change PIN',
              onTap: _onChangePin,
            ),
            const Divider(height: 1),
            _SettingSwitch(
              icon: LucideIcons.scanFace,
              title: 'Use biometrics',
              subtitle: canUseBiometrics
                  ? 'Unlock with Face ID or fingerprint'
                  : 'Not available on this device',
              value: settings.biometricEnabled && canUseBiometrics,
              onChanged: canUseBiometrics
                  ? controller.setBiometricEnabled
                  : null,
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
      final fileName =
          'lifeos-backup-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.zip';
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
          'This replaces all local data with what\'s in the backup. Older backups do not include bills, recurring transactions, or custom account types; those lists will be cleared. Export your current data first if you want to keep a copy. This can\'t be undone.',
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
          _SettingRow(
            icon: LucideIcons.upload,
            title: 'Export data',
            subtitle: 'Save everything as a backup file',
            trailing: _op == _BackupOp.exporting
                ? const _MiniSpinner()
                : const Icon(LucideIcons.chevronRight),
            onTap: busy ? null : _export,
          ),
          const Divider(height: 1),
          _SettingRow(
            icon: LucideIcons.download,
            title: 'Import data',
            subtitle: 'Restore from a backup file',
            trailing: _op == _BackupOp.importing
                ? const _MiniSpinner()
                : const Icon(LucideIcons.chevronRight),
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
      padding: const EdgeInsets.fromLTRB(6, 26, 6, 10),
      child: Overline(title),
    );
  }
}

/// The 40px accent well that leads every settings row, so each group scans
/// as a list of like items rather than bare text.
class _IconWell extends StatelessWidget {
  const _IconWell(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InitialWell(
      color: context.appColors.accentInk,
      size: 40,
      radius: AppSpacing.iconButtonRadius,
      icon: icon,
    );
  }
}

/// A tappable settings row: icon well, title, optional subtitle, and a chevron
/// unless the caller supplies its own trailing (e.g. a busy spinner).
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: _IconWell(icon),
      title: Text(title, style: theme.textTheme.bodyMedium),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: trailing ?? const Icon(LucideIcons.chevronRight, size: 18),
      onTap: onTap,
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData? icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: icon == null ? null : _IconWell(icon!),
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
