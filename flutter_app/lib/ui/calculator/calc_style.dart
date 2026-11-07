import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';

/// Tailwind's mobile-first breakpoints, applied to the logical width: `base`, then `sm` (640), `md` (768), `lg` (1024),
/// `xl` (1280). Each value applies from its breakpoint up, until a larger one overrides it.
double tw(double width, double base, {double? sm, double? md, double? lg, double? xl}) {
  var v = base;
  if (width >= 640 && sm != null) v = sm;
  if (width >= 768 && md != null) v = md;
  if (width >= 1024 && lg != null) v = lg;
  if (width >= 1280 && xl != null) v = xl;
  return v;
}

/// A text style with an explicit CSS-like line box: [lineHeight] px, the glyphs centred in it.
TextStyle calcText({
  required double size,
  required FontWeight weight,
  required Color color,
  required double lineHeight,
  double? letterSpacingEm,
  bool mono = false,
  double opacity = 1,
}) {
  return appText(
    size: size,
    weight: weight,
    color: opacity >= 1 ? color : color.withValues(alpha: color.a * opacity),
    letterSpacingEm: letterSpacingEm,
    height: lineHeight / size,
    tabular: mono,
  ).copyWith(leadingDistribution: TextLeadingDistribution.even);
}

/// `color-mix(in srgb, a p%, transparent)`.
Color withAlphaFraction(Color c, double fraction) => c.withValues(alpha: c.a * fraction);
