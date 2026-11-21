import '../../../app/theme/app_color_theme.dart';
import '../../../app/theme/app_font_style.dart';

/// What someone is on. Everything that works on one phone is [free];
/// [plus] is the subscription.
enum AppPlan { free, plus }

/// What PersonalOS Plus adds — the things that cost money to run (sync, voice)
/// and the extra looks.
enum PlusFeature {
  sync(
    'Sync across your phones',
    'Encrypted, with recovery if a phone is lost',
  ),
  voice('Voice entry', '300 a month — say it instead of typing it'),
  themes('Every colour theme', 'Ocean, Indigo, Plum and OLED Midnight'),
  fonts('Every font style', 'Six more looks for the whole app');

  const PlusFeature(this.title, this.detail);

  final String title;
  final String detail;
}

/// The colour theme and font everyone has.
const freeColorTheme = AppColorTheme.forest;
const freeFontStyle = AppFontStyle.classic;

extension PlusColorTheme on AppColorTheme {
  bool get isPlus => this != freeColorTheme;
}

extension PlusFontStyle on AppFontStyle {
  bool get isPlus => this != freeFontStyle;
}

/// How many voice entries are left, as the server counts them
/// (`voice_allowance` in `supabase/migrations/*_voice_plan_allowance.sql`).
class VoiceAllowance {
  const VoiceAllowance({
    required this.plan,
    required this.limit,
    required this.used,
    required this.remaining,
  });

  final AppPlan plan;

  /// Free: 15, once. Plus: 300, each month.
  final int limit;
  final int used;

  /// What can still be used right now — on Plus also held by a daily cap,
  /// so it can be zero with some of the month's [limit] unused.
  final int remaining;

  bool get exhausted => remaining <= 0;

  /// A short line for the voice sheet, or null when there's plenty left
  /// and nothing worth saying.
  String? get hint {
    if (plan == AppPlan.free) {
      return remaining == 1
          ? '1 free voice entry left'
          : '$remaining of $limit free voice entries left';
    }
    if (remaining <= 20) {
      return remaining == 1
          ? '1 voice entry left'
          : '$remaining voice entries left';
    }
    return null;
  }

  /// What to say when there are none left.
  String get exhaustedMessage {
    if (plan == AppPlan.free) {
      return "You've used your $limit free voice entries. PersonalOS Plus "
          'includes 300 a month.';
    }
    return used >= limit
        ? "You've used this month's $limit voice entries. They refill on "
              'the 1st.'
        : "That's today's limit for voice entries. Try again tomorrow.";
  }

  static VoiceAllowance? fromJson(Object? json) {
    if (json is! Map) return null;
    final limit = json['limit'];
    final used = json['used'];
    final remaining = json['remaining'];
    if (limit is! num || used is! num || remaining is! num) return null;
    return VoiceAllowance(
      plan: json['plan'] == 'plus' ? AppPlan.plus : AppPlan.free,
      limit: limit.toInt(),
      used: used.toInt(),
      remaining: remaining.toInt(),
    );
  }
}
