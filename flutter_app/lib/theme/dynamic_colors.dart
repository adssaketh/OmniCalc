import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Material You (Android 12+) system palette: `system_accent1_200` -> RGB, the same keys the web app's native
/// `DynamicColor` plugin returns (src/native/dynamicColor.ts). Alpha is dropped, like the plugin's `#RRGGBB` strings.
@immutable
class SystemColors {
  const SystemColors(this.colors);

  final Map<String, int> colors;

  /// `system_neutral2_700` etc. -> opaque colour, or null if the key is missing.
  Color? operator [](String key) {
    final v = colors[key];
    return v == null ? null : Color(0xFF000000 | v);
  }

  static const List<String> _palettes = [
    'system_accent1',
    'system_accent2',
    'system_accent3',
    'system_neutral1',
    'system_neutral2',
  ];

  /// Tone suffixes in the order the `dynamic_color` plugin returns them (see its Kotlin `getCorePalette`).
  static const List<String> _tones = ['1000', '900', '800', '700', '600', '500', '400', '300', '200', '100', '50', '10', '0'];

  /// The plugin answers a flat list of 5 palettes x 13 tones (65 ARGB ints).
  static SystemColors? fromPaletteList(List<Object?>? list) {
    if (list == null || list.length != _palettes.length * _tones.length) return null;
    final out = <String, int>{};
    for (var p = 0; p < _palettes.length; p++) {
      for (var t = 0; t < _tones.length; t++) {
        final raw = list[p * _tones.length + t];
        if (raw is! int) return null;
        out['${_palettes[p]}_${_tones[t]}'] = raw & 0xFFFFFF;
      }
    }
    return SystemColors(out);
  }
}

/// `getSystemColors()`: the system colours, or null when unsupported (web, iOS, Android below 12) or on any error.
abstract class SystemColorsSource {
  Future<SystemColors?> getSystemColors();
}

/// Reads the palette through the `dynamic_color` package's native plugin channel.
class PlatformSystemColorsSource implements SystemColorsSource {
  const PlatformSystemColorsSource();

  static const MethodChannel _channel = MethodChannel('io.material.plugins/dynamic_color');

  @override
  Future<SystemColors?> getSystemColors() async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>('getCorePalette');
      return SystemColors.fromPaletteList(result);
    } catch (_) {
      // plugin not available (MissingPluginException) or error: unsupported
      return null;
    }
  }
}

/// Fixed colours for tests and previews.
class FakeSystemColorsSource implements SystemColorsSource {
  const FakeSystemColorsSource(this.colors);

  final SystemColors? colors;

  @override
  Future<SystemColors?> getSystemColors() async => colors;
}

/// color-mix(in srgb, [a] [percentA]%, [b]).
Color _mix(Color a, double percentA, Color b) => Color.lerp(b, a, percentA / 100)!;

/// Port of `applyDynamicTokens` (src/native/dynamicColor.ts): maps the system palette to the Material 3 roles.
/// Every fallback colour and every fixed role is copied from the TS.
M3Tokens applyDynamicTokens(SystemColors system, {required bool isDark}) {
  Color get(String key, int fallback) => system[key] ?? Color(fallback);

  if (isDark) {
    final surface = get('system_neutral1_900', 0xFF111318);
    final onSurface = get('system_neutral1_100', 0xFFE2E2E9);
    return M3Tokens(
      isDark: true,
      primary: get('system_accent1_200', 0xFFA8C7FA),
      onPrimary: get('system_accent1_800', 0xFF062E6F),
      primaryContainer: get('system_accent1_700', 0xFF264585),
      onPrimaryContainer: get('system_accent1_100', 0xFFD3E3FD),
      secondary: get('system_accent2_200', 0xFFBDC7DC),
      onSecondary: get('system_accent2_800', 0xFF273142),
      secondaryContainer: get('system_accent2_700', 0xFF334460),
      onSecondaryContainer: get('system_accent2_100', 0xFFDCE2F9),
      tertiary: get('system_accent3_200', 0xFFEFB8C8),
      onTertiary: get('system_accent3_800', 0xFF492532),
      tertiaryContainer: get('system_accent3_700', 0xFF493344),
      onTertiaryContainer: get('system_accent3_100', 0xFFFFD8E4),
      surface: surface,
      surfaceDim: get('system_neutral1_900', 0xFF0B0D12),
      surfaceBright: get('system_neutral1_800', 0xFF37393E),
      surfaceContainerLowest: _mix(surface, 82, const Color(0xFF000000)),
      // Was the same colour as the page, so cards disappeared in dark mode. One clear step lighter (as in the TS).
      surfaceContainerLow: _mix(surface, 93, onSurface),
      surfaceContainer: get('system_neutral1_800', 0xFF1D2024),
      surfaceContainerHigh: get('system_neutral1_700', 0xFF282A2F),
      surfaceContainerHighest: get('system_neutral1_600', 0xFF33353A),
      outline: get('system_neutral2_400', 0xFF8C9199),
      outlineVariant: get('system_neutral2_700', 0xFF43474E),
      onSurface: onSurface,
      onSurfaceVariant: get('system_neutral2_200', 0xFFC3C7CF),
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
      errorContainer: const Color(0xFF93000A),
      onErrorContainer: const Color(0xFFFFDAD6),
      scrim: const Color(0xBF000000),
    );
  }

  return M3Tokens(
    isDark: false,
    primary: get('system_accent1_600', 0xFF0B57D0),
    onPrimary: get('system_accent1_0', 0xFFFFFFFF),
    primaryContainer: get('system_accent1_100', 0xFFD3E3FD),
    onPrimaryContainer: get('system_accent1_900', 0xFF041E49),
    secondary: get('system_accent2_600', 0xFF4F607C),
    onSecondary: const Color(0xFFFFFFFF),
    secondaryContainer: get('system_accent2_100', 0xFFD7E3FF),
    onSecondaryContainer: get('system_accent2_900', 0xFF091B35),
    tertiary: get('system_accent3_600', 0xFF6F5575),
    onTertiary: const Color(0xFFFFFFFF),
    tertiaryContainer: get('system_accent3_100', 0xFFF9D8FE),
    onTertiaryContainer: get('system_accent3_900', 0xFF28132E),
    surface: get('system_neutral1_10', 0xFFF8F9FA),
    surfaceDim: get('system_neutral1_50', 0xFFDADCE0),
    surfaceBright: const Color(0xFFFFFFFF),
    surfaceContainerLowest: const Color(0xFFFFFFFF),
    surfaceContainerLow: get('system_neutral1_50', 0xFFF0F4F9),
    surfaceContainer: get('system_neutral1_100', 0xFFE9EEF6),
    surfaceContainerHigh: get('system_neutral1_200', 0xFFE1E7F0),
    surfaceContainerHighest: get('system_neutral1_300', 0xFFD8E0EC),
    outline: get('system_neutral2_500', 0xFF747775),
    outlineVariant: get('system_neutral2_200', 0xFFC4C7C5),
    onSurface: get('system_neutral1_900', 0xFF1F1F1F),
    onSurfaceVariant: get('system_neutral2_700', 0xFF444746),
    error: const Color(0xFFBA1A1A),
    onError: const Color(0xFFFFFFFF),
    errorContainer: const Color(0xFFFFDAD6),
    onErrorContainer: const Color(0xFF410002),
    scrim: const Color(0x66000000),
  );
}

/// What App.tsx's theme effect computes: the roles in force, and the page surface colour (status bar and root).
class ResolvedTheme {
  const ResolvedTheme({required this.tokens, required this.pageSurface});

  final M3Tokens tokens;
  final Color pageSurface;
}

/// `settings.theme === 'dynamic' && systemColors?.colors` uses the Material You roles; every other case uses the
/// theme's static roles. The page surface is the theme's `DARK_SURFACES`/`LIGHT_SURFACES` entry, or the dynamic
/// surface role.
ResolvedTheme resolveTheme({required String themeId, required bool isDark, SystemColors? system}) {
  if (themeId == 'dynamic' && system != null) {
    final tokens = applyDynamicTokens(system, isDark: isDark);
    return ResolvedTheme(tokens: tokens, pageSurface: tokens.surface);
  }
  return ResolvedTheme(
    tokens: staticTokens(themeId, isDark: isDark),
    pageSurface: pageSurface(themeId, isDark: isDark),
  );
}
