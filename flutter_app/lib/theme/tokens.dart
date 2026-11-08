import 'package:flutter/widgets.dart';

import 'theme_data_generated.dart';

/// The `--m3-*` colour roles of `src/index.css` (Material 3 tonal roles). Values come from the generated tables or,
/// for Material You, from the system palette (see `dynamic_colors.dart`).
@immutable
class M3Tokens {
  const M3Tokens({
    required this.isDark,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.surface,
    required this.surfaceDim,
    required this.surfaceBright,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.outline,
    required this.outlineVariant,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.scrim,
  });

  /// `data-m3-mode` is "dark".
  final bool isDark;

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;

  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;

  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;

  final Color surface;
  final Color surfaceDim;
  final Color surfaceBright;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;

  final Color outline;
  final Color outlineVariant;
  final Color onSurface;
  final Color onSurfaceVariant;

  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;

  final Color scrim;

  /// `var(--m3-inverse-surface, var(--m3-on-surface))`: the CSS never defines --m3-inverse-surface, so it is on-surface.
  Color get inverseSurface => onSurface;

  /// Builds tokens from a map keyed like the CSS names without the `--m3-` prefix (`on-primary-container`, ...).
  factory M3Tokens.fromMap(Map<String, int> m, {required bool isDark}) {
    Color c(String key) {
      final v = m[key];
      if (v == null) throw StateError('Missing colour role --m3-$key');
      return Color(v);
    }

    return M3Tokens(
      isDark: isDark,
      primary: c('primary'),
      onPrimary: c('on-primary'),
      primaryContainer: c('primary-container'),
      onPrimaryContainer: c('on-primary-container'),
      secondary: c('secondary'),
      onSecondary: c('on-secondary'),
      secondaryContainer: c('secondary-container'),
      onSecondaryContainer: c('on-secondary-container'),
      tertiary: c('tertiary'),
      onTertiary: c('on-tertiary'),
      tertiaryContainer: c('tertiary-container'),
      onTertiaryContainer: c('on-tertiary-container'),
      surface: c('surface'),
      surfaceDim: c('surface-dim'),
      surfaceBright: c('surface-bright'),
      surfaceContainerLowest: c('surface-container-lowest'),
      surfaceContainerLow: c('surface-container-low'),
      surfaceContainer: c('surface-container'),
      surfaceContainerHigh: c('surface-container-high'),
      surfaceContainerHighest: c('surface-container-highest'),
      outline: c('outline'),
      outlineVariant: c('outline-variant'),
      onSurface: c('on-surface'),
      onSurfaceVariant: c('on-surface-variant'),
      error: c('error'),
      onError: c('on-error'),
      errorContainer: c('error-container'),
      onErrorContainer: c('on-error-container'),
      scrim: c('scrim'),
    );
  }

  /// Every role as `css-name -> ARGB`, the inverse of [M3Tokens.fromMap]. Used by tests.
  Map<String, int> toMap() => <String, int>{
        'primary': primary.toARGB32(),
        'on-primary': onPrimary.toARGB32(),
        'primary-container': primaryContainer.toARGB32(),
        'on-primary-container': onPrimaryContainer.toARGB32(),
        'secondary': secondary.toARGB32(),
        'on-secondary': onSecondary.toARGB32(),
        'secondary-container': secondaryContainer.toARGB32(),
        'on-secondary-container': onSecondaryContainer.toARGB32(),
        'tertiary': tertiary.toARGB32(),
        'on-tertiary': onTertiary.toARGB32(),
        'tertiary-container': tertiaryContainer.toARGB32(),
        'on-tertiary-container': onTertiaryContainer.toARGB32(),
        'surface': surface.toARGB32(),
        'surface-dim': surfaceDim.toARGB32(),
        'surface-bright': surfaceBright.toARGB32(),
        'surface-container-lowest': surfaceContainerLowest.toARGB32(),
        'surface-container-low': surfaceContainerLow.toARGB32(),
        'surface-container': surfaceContainer.toARGB32(),
        'surface-container-high': surfaceContainerHigh.toARGB32(),
        'surface-container-highest': surfaceContainerHighest.toARGB32(),
        'outline': outline.toARGB32(),
        'outline-variant': outlineVariant.toARGB32(),
        'on-surface': onSurface.toARGB32(),
        'on-surface-variant': onSurfaceVariant.toARGB32(),
        'error': error.toARGB32(),
        'on-error': onError.toARGB32(),
        'error-container': errorContainer.toARGB32(),
        'on-error-container': onErrorContainer.toARGB32(),
        'scrim': scrim.toARGB32(),
      };

  @override
  bool operator ==(Object other) {
    if (other is! M3Tokens || other.isDark != isDark) return false;
    final a = toMap();
    final b = other.toMap();
    for (final k in a.keys) {
      if (a[k] != b[k]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([isDark, ...toMap().values]);
}

/// `data-m3-theme` value for a theme id (App.tsx `THEME_DATA_ATTR`; anything not listed is 'iris').
String themeDataAttr(String themeId) => kThemeDataAttr[themeId] ?? 'iris';

/// The static (non-Material-You) roles for a theme: the Iris base of the mode with the theme's overrides on top,
/// exactly how the CSS cascade resolves `:root`, `[data-m3-mode="light"]` and the per-theme blocks.
M3Tokens staticTokens(String themeId, {required bool isDark}) {
  final attr = themeDataAttr(themeId);
  final map = <String, int>{
    ...(isDark ? kDarkBase : kLightBase),
    ...?(isDark ? kDarkOverrides : kLightOverrides)[attr],
  };
  return M3Tokens.fromMap(map, isDark: isDark);
}

/// Page background of a theme (App.tsx `DARK_SURFACES` / `LIGHT_SURFACES`, with the same fallbacks), used for the status
/// bar and the root. Material You uses its own surface role instead (see `resolveTokens`).
Color pageSurface(String themeId, {required bool isDark}) {
  final v = (isDark ? kDarkSurfaces : kLightSurfaces)[themeId];
  return Color(v ?? (isDark ? 0xFF111318 : 0xFFF8F9FA));
}

/// Light-weight accessor: `M3Theme.of(context)`.
class M3Theme extends InheritedWidget {
  const M3Theme({super.key, required this.tokens, required super.child});

  final M3Tokens tokens;

  static M3Tokens of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<M3Theme>();
    assert(w != null, 'No M3Theme above this context');
    return w!.tokens;
  }

  @override
  bool updateShouldNotify(M3Theme oldWidget) => oldWidget.tokens != tokens;
}
