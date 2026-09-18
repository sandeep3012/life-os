import 'package:flutter/material.dart';

import '../../app/theme/app_fonts.dart';

/// A section heading in the design's serif face — 19px Newsreader w600 — with an
/// optional trailing counter or action on the same baseline.
///
/// The comp sets section headings in Newsreader, not the UI face, which is why
/// this exists rather than reaching for `textTheme.titleMedium` inline.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;

  /// Right-aligned text such as the to-do list's "1 of 3 done" counter.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: AppFonts.serif,
              fontSize: 19,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// The design's uppercase overline: 11px w800 with wide tracking, in the third
/// text tone. Used for the dashboard date, `NET SAVED · AUGUST`, `SPENT`, and the
/// amount labels in the entry sheet.
class Overline extends StatelessWidget {
  const Overline(
    this.text, {
    super.key,
    this.color,
    this.letterSpacing = 0.6,
    this.fontSize = 11,
  });

  final String text;
  final Color? color;
  final double letterSpacing;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: AppFonts.sans,
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: letterSpacing,
        color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
