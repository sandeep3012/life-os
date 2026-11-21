import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_color_theme.dart';
import '../../../app/theme/app_font_style.dart';
import '../../settings/application/settings_providers.dart';
import '../../sync/application/sync_providers.dart';
import '../data/plan_backend.dart';
import '../domain/plan.dart';

final planBackendProvider = Provider<PlanBackend?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabasePlanBackend(client);
});

final planCacheProvider = Provider<PlanCache>((ref) => SecurePlanCache());

/// Where the app stands on someone's plan.
enum PlanStatus {
  /// Nobody is signed in: the free plan. A subscription belongs to an
  /// account, as sync and voice entry do.
  signedOut,

  /// Signed in, and the server hasn't answered yet (and never has on this
  /// phone). Nothing is taken away while it's unknown.
  checking,

  /// The server's answer, or its last one within [PlanController.trustFor].
  known,
}

@immutable
class PlanState {
  const PlanState({required this.status, this.plan = AppPlan.free});

  final PlanStatus status;
  final AppPlan plan;

  bool get isPlus => status == PlanStatus.known && plan == AppPlan.plus;

  /// Whether [feature] is unlocked. Sync and voice are decided by the
  /// server each time they're used; this is for what the app itself draws
  /// or offers. While the plan is still being checked for a signed-in
  /// account, the looks stay as they are rather than flickering to the
  /// free ones.
  bool allows(PlusFeature feature) => switch (status) {
    PlanStatus.signedOut => false,
    PlanStatus.checking =>
      feature == PlusFeature.themes || feature == PlusFeature.fonts,
    PlanStatus.known => plan == AppPlan.plus,
  };
}

final planControllerProvider = NotifierProvider<PlanController, PlanState>(
  PlanController.new,
);

/// Follows sign-in and keeps the plan current: asks the server on launch,
/// on return to the app and on sign-in, and remembers the answer so being
/// offline doesn't take Plus away.
class PlanController extends Notifier<PlanState> {
  /// How long a remembered "Plus" is trusted without the server confirming
  /// it. Long enough for a trip without signal; short enough that a
  /// cancelled subscription doesn't keep its looks for ever by staying
  /// offline.
  static const trustFor = Duration(days: 14);

  StreamSubscription<String?>? _signIns;
  bool _started = false;
  int _generation = 0;

  @override
  PlanState build() {
    ref.onDispose(() => _signIns?.cancel());
    final session = ref.read(syncSessionProvider);
    return PlanState(
      status: session?.userId == null
          ? PlanStatus.signedOut
          : PlanStatus.checking,
    );
  }

  /// Called once the app is up.
  Future<void> start() async {
    final session = ref.read(syncSessionProvider);
    if (_started || session == null) return;
    _started = true;
    _signIns = session.userIdChanges.listen((_) => unawaited(refresh()));
    await refresh();
  }

  /// After the store has confirmed a purchase: asks the server until it
  /// agrees. The store tells the server itself, which takes a moment, so
  /// the first answer is often still "free". True once the account has Plus.
  Future<bool> refreshUntilPlus({
    int tries = 10,
    Duration every = const Duration(seconds: 2),
  }) async {
    for (var i = 0; i < tries; i++) {
      if (i > 0) await Future<void>.delayed(every);
      if (!ref.mounted) return false;
      await refresh();
      if (!ref.mounted) return false;
      if (state.isPlus) return true;
    }
    return false;
  }

  /// Reads the remembered plan, then asks the server.
  Future<void> refresh() async {
    final generation = ++_generation;
    final userId = ref.read(syncSessionProvider)?.userId;
    if (userId == null) {
      state = const PlanState(status: PlanStatus.signedOut);
      return;
    }
    final cache = ref.read(planCacheProvider);
    final backend = ref.read(planBackendProvider);

    final remembered = await cache.read(userId);
    if (!ref.mounted || generation != _generation) return;
    if (remembered != null) {
      final fresh =
          DateTime.now().difference(remembered.checkedAt).abs() <= trustFor;
      state = PlanState(
        status: PlanStatus.known,
        // A remembered "free" is always believed; "Plus" only while fresh.
        plan: remembered.plus && fresh ? AppPlan.plus : AppPlan.free,
      );
    } else if (state.status != PlanStatus.known) {
      state = const PlanState(status: PlanStatus.checking);
    }

    if (backend == null) return;
    try {
      final plus = await backend.hasPlus();
      if (!ref.mounted || generation != _generation) return;
      state = PlanState(
        status: PlanStatus.known,
        plan: plus ? AppPlan.plus : AppPlan.free,
      );
      await cache.write(
        userId,
        CachedPlan(plus: plus, checkedAt: DateTime.now()),
      );
    } on Object {
      // Offline: whatever was remembered stands.
    }
  }
}

/// The colour theme to draw: the chosen one if the plan includes it,
/// otherwise the free one. The choice itself is kept, so it comes back the
/// moment Plus does.
final effectiveColorThemeProvider = Provider<AppColorTheme>((ref) {
  final chosen = ref.watch(settingsProvider.select((s) => s.colorTheme));
  final allowed = ref.watch(
    planControllerProvider.select((p) => p.allows(PlusFeature.themes)),
  );
  return chosen.isPlus && !allowed ? freeColorTheme : chosen;
});

/// The font style to draw, on the same rule.
final effectiveFontStyleProvider = Provider<AppFontStyle>((ref) {
  final chosen = ref.watch(settingsProvider.select((s) => s.fontStyle));
  final allowed = ref.watch(
    planControllerProvider.select((p) => p.allows(PlusFeature.fonts)),
  );
  return chosen.isPlus && !allowed ? freeFontStyle : chosen;
});
