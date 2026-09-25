import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/database/app_database_provider.dart';
import '../core/services/notification_service.dart';
import '../core/services/schedule_coordinator.dart';
import '../features/ai_analyser/application/ai_analyser_providers.dart';
import '../features/finance/application/finance_providers.dart';
import '../features/settings/application/app_lock_providers.dart';
import '../features/settings/application/settings_providers.dart';
import '../features/settings/presentation/screens/lock_screen.dart';
import 'boot_plate.dart';
import 'router/app_router.dart';
import 'splash_gate.dart';
import 'theme/app_theme.dart';

class LifeOSApp extends ConsumerStatefulWidget {
  const LifeOSApp({super.key});

  @override
  ConsumerState<LifeOSApp> createState() => _LifeOSAppState();
}

class _LifeOSAppState extends ConsumerState<LifeOSApp>
    with WidgetsBindingObserver {
  bool? _habitReminderScheduled;
  bool _choresStarted = false;
  bool _launchSettling = false;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter();
    WidgetsBinding.instance.addObserver(this);
    // Touches no database, so it can't get in the way of the settings read.
    ref.read(notificationServiceProvider).init();
  }

  /// Background maintenance, started only once the landing screen is up.
  ///
  /// These all queue work on the one Drift connection, which runs statements
  /// in order. Anywhere earlier and they sit in front of the queries the
  /// screen is waiting on — the AI analyser sweeps every transaction, habit,
  /// task and goal, which on a full database is seconds of blank screen.
  ///
  /// Fire-and-forget: none should block a frame, and none should crash the
  /// app if the tree is torn down (hot restart, app closing) mid-flight.
  void _startBackgroundChores() {
    if (_choresStarted || !mounted) return;
    _choresStarted = true;
    final finance = ref.read(financeRepositoryProvider);
    finance.ensureDefaultCategories();
    finance.ensureDefaultAccountTypes();
    finance.generateDueRecurringTransactions();
    ref.read(scheduleCoordinatorProvider).start();
    ref.read(aiAnalyserControllerProvider).refresh().catchError((_) {});
  }

  /// Releases the native splash once the first screen has its data, then
  /// starts the background chores.
  ///
  /// The landing screen subscribes to its queries while building its first
  /// frame. Drift runs statements in order on one connection, so a no-op
  /// query issued after that frame resolves only once every one of those has
  /// answered — a precise "the screen's data is in" signal, without this
  /// widget having to know which providers the screen uses. It holds equally
  /// for the lock screen or any other landing route.
  void _settleLaunch() {
    if (_launchSettling) return;
    _launchSettling = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(appDatabaseProvider).customSelect('SELECT 1').get();
      } catch (_) {
        // A failed probe shouldn't strand the splash; release regardless.
      }
      if (!mounted) return;
      // The answers reach the widgets a beat after the probe resolves; give
      // them two frames to rebuild before the first one is shown.
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      SplashGate.release();
      _startBackgroundChores();
    });
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
    if (state == AppLifecycleState.resumed) {
      ref.read(scheduleCoordinatorProvider).requestRefresh();
    }
    if (!ref.read(settingsProvider).appLockEnabled) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
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
    // The colour theme is stored in the database, so it isn't known on the
    // first frames; painting the app now would flash the default theme. On a
    // cold start the native splash is held over this, so the plate is only a
    // fallback — seen if launch outlasts SplashGate.maxHold, or during the
    // in-app restart a theme change triggers.
    if (!ref.watch(settingsLoadedProvider)) return const BootPlate();

    _settleLaunch();

    final settings = ref.watch(settingsProvider);
    final themeMode = settings.themeMode;
    _syncHabitReminder(settings.habitReminders);

    final isLocked = ref.watch(isLockedProvider);
    final showLockScreen = settings.appLockEnabled && isLocked;

    return MaterialApp.router(
      title: 'LifeOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(settings.colorTheme),
      darkTheme: AppTheme.dark(settings.colorTheme),
      themeMode: themeMode,
      routerConfig: _router,
      builder: (context, child) {
        if (showLockScreen) return const LockScreen();
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
