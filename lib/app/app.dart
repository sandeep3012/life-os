import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/notification_service.dart';
import '../features/ai_analyser/application/ai_analyser_providers.dart';
import '../features/calendar/application/calendar_providers.dart';
import '../features/finance/application/finance_providers.dart';
import '../features/settings/application/app_lock_providers.dart';
import '../features/settings/application/settings_providers.dart';
import '../features/settings/presentation/screens/lock_screen.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class LifeOSApp extends ConsumerStatefulWidget {
  const LifeOSApp({super.key});

  @override
  ConsumerState<LifeOSApp> createState() => _LifeOSAppState();
}

class _LifeOSAppState extends ConsumerState<LifeOSApp> with WidgetsBindingObserver {
  bool? _habitReminderScheduled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Fire-and-forget: none of these should block first frame, and none
    // should crash the app if the widget tree is torn down (e.g. hot
    // restart, or the app closing) while they're still in flight.
    ref.read(notificationServiceProvider).init();
    ref.read(financeRepositoryProvider).ensureDefaultCategories();
    ref.read(financeRepositoryProvider).ensureDefaultAccountTypes();
    ref.read(financeRepositoryProvider).generateDueRecurringTransactions();
    ref.read(calendarRepositoryProvider).extendRecurringEvents();
    ref.read(aiAnalyserControllerProvider).refresh().catchError((_) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-locks the moment the app leaves the foreground — otherwise "app
  /// lock" wouldn't actually protect anything once the app has been opened
  /// once in a session.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!ref.read(settingsProvider).appLockEnabled) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      ref.read(isLockedProvider.notifier).lock();
    }
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

    final isLocked = ref.watch(isLockedProvider);
    final showLockScreen = settings.appLockEnabled && isLocked;

    return MaterialApp.router(
      title: 'LifeOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: appRouter,
      builder: (context, child) {
        if (showLockScreen) return const LockScreen();
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
