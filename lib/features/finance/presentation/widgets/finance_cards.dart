import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/donut_chart.dart';
import '../../../../core/widgets/initial_well.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../core/widgets/tappable.dart';

/// Tabular money style — the handoff requires tabular figures on every amount.
TextStyle _money(double size, Color color, {FontWeight weight = FontWeight.w800}) {
  return TextStyle(
    fontFamily: AppFonts.numeric,
    fontSize: size,
    fontWeight: weight,
    color: color,
    fontFeatures: AppFonts.tabular,
  );
}

/// One of the three figures under the Finance headline. Comp: equal-width grid,
/// radius 16, a 26px radius-8 well, an 11px `text3` label and a 15px w800 value.
class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      radius: AppSpacing.tileRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialWell(color: color, size: 26, radius: 8, icon: icon),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.text3,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _money(15, scheme.onSurface),
          ),
        ],
      ),
    );
  }
}

/// A legend entry beside the donut.
class DonutLegendEntry {
  const DonutLegendEntry({
    required this.name,
    required this.share,
    required this.color,
  });

  final String name;
  final double share;
  final Color color;
}

/// Comp: "Where it went" — a radius-22 card holding the 132px ring with `SPENT`
/// and the total in its centre, and the top categories listed to its right.
class SpendDonutCard extends StatelessWidget {
  const SpendDonutCard({
    super.key,
    required this.segments,
    required this.legend,
    required this.totalLabel,
  });

  final List<DonutSegment> segments;
  final List<DonutLegendEntry> legend;
  final String totalLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where it went',
            style: TextStyle(
              fontFamily: AppFonts.serif,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              DonutChart(
                segments: segments,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Overline('Spent', color: colors.text3, fontSize: 10.5),
                    Text(totalLabel, style: _money(17, scheme.onSurface)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    for (final entry in legend)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: entry.color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppFonts.sans,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Text(
                              '${(entry.share * 100).round()}%',
                              style: _money(12.5, scheme.onSurface),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One bar of [MonthlyBarsCard].
class MonthBar {
  const MonthBar({
    required this.label,
    required this.topLabel,
    required this.value,
  });

  final String label;
  final String topLabel;
  final int value;
}

/// Comp: "Monthly spending" — a radius-22 card with a 130px-tall row of bars
/// capped at 26px wide, radius `8 8 4 4`, heights proportional to the largest
/// month, and the largest month filled in the accent while the rest sit in a
/// border tone.
class MonthlyBarsCard extends StatelessWidget {
  const MonthlyBarsCard({super.key, required this.bars});

  final List<MonthBar> bars;

  static const double _chartHeight = 130;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    final max = bars.fold<int>(0, (m, b) => b.value > m ? b.value : m);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'Monthly spending',
                  style: TextStyle(
                    fontFamily: AppFonts.serif,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Text(
                '${bars.length} months',
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.text3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: _chartHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final bar in bars)
                  Expanded(
                    child: _Bar(
                      bar: bar,
                      isMax: max > 0 && bar.value == max,
                      fraction: max == 0 ? 0 : bar.value / max,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.bar,
    required this.isMax,
    required this.fraction,
  });

  final MonthBar bar;
  final bool isMax;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    // The bar takes whatever height the two labels leave rather than being
    // sized against a hard-coded reserve. Text scales with the platform font
    // setting, so subtracting a fixed number overflowed the card by a couple of
    // pixels as soon as the labels were a hair taller than assumed.
    return Column(
      children: [
        Text(
          bar.topLabel,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: _money(10, isMax ? colors.accentInk : colors.text3),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: fraction.clamp(0.02, 1.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 26),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isMax ? scheme.secondary : scheme.outlineVariant,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                    bottom: Radius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          bar.label,
          maxLines: 1,
          style: TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: colors.text3,
          ),
        ),
      ],
    );
  }
}

/// Comp: a 158px-wide radius-20 card in a horizontal scroller — a 30px initial
/// well, a type overline, the name, the balance (negative balances render in the
/// spend colour), and a caption.
class AccountMiniCard extends StatelessWidget {
  const AccountMiniCard({
    super.key,
    required this.name,
    required this.kind,
    required this.balance,
    required this.color,
    required this.negative,
    this.subtitle,
    this.onTap,
  });

  final String name;
  final String kind;
  final String balance;
  final Color color;
  final bool negative;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return Tappable(
      onTap: onTap,
      haptic: TapHaptic.light,
      semanticLabel: '$name, $balance',
      child: SizedBox(
        width: 158,
        child: SurfaceCard(
          padding: const EdgeInsets.all(15),
          radius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InitialWell(
                    color: color,
                    size: 30,
                    radius: 10,
                    label: InitialWell.initialOf(name),
                    fontSize: 12.5,
                  ),
                  const Spacer(),
                  Overline(kind, color: colors.text3, fontSize: 10, letterSpacing: 0.5),
                ],
              ),
              const SizedBox(height: 11),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                balance,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _money(17, negative ? colors.warm : scheme.onSurface),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 11,
                    color: colors.text3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Comp: a radius-16 row with a 40px radius-13 initial well, the name followed by
/// a small tag pill, a cadence caption, and a right-aligned amount over its next
/// run date.
class RecurringRow extends StatelessWidget {
  const RecurringRow({
    super.key,
    required this.name,
    required this.subtitle,
    required this.amount,
    required this.nextRun,
    required this.color,
    this.tag,
    this.onTap,
  });

  final String name;
  final String subtitle;
  final String amount;
  final String nextRun;
  final Color color;
  final String? tag;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    final row = SurfaceCard.row(
      child: Row(
        children: [
          InitialWell(
            color: color,
            size: 40,
            radius: 13,
            label: InitialWell.initialOf(name),
            fontSize: 14,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.sans,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    if (tag != null) ...[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.accentSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tag!.toUpperCase(),
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: colors.accentInk,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 12,
                    color: colors.text3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: _money(14, scheme.onSurface)),
              const SizedBox(height: 1),
              Text(
                nextRun,
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 11,
                  color: colors.text3,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return row;
    return Tappable(
      onTap: onTap,
      haptic: TapHaptic.light,
      semanticLabel: '$name, $amount, $nextRun',
      child: row,
    );
  }
}

/// Comp: a hairline-divided list row — no card — with a 42px radius-13 initial
/// well, name over "Category · date", and the amount signed `+` in the accent ink
/// or `−` in the primary text colour.
class TxnRow extends StatelessWidget {
  const TxnRow({
    super.key,
    required this.name,
    required this.subtitle,
    required this.amount,
    required this.color,
    required this.incoming,
    this.onTap,
  });

  final String name;
  final String subtitle;
  final String amount;
  final Color color;
  final bool incoming;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          InitialWell(
            color: color,
            size: 42,
            radius: 13,
            label: InitialWell.initialOf(name),
            fontSize: 15,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 12,
                    color: colors.text3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amount,
            style: _money(14.5, incoming ? colors.accentInk : scheme.onSurface),
          ),
        ],
      ),
    );

    if (onTap == null) return row;
    return Tappable(
      onTap: onTap,
      haptic: TapHaptic.light,
      semanticLabel: '$name, $amount',
      child: row,
    );
  }
}
