import 'package:flutter/material.dart';

/// The dashed guide lines behind the Spend Analyzer charts: light grey, enough
/// to find your place without competing with the data.
///
/// Built from the text colour at a fixed alpha so it is a predictable grey in
/// both themes. [ColorScheme.outlineVariant] is already a faint translucent tone
/// in this theme, and calling `.withValues(alpha: …)` on it *replaces* that alpha
/// rather than scaling it — a 0.7 once turned these lines near-black, and the
/// plain colour (about 12%) was then too faint to see.
Color chartGridColor(ColorScheme scheme) =>
    scheme.onSurface.withValues(alpha: 0.2);
