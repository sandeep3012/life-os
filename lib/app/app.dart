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
import 'launch/launch_splash.dart';
import 'launch_timeline.dart';
import 'router/app_router.dart';
import 'splash_gate.dart';
import 'theme/app_theme.dart';
import 'transitions/screen_reveal.dart';

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

  /// Process-wide, so only the cold start plays the animation: the in-app
  /// restart that applies a theme change remounts this widget and must not
  /// replay it.
  static bool _launchPlayed = false;
  late final bool _playLaunch = SplashGate.coldStart && !_launchPlayed;
  late bool _launchDone = !_playLaunch;
  bool _dataReady = false;
  // The splash has started fading, so the app underneath may paint and
  // animate. Until then it's built but offstage with its tickers paused —
  // otherwise Home repaints on every stream update and plays its entrance
  // animation unseen, both stealing frames from the launch animation.
  late bool _appRevealed = !_playLaunch;
  final _appKey = GlobalKey(debugLabel: 'app');
  final _splashKey = GlobalKey(debugLabel: 'launch splash');
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter();
    WidgetsBinding.instance.addObserver(this);
    // Touches no database, so it can't get in the way of the settings read.
    ref.read(notificationServiceProvider).init();
    if (_playLaunch) _launchPlayed = true;
  }

  void _onLaunchFinished() {
    if (!mounted) return;
    setState(() => _launchDone = _appRevealed = true);
    LaunchTimeline.mark('launch animation finished');
    _startBackgroundChores();
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
    LaunchTimeline.mark('background chores started');
    ref
        .read(aiAnalyserControllerProvider)
        .refresh()
        .then((_) => LaunchTimeline.mark('AI analyser finished'))
        .catchError((_) {});
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
      LaunchTimeline.mark('landing screen built, waiting on its queries');
      try {
        await ref.read(appDatabaseProvider).customSelect('SELECT 1').get();
      } catch (_) {
        // A failed probe shouldn't strand the splash; release regardless.
      }
      LaunchTimeline.mark('landing screen queries answered');
      if (!mounted) return;
      // The answers reach the widgets a beat after the probe resolves; give
      // them two frames to rebuild before the first one is shown.
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      if (_playLaunch) {
        // The animation finishes its current item and fades; chores start
        // after it, so they can't make it stutter.
        setState(() => _dataReady = true);
      } else {
        SplashGate.release();
        // A colour theme change restarts into here; its page turn is waiting
        // for this screen to be ready before it uncovers it.
        ScreenReveal.contentReady();
        _startBackgroundChores();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-locks when the app comes back after a while in the background — see
  /// [RelockPolicy]. Without this "app lock" would protect nothing once the
  /// app had been opened once; locking the instant it leaves the foreground
  /// instead asked for the PIN after every quick app switch.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(scheduleCoordinatorProvider).requestRefresh();
    }
    if (!ref.read(settingsProvider).appLockEnabled) return;
    final policy = ref.read(relockPolicyProvider);
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        // The phone's own Face ID / fingerprint / passcode screen also sends
        // the app here; that's the unlock happening, not the user leaving.
        if (ref.read(appLockServiceProvider).isAuthenticating) return;
        policy.left();
      case AppLifecycleState.resumed:
        if (policy.returned()) ref.read(isLockedProvider.notifier).lock();
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        // Inactive is the notification shade, Control Centre, the app
        // switcher, an incoming call banner — the app hasn't been left.
        break;
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
    // first frames; painting the app then would flash the default theme. On a
    // cold start the launch animation covers that time (and Home's data
    // loading); otherwise — the in-app restart a theme change triggers — the
    // boot plate does.
    final Widget app;
    if (!ref.watch(settingsLoadedProvider)) {
      // Under the launch animation nothing needs to show yet; without it,
      // the plate keeps the default theme from ever being painted.
      app = _playLaunch ? const SizedBox.shrink() : const BootPlate();
    } else {
      app = _buildApp();
    }
    // One stable tree shape for the whole launch: the app keeps its state
    // when the splash above it is removed, and the splash keeps its place
    // (and its animation) when the app underneath switches from a
    // placeholder to the real thing.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          KeyedSubtree(
            key: _appKey,
            child: Offstage(
              offstage: !_appRevealed,
              child: TickerMode(enabled: _appRevealed, child: app),
            ),
          ),
          if (!_launchDone)
            KeyedSubtree(
              key: _splashKey,
              // It sits above MaterialApp, so it brings its own MediaQuery.
              child: MediaQuery.fromView(
                view: View.of(context),
                child: LaunchSplash(
                  ready: _dataReady,
                  onLeaving: () => setState(() => _appRevealed = true),
                  onFinished: _onLaunchFinished,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildApp() {
    LaunchTimeline.mark('settings loaded, building app');

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
      // Under a reveal the new theme must be final the moment it's uncovered;
      // blending it in would show the circle sweeping half-changed colours.
      themeAnimationDuration: ScreenReveal.isActive
          ? Duration.zero
          : kThemeAnimationDuration,
      routerConfig: _router,
      builder: (context, child) {
        // "Animations: Reduced" works by telling every widget below what the
        // phone's own reduce-motion setting would — so AppMotion.of, and
        // anything else that reads it, follows without per-screen wiring.
        // Always wrapped, even when off, so toggling it doesn't reparent (and
        // reset) the whole app.
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            disableAnimations: media.disableAnimations || settings.reduceMotion,
          ),
          child: showLockScreen
              ? const LockScreen()
              : child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
