import 'package:life_manager/features/subscription/application/plan_providers.dart';
import 'package:life_manager/features/subscription/data/plan_backend.dart';
import 'package:life_manager/features/subscription/domain/plan.dart';

/// A plan that's simply given, for tests about something else: override
/// `planControllerProvider` with `FixedPlan.plus` (or `.free`).
class FixedPlan extends PlanController {
  FixedPlan(this._state);

  static FixedPlan plus() =>
      FixedPlan(const PlanState(status: PlanStatus.known, plan: AppPlan.plus));
  static FixedPlan free() =>
      FixedPlan(const PlanState(status: PlanStatus.known, plan: AppPlan.free));
  static FixedPlan signedOut() =>
      FixedPlan(const PlanState(status: PlanStatus.signedOut));

  final PlanState _state;

  @override
  PlanState build() => _state;

  @override
  Future<void> start() async {}

  @override
  Future<void> refresh() async {}
}

/// The server's answer, settable; `offline` makes it unreachable.
class FakePlanBackend implements PlanBackend {
  FakePlanBackend({this.plus = false});

  bool plus;
  bool offline = false;
  int checks = 0;

  @override
  Future<bool> hasPlus() async {
    checks++;
    if (offline) throw StateError('offline');
    return plus;
  }

  @override
  Future<VoiceAllowance?> voiceAllowance() async => null;
}

class MemoryPlanCache implements PlanCache {
  final plans = <String, CachedPlan>{};

  @override
  Future<CachedPlan?> read(String userId) async => plans[userId];

  @override
  Future<void> write(String userId, CachedPlan plan) async =>
      plans[userId] = plan;

  @override
  Future<void> clear(String userId) async => plans.remove(userId);
}
