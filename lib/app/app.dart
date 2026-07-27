import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/notification_service.dart';
import '../features/ai_analyser/application/ai_analyser_providers.dart';
import '../features/finance/application/finance_providers.dart';
import '../features/settings/application/settings_providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class LifeManagerApp extends ConsumerStatefulWidget {
  const LifeManagerApp({super.key});

  @override
  ConsumerState<LifeManagerApp> createState() => _LifeManagerAppState();
}

class _LifeManagerAppState extends ConsumerState<LifeManagerApp> {
  bool? _habitReminderScheduled;

  @override
  void initState() {
    super.initState();
    // Fire-and-forget: none of these should block first frame, and none
    // should crash the app if the widget tree is torn down (e.g. hot
    // restart, or the app closing) while they're still in flight.
    ref.read(notificationServiceProvider).init();
    ref.read(financeRepositoryProvider).ensureDefaultCategories();
    ref.read(aiAnalyserControllerProvider).refresh().catchError((_) {});
  }

  /// Keeps the recurring habit reminder in sync with its setting. Driven off
  /// the settings stream rather than initState because the stored value
  /// isn't available on the first frame — reading it too early would
  /// re-enable a reminder the user had switched off. Deferred to after the
  /// frame so it never runs as a side effect of build itself.
  void _syncHabitReminder(bool enabled) {
    if (_habitReminderScheduled == enabled) return;
    _habitReminderScheduled = enabled;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifications = ref.read(notificationServiceProvider);
      if (enabled) {
        notifications.scheduleDailyHabitReminder();
      } else {
        notifications.cancelDailyHabitReminder();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final themeMode = settings.themeMode;
    _syncHabitReminder(settings.habitReminders);

    return MaterialApp.router(
      title: 'LifeOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
