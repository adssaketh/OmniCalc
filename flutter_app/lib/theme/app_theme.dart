import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// One typeface for the whole app (src/index.css `--font-sans` / `--font-mono`): Google Sans where the phone has it,
/// then the same fallbacks as the CSS. Numbers use the same font as the labels.
const String kFontFamily = 'Google Sans';
const List<String> kFontFamilyFallback = ['Google Sans Text', 'Roboto Flex', 'Roboto'];

/// `font-variant-numeric: tabular-nums` / `font-feature-settings: 'tnum' 1`. The CSS applies it to `.font-mono`,
/// `.tabular-nums`, inputs and textareas, not to every label, so it is opt-in here too.
const List<FontFeature> kTabularFigures = [FontFeature.tabularFigures()];

/// Text style with the app font. [color] is usually an `M3Tokens` role.
TextStyle appText({
  double? size,
  FontWeight? weight,
  Color? color,
  double? letterSpacingEm,
  double? height,
  bool tabular = false,
}) {
  return TextStyle(
    fontFamily: kFontFamily,
    fontFamilyFallback: kFontFamilyFallback,
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: (letterSpacingEm != null && size != null) ? letterSpacingEm * size : null,
    height: height,
    fontFeatures: tabular ? kTabularFigures : null,
  );
}

/// Material `ThemeData` for the roles in force. Only what the framework itself draws (text selection, scroll glow,
/// default text) comes from here; every OmniCalc surface is drawn by hand from [M3Tokens] to match the CSS.
ThemeData buildThemeData(M3Tokens t) {
  final scheme = ColorScheme(
    brightness: t.isDark ? Brightness.dark : Brightness.light,
    primary: t.primary,
    onPrimary: t.onPrimary,
    primaryContainer: t.primaryContainer,
    onPrimaryContainer: t.onPrimaryContainer,
    secondary: t.secondary,
    onSecondary: t.onSecondary,
    secondaryContainer: t.secondaryContainer,
    onSecondaryContainer: t.onSecondaryContainer,
    tertiary: t.tertiary,
    onTertiary: t.onTertiary,
    tertiaryContainer: t.tertiaryContainer,
    onTertiaryContainer: t.onTertiaryContainer,
    error: t.error,
    onError: t.onError,
    errorContainer: t.errorContainer,
    onErrorContainer: t.onErrorContainer,
    surface: t.surface,
    onSurface: t.onSurface,
    surfaceDim: t.surfaceDim,
    surfaceBright: t.surfaceBright,
    surfaceContainerLowest: t.surfaceContainerLowest,
    surfaceContainerLow: t.surfaceContainerLow,
    surfaceContainer: t.surfaceContainer,
    surfaceContainerHigh: t.surfaceContainerHigh,
    surfaceContainerHighest: t.surfaceContainerHighest,
    onSurfaceVariant: t.onSurfaceVariant,
    outline: t.outline,
    outlineVariant: t.outlineVariant,
    scrim: t.scrim,
    inverseSurface: t.inverseSurface,
    onInverseSurface: t.surface,
    inversePrimary: t.primaryContainer,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.surface,
    canvasColor: t.surface,
    fontFamily: kFontFamily,
    fontFamilyFallback: kFontFamilyFallback,
    // -webkit-tap-highlight-color: transparent: no ripples or highlights, the keys draw their own press feedback.
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: t.primary,
      selectionColor: t.primary.withValues(alpha: 0.3),
      selectionHandleColor: t.primary,
    ),
  );
}
