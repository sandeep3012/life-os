import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/tappable.dart';

/// The dashboard's "right now" hero — the one gradient surface in the design.
///
/// Comp: radius 24, padding 20, a 150° `heroA → heroB` gradient, two translucent
/// `heroVeil` circles bleeding off the right edge, and all ink in `onAccent`
/// (never white — see the handoff's contrast rule, which this satisfies by
/// reading `colorScheme.onPrimary`).
///
/// Every element below the title is optional so the card degrades honestly: with
/// nothing scheduled it renders as a title and subtitle only, rather than showing
/// an empty progress track or a play button that does nothing.
class NowHeroCard extends StatelessWidget {
  const NowHeroCard({
    super.key,
    required this.overline,
    required this.title,
    this.kicker,
    this.subtitle,
    this.upNextLabel,
    this.upNextValue,
    this.onPlay,
    this.progress,
    this.progressLeft,
    this.progressRight,
    this.live = false,
  });

  /// Comp: `NOW · 7:00–8:00 AM`.
  final String overline;

  /// Comp: `Chest & Triceps`, 26px Newsreader w500.
  final String title;

  /// Comp: `PUSH DAY` — the smaller uppercase line above [title].
  final String? kicker;

  /// Shown in place of the up-next/progress block when there's nothing running.
  final String? subtitle;

  final String? upNextLabel;
  final String? upNextValue;

  /// Renders the 46px circular play button when non-null.
  final VoidCallback? onPlay;

  /// 0..1. Renders the progress track when non-null.
  final double? progress;
  final String? progressLeft;
  final String? progressRight;

  /// Pulses the ring around the status dot.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final onHero = Theme.of(context).colorScheme.onPrimary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            // CSS `linear-gradient(150deg, heroA, heroB)`: 150° clockwise from
            // "to top" resolves to a down-and-right axis.
            begin: const Alignment(-0.5, -0.866),
            end: const Alignment(0.5, 0.866),
            colors: [colors.heroA, colors.heroB],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: _veil(150, colors.heroVeil),
            ),
            Positioned(
              right: 24,
              bottom: -40,
              child: _veil(110, colors.heroVeil),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StatusDot(color: onHero, ring: colors.heroTrack, pulse: live),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Overline(
                          overline,
                          color: onHero.withValues(alpha: 0.92),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (kicker != null) ...[
                    Text(
                      kicker!.toUpperCase(),
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: onHero.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: AppFonts.serif,
                      fontSize: 26,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                      color: onHero,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 13,
                        color: onHero.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                  if (upNextValue != null || onPlay != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (upNextLabel != null)
                                Text(
                                  upNextLabel!,
                                  style: TextStyle(
                                    fontFamily: AppFonts.sans,
                                    fontSize: 12.5,
                                    color: onHero.withValues(alpha: 0.85),
                                  ),
                                ),
                              if (upNextValue != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Text(
                                    upNextValue!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: AppFonts.sans,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: onHero,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (onPlay != null) ...[
                          const SizedBox(width: 12),
                          Tappable(
                            onTap: onPlay,
                            haptic: TapHaptic.light,
                            semanticLabel: 'Start',
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: onHero,
                              ),
                              child: Icon(
                                LucideIcons.play,
                                size: 24,
                                color: colors.heroA,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (progress != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            progressLeft ?? '',
                            style: _progressLabel(onHero),
                          ),
                        ),
                        Text(progressRight ?? '', style: _progressLabel(onHero)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress!.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: colors.heroTrack,
                        valueColor: AlwaysStoppedAnimation<Color>(onHero),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static TextStyle _progressLabel(Color onHero) => TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    color: onHero.withValues(alpha: 0.9),
  );

  Widget _veil(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

/// The comp's 8px dot inside a 4px ring (`box-shadow:0 0 0 4px var(--hero-track)`),
/// with the ring pulsing when the block is actually live.
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, required this.ring, required this.pulse});

  final Color color;
  final Color ring;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final halo = Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(shape: BoxShape.circle, color: ring),
    );

    return SizedBox(
      width: 16,
      height: 16,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (pulse)
            halo
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 0.8, end: 1.15, duration: 900.ms)
          else
            halo,
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ],
      ),
    );
  }
}
