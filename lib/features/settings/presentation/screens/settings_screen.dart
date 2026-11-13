import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_color_theme.dart';
import '../../../../app/app_restart.dart';
import '../../../../app/transitions/screen_reveal.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/services/demo_data_service.dart';
import '../../../../core/services/app_lock_service.dart';
import '../../../../core/services/backup_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/system_settings.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../app/router/app_sidebar.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_font_style.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/tappable.dart';
import '../../../../core/widgets/initial_well.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/tab_rail.dart';
import '../../../finance/presentation/screens/account_type_management_screen.dart';
import '../../../finance/presentation/screens/category_management_screen.dart';
import '../../application/app_lock_providers.dart';
import '../../application/settings_providers.dart';
import '../widgets/alarm_tone_sheet.dart';
import '../widgets/pin_setup_sheet.dart';
import '../widgets/unlock_method_sheet.dart';
import '../widgets/reminder_status_card.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/route_paths.dart';
import '../../../ai_analyser/application/ai_analyser_providers.dart';
import '../../../sync/application/sync_providers.dart';
import '../../../voice_entry/data/sample_voice_parser.dart';

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
                onChangedAt: (mode, origin) =>
                    _changeThemeMode(context, ref, mode, origin),
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
                  const SizedBox(height: 18),
                  Text('Background', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    'The page colour behind the cards, in light mode.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final background in settings.colorTheme.backgrounds)
                        ChoiceChip(
                          avatar: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: settings.colorTheme.lightBackground(
                                background,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                          ),
                          label: Text(background.label),
                          selected:
                              settings.colorTheme.shown(settings.background) ==
                              background,
                          onSelected: (_) => controller.setBackground(
                            settings.colorTheme.saved(background),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Font', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    'Changes the lettering across the app, straight away.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final style in AppFontStyle.values)
                    _FontStyleRow(
                      style: style,
                      selected: settings.fontStyle == style,
                      onTap: () => controller.setFontStyle(style),
                    ),
                ],
              ),
            ),
          ),

          const _SectionTitle('Motion & feedback'),
          Card(
            child: Column(
              children: [
                const _MotionSettings(),
                const Divider(height: 1),
                _SettingSwitch(
                  icon: LucideIcons.vibrate,
                  title: 'Haptic feedback',
                  subtitle: 'Vibration for interactions and calendar saves',
                  value: settings.hapticsEnabled,
                  onChanged: controller.setHapticsEnabled,
                ),
                const Divider(height: 1),
                _SettingSwitch(
                  icon: LucideIcons.volume2,
                  title: 'Sounds',
                  subtitle:
                      'Ticking off tasks, streaks, goals and budget alerts. '
                      'Silent when your phone is.',
                  value: settings.soundEffectsEnabled,
                  onChanged: controller.setSoundEffectsEnabled,
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
                  subtitle: 'A note at 9 AM when LifeOS finds something new',
                  value: settings.aiInsightAlerts,
                  onChanged: (enabled) async {
                    await controller.setAiInsightAlerts(enabled);
                    if (enabled) {
                      await ref
                          .read(notificationServiceProvider)
                          .requestReminderPermissions();
                    }
                    await ref
                        .read(aiAnalyserControllerProvider)
                        .updateInsightAlert(enabled: enabled);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const _IconWell(LucideIcons.alarmClock),
                  title: const Text('Alarm tone'),
                  subtitle: Text(settings.alarmTone.label),
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: () async {
                    final tone = await showAlarmToneSheet(
                      context,
                      current: settings.alarmTone,
                    );
                    if (tone != null && tone != settings.alarmTone) {
                      await controller.setAlarmTone(tone);
                    }
                  },
                ),
                if (SystemSettings.canOpenNotificationSettings) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const _IconWell(LucideIcons.music),
                    title: const Text('Notification sounds'),
                    subtitle: const Text(
                      "Set each reminder type's sound in Android settings",
                    ),
                    trailing: const Icon(LucideIcons.externalLink, size: 18),
                    onTap: SystemSettings.openNotificationSettings,
                  ),
                ],
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

          const _SectionTitle('Sync'),
          const _SyncRow(),

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
          const _SampleDataRow(),
          if (kDebugMode) ...[
            const _SectionTitle('Developer tools'),
            const _DemoDataCard(),
            const _VoiceTestModeRow(),
          ],

          const _SectionTitle('More'),
          Card(
            child: ListTile(
              leading: const _IconWell(LucideIcons.sparkles),
              title: const Text('Replay the tour'),
              subtitle: const Text('See the tips on Home again'),
              onTap: () async {
                await controller.resetTours();
                if (context.mounted) context.go(RoutePaths.home);
              },
            ),
          ),
          const SizedBox(height: 10),
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
      : AppTheme.light(colorTheme, ref.read(settingsProvider).background);
  final approved = await showDialog<bool>(
    context: context,
    builder: (context) => Theme(
      data: previewTheme,
      child: _ThemePreviewDialog(theme: colorTheme),
    ),
  );
  if (approved != true || !context.mounted) return;

  await ScreenReveal.run(
    style: revealStyleOf(context, ref, RevealStyle.pageTurn),
    // Let the dialog finish closing, or the page that turns away has it on.
    settleFirst: _dialogExit,
    change: () async {
      // Whoever is changing the theme is already in; the restart must not put
      // the lock screen back up.
      final unlocked = !ref.read(isLockedProvider);
      await ref.read(settingsControllerProvider).setColorTheme(colorTheme);
      if (!context.mounted) return;
      if (AppRestartBoundary.restart(context) && unlocked) {
        IsLocked.keepUnlockedThroughRestart();
      }
    },
    // The restart rebuilds everything, so wait for the app to say its first
    // screen is ready rather than for the setting to read back.
    awaitContentReady: true,
  );
}

/// Material's dialog exit transition, plus a frame.
const _dialogExit = Duration(milliseconds: 170);

/// Light/dark via the Appearance rail: the new mode spreads in a circle from
/// the option that was tapped. A choice that doesn't change what's on screen
/// — System while the phone is already in that mode — just applies.
void _changeThemeMode(
  BuildContext context,
  WidgetRef ref,
  ThemeMode mode,
  Offset? origin,
) {
  final controller = ref.read(settingsControllerProvider);
  final phone = MediaQuery.platformBrightnessOf(context);
  Brightness shown(ThemeMode m) => switch (m) {
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
    ThemeMode.system => phone,
  };
  if (shown(mode) == shown(ref.read(settingsProvider).themeMode)) {
    controller.setThemeMode(mode);
    return;
  }
  ScreenReveal.run(
    style: revealStyleOf(context, ref, RevealStyle.circle),
    origin: origin,
    change: () => controller.setThemeMode(mode),
    isApplied: () => ref.read(settingsProvider).themeMode == mode,
  );
}

/// "Animations: Full | Reduced", and — while full — whether the large screen
/// transitions play.
class _MotionSettings extends ConsumerWidget {
  const _MotionSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsControllerProvider);
    // The phone's own setting, not the app-adjusted one in MediaQuery.
    final phoneReduces = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    final reduced = phoneReduces || settings.reduceMotion;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Animations', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                phoneReduces
                    ? "Your phone's Reduce motion is on, so animations stay "
                          'reduced.'
                    : 'Reduced turns every animation into a short fade.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              AppTabRail<bool>(
                value: reduced,
                labels: const {false: 'Full', true: 'Reduced'},
                icons: const {
                  false: LucideIcons.sparkles,
                  true: LucideIcons.minus,
                },
                onChanged: (reduce) {
                  if (phoneReduces) return;
                  controller.setReduceMotion(reduce);
                },
              ),
            ],
          ),
        ),
        if (!reduced) ...[
          const Divider(height: 1),
          _SettingSwitch(
            icon: LucideIcons.wandSparkles,
            title: 'Transition effects',
            subtitle: 'Circle reveals, page turn and sliding tabs',
            value: settings.transitionEffectsEnabled,
            onChanged: controller.setTransitionEffectsEnabled,
          ),
        ],
      ],
    );
  }
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

/// Voice entry without the server: speech is real, the three options are
/// samples. Debug builds only.
class _VoiceTestModeRow extends ConsumerWidget {
  const _VoiceTestModeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(voiceTestModeProvider);
    return Card(
      child: SwitchListTile(
        secondary: const _IconWell(LucideIcons.mic),
        title: const Text('Voice entry test mode'),
        subtitle: const Text(
          'Real speech recognition, sample options — no AI or Supabase needed',
        ),
        value: on,
        onChanged: (v) => ref.read(voiceTestModeProvider.notifier).set(v),
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

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Asks the OS to confirm it's the phone's owner, for changes that would
  /// weaken or switch the lock. Backing out is silent; anything else says why.
  Future<bool> _confirmWithPhoneLock(String reason) async {
    final result = await ref
        .read(appLockServiceProvider)
        .authenticateWithDevice(reason: reason);
    if (result == DeviceAuthResult.success) return true;
    if (result == DeviceAuthResult.lockedOut) {
      _snack('Too many attempts. Try again in a moment.');
    } else if (result != DeviceAuthResult.cancelled) {
      _snack("Couldn't confirm with your phone lock.");
    }
    return false;
  }

  /// Confirms it's the owner with whatever protects the app right now: the PIN
  /// when there is one, otherwise the phone's lock.
  Future<bool> _confirmIdentity({required String reason}) async {
    if (await ref.read(appLockServiceProvider).hasPin()) {
      if (!mounted) return false;
      final ok = await _confirmPin(context);
      if (!ok) _snack('Incorrect PIN');
      return ok;
    }
    return _confirmWithPhoneLock(reason);
  }

  Future<void> _onAppLockChanged(bool enabled) async {
    final controller = ref.read(settingsControllerProvider);
    final service = ref.read(appLockServiceProvider);
    if (enabled) {
      // With a phone lock to use, ask which way; without one the app PIN is the
      // only option, so there's nothing to choose.
      var usePhoneLock = false;
      if (await service.canUseDeviceAuth()) {
        if (!mounted) return;
        final choice = await showUnlockMethodSheet(context);
        if (choice == null) return;
        usePhoneLock = choice == UnlockMethod.phoneLock;
      }
      if (usePhoneLock) {
        // Prove it works before relying on it — otherwise a broken setup would
        // lock the user out of their own data.
        if (!await _confirmWithPhoneLock('Confirm to turn on app lock')) return;
        await controller.setBiometricEnabled(true);
      } else {
        if (!mounted) return;
        final result = await showPinSetupSheet(
          context,
          mode: PinSetupMode.create,
        );
        if (result != true) return;
        ref.invalidate(hasPinProvider);
      }
      await controller.setAppLockEnabled(true);
      // Turning it on mid-session shouldn't immediately lock the user out of the
      // screen they're already on.
      ref.read(isLockedProvider.notifier).unlock();
    } else {
      if (!await _confirmIdentity(reason: 'Confirm to turn off app lock')) {
        return;
      }
      await service.clearPin();
      await controller.setAppLockEnabled(false);
      await controller.setBiometricEnabled(false);
      ref.invalidate(hasPinProvider);
    }
  }

  Future<void> _onPhoneLockChanged(bool enabled) async {
    final controller = ref.read(settingsControllerProvider);
    if (enabled) {
      if (!await _confirmWithPhoneLock('Confirm to use your phone lock')) {
        return;
      }
      await controller.setBiometricEnabled(true);
    } else {
      // Switching it off must leave a way in.
      if (!await ref.read(appLockServiceProvider).hasPin()) {
        _snack('Set an app PIN first, or turn off app lock.');
        return;
      }
      await controller.setBiometricEnabled(false);
    }
  }

  Future<void> _onPinTapped({required bool hasPin}) async {
    final result = await showPinSetupSheet(
      context,
      mode: hasPin ? PinSetupMode.change : PinSetupMode.create,
    );
    if (result == true) ref.invalidate(hasPinProvider);
  }

  Future<void> _onRemovePin() async {
    if (!await _confirmPin(context)) {
      _snack('Incorrect PIN');
      return;
    }
    await ref.read(appLockServiceProvider).clearPin();
    ref.invalidate(hasPinProvider);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final deviceAvailable = ref.watch(canUseDeviceAuthProvider).value ?? false;
    final hasPin = ref.watch(hasPinProvider).value ?? false;

    return Card(
      child: Column(
        children: [
          _SettingSwitch(
            icon: LucideIcons.lockKeyhole,
            title: 'App lock',
            subtitle: 'Require your phone lock or an app PIN to open the app',
            value: settings.appLockEnabled,
            onChanged: _onAppLockChanged,
          ),
          if (settings.appLockEnabled) ...[
            const Divider(height: 1),
            _SettingSwitch(
              icon: LucideIcons.scanFace,
              title: 'Use phone lock',
              subtitle: deviceAvailable
                  ? "Face ID, fingerprint or your phone's passcode"
                  : 'Set a screen lock on your phone first',
              value: settings.biometricEnabled && deviceAvailable,
              onChanged: deviceAvailable ? _onPhoneLockChanged : null,
            ),
            const Divider(height: 1),
            _SettingRow(
              icon: LucideIcons.keyRound,
              title: hasPin ? 'Change PIN' : 'Set app PIN',
              subtitle: hasPin
                  ? null
                  : "A backup way in if your phone lock isn't available",
              onTap: () => _onPinTapped(hasPin: hasPin),
            ),
            // With the phone lock on, the PIN is optional — it can go.
            if (hasPin && settings.biometricEnabled && deviceAvailable) ...[
              const Divider(height: 1),
              _SettingRow(
                icon: LucideIcons.trash2,
                title: 'Remove app PIN',
                onTap: _onRemovePin,
              ),
            ],
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

  /// Above this, the backup isn't loaded into memory to hand to the save
  /// dialog; it's passed as a file to the share sheet instead.
  static const _maxSaveDialogBytes = 150 * 1024 * 1024;

  Future<void> _export() async {
    // Optional: a backup holds every account, transaction and document.
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _BackupPasswordDialog.choose(),
    );
    if (password == null || !mounted) return;

    setState(() => _op = _BackupOp.exporting);
    BackupExport? export;
    try {
      export = await ref
          .read(backupServiceProvider)
          .exportBackupFile(password: password);
      final fileName =
          'lifeos-backup-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.zip';
      final bool saved;
      if (export.sizeBytes <= _maxSaveDialogBytes) {
        final path = await FilePicker.saveFile(
          dialogTitle: 'Save LifeOS backup',
          fileName: fileName,
          bytes: await export.file.readAsBytes(),
        );
        saved = path != null;
      } else {
        // A big document library: send the file itself rather than hold
        // hundreds of megabytes in memory.
        final named = await export.file.rename(
          '${export.file.parent.path}/$fileName',
        );
        final result = await SharePlus.instance.share(
          ShareParams(
            files: [XFile(named.path, mimeType: 'application/zip')],
            subject: 'LifeOS backup',
          ),
        );
        saved = result.status == ShareResultStatus.success;
      }
      if (!mounted) return;
      if (!saved) {
        _showSnack('Export cancelled.');
      } else {
        final missing = export.missingFiles;
        _showSnack(
          missing == 0
              ? 'Backup saved.'
              : 'Backup saved, but $missing document '
                    '${missing == 1 ? 'file isn\'t' : 'files aren\'t'} on this '
                    'phone, so ${missing == 1 ? 'it isn\'t' : 'they aren\'t'} '
                    'in it. Export from the phone that has '
                    '${missing == 1 ? 'it' : 'them'} to include '
                    '${missing == 1 ? 'it' : 'them'}.',
        );
      }
    } catch (e) {
      if (mounted) _showSnack('Could not export backup: $e', isError: true);
    } finally {
      await export?.discard();
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
    final service = ref.read(backupServiceProvider);
    final file = picked.path == null ? null : File(picked.path!);

    String? password;
    if (file != null && await service.isPasswordProtected(file)) {
      if (!mounted) return;
      password = await showDialog<String>(
        context: context,
        builder: (_) => const _BackupPasswordDialog.enter(),
      );
      if (password == null || !mounted) return;
    }
    if (!mounted) return;

    // With sync on, the restore doesn't stop at this phone.
    final syncing = ref.read(syncControllerProvider).phase == SyncPhase.ready;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: Text(
          'This replaces all local data with what\'s in the backup. Older '
          'backups do not include bills, recurring transactions, or custom '
          'account types; those lists will be cleared. Export your current '
          'data first if you want to keep a copy. This can\'t be undone.'
          '${syncing ? '\n\nSync is on, so your other phones will be changed to match this backup too. Anything added since the backup was made will be removed everywhere.' : ''}',
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
      if (file != null) {
        await service.importBackupFile(file, password: password);
      } else {
        await service.importBackup(picked.bytes!, password: password);
      }
      if (mounted) _showSnack('Backup restored.');
    } on BackupPasswordRequired catch (e) {
      if (mounted) {
        _showSnack(
          e.wrong
              ? "That password doesn't open this backup. Nothing was changed."
              : 'This backup is password-protected. Nothing was changed.',
          isError: true,
        );
      }
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

/// Settings → Sync: where sync stands, one tap from its own screen.
class _SyncRow extends ConsumerWidget {
  const _SyncRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncControllerProvider);
    final subtitle = switch (status.phase) {
      SyncPhase.unavailable => 'Not available in this build',
      SyncPhase.signedOut => 'Off — your data is on this device only',
      SyncPhase.checking => 'Checking…',
      SyncPhase.needsSetup => 'Signed in — finish setting up',
      SyncPhase.needsRecoveryKey => 'Signed in — enter your recovery key',
      SyncPhase.ready =>
        status.error != null
            ? 'Waiting to sync'
            : 'On · ${status.email ?? 'signed in'}',
    };
    return Card(
      child: _SettingRow(
        icon: LucideIcons.cloud,
        title: 'Sync & account',
        subtitle: subtitle,
        onTap: () => context.push(RoutePaths.sync),
      ),
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

/// "Remove sample data", once there is some — the welcome screens offer to
/// fill the app with it, so taking it out can't be a debug-only tool.
class _SampleDataRow extends ConsumerStatefulWidget {
  const _SampleDataRow();

  @override
  ConsumerState<_SampleDataRow> createState() => _SampleDataRowState();
}

class _SampleDataRowState extends ConsumerState<_SampleDataRow> {
  bool _has = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(demoDataServiceProvider).hasDemoData.then((has) {
      if (mounted) setState(() => _has = has);
    });
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove sample data?'),
        content: const Text(
          'Takes out the example entries added when you tried LifeOS. '
          'Anything you added yourself stays.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
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
      if (mounted) setState(() => _has = false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_has) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Card(
        child: ListTile(
          leading: const _IconWell(LucideIcons.eraser),
          title: const Text('Remove sample data'),
          subtitle: Text(_busy ? 'Removing…' : 'Clear the example entries'),
          onTap: _busy ? null : _remove,
        ),
      ),
    );
  }
}

/// One font look in Settings → Appearance → Font, drawn in its own faces so
/// it can be judged before it's picked.
class _FontStyleRow extends StatelessWidget {
  const _FontStyleRow({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final AppFontStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tappable(
      selected: selected,
      onTap: onTap,
      haptic: TapHaptic.selection,
      semanticLabel: '${style.label} font. ${style.description}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.tileRadius),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color: selected ? scheme.primary.withValues(alpha: 0.06) : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Text(
                'Ag',
                style: TextStyle(
                  fontFamily: style.headingFamily,
                  fontSize: 26,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    style.label,
                    style: TextStyle(
                      fontFamily: style.headingFamily,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${style.description} · ₹1,250.00',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: style.bodyFamily,
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? LucideIcons.circleCheck : LucideIcons.circle,
              size: 20,
              color: selected ? scheme.primary : scheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks for a backup's password: [choose] when exporting (optional, typed
/// twice — a typo here is a backup nobody can open), [enter] when restoring
/// a protected one. Pops with the password, or an empty string for "no
/// password"; dismissing it pops null.
class _BackupPasswordDialog extends StatefulWidget {
  const _BackupPasswordDialog.choose() : choosing = true;
  const _BackupPasswordDialog.enter() : choosing = false;

  final bool choosing;

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final _password = TextEditingController();
  final _again = TextEditingController();
  bool _hidden = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _again.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _password.text;
    if (widget.choosing && password != _again.text) {
      setState(() => _error = "The two passwords don't match.");
      return;
    }
    if (!widget.choosing && password.isEmpty) {
      setState(() => _error = 'Enter the password for this backup.');
      return;
    }
    Navigator.of(context).pop(password);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final choosing = widget.choosing;
    return AlertDialog(
      title: Text(choosing ? 'Protect this backup?' : 'Backup password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              choosing
                  ? 'A backup holds all your finances and documents. Add a '
                        'password so only you can open it, or leave it empty '
                        'to save it without one. If you forget the password, '
                        'the backup can\'t be opened.'
                  : 'This backup is protected. Enter the password it was '
                        'saved with.',
              style: TextStyle(height: 1.4, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              autofocus: !choosing,
              obscureText: _hidden,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: choosing ? 'Password (optional)' : 'Password',
                errorText: choosing ? null : _error,
                suffixIcon: IconButton(
                  tooltip: _hidden ? 'Show password' : 'Hide password',
                  icon: Icon(_hidden ? LucideIcons.eye : LucideIcons.eyeOff),
                  onPressed: () => setState(() => _hidden = !_hidden),
                ),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: choosing ? null : (_) => _submit(),
            ),
            if (choosing) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _again,
                obscureText: _hidden,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Password again',
                  errorText: _error,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _submit(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(choosing ? 'Export' : 'Continue'),
        ),
      ],
    );
  }
}
