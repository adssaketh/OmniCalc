import '../engine/types.dart';

/// Mirrors `AppSettings` and `DEFAULT_SETTINGS` (src/types/index.ts, src/App.tsx).
/// Enum values carry the exact strings the web app stores, so the JSON written to `omni_calc_settings` has the same shape.

enum VibrationIntensity { light, medium, strong, intense }

enum ColorMode { system, light, dark }

/// How content behaves as it slides under the floating bars.
enum EdgeEffect { off, fade, blur }

enum FadeHeight { short, medium, tall }

enum BarStyle { solid, glass }

enum GlassBlur { soft, medium, strong }

/// Theme ids (ThemeId in the TS). Kept as strings: the legacy ids (dark-obsidian, oled-midnight, warm-paper,
/// cyber-emerald) can still be present in a saved settings blob and must round-trip unchanged.
class ThemeIds {
  const ThemeIds._();

  static const dynamic = 'dynamic';
  static const iris = 'm3-iris';
  static const ocean = 'm3-ocean';
  static const forest = 'm3-forest';
  static const sunset = 'm3-sunset';
  static const amoled = 'm3-amoled';
  static const darkObsidian = 'dark-obsidian';
  static const oledMidnight = 'oled-midnight';
  static const warmPaper = 'warm-paper';
  static const cyberEmerald = 'cyber-emerald';
}

T _enumOr<T extends Enum>(List<T> values, Object? raw, T fallback) {
  for (final v in values) {
    if (v.name == raw) return v;
  }
  return fallback;
}

bool _boolOr(Object? raw, bool fallback) => raw is bool ? raw : fallback;

String _stringOr(Object? raw, String fallback) => raw is String ? raw : fallback;

int _intOr(Object? raw, int fallback) {
  if (raw is int) return raw;
  if (raw is double && raw.isFinite) return raw.round();
  return fallback;
}

class AppSettings {
  const AppSettings({
    this.soundEnabled = true,
    this.hapticEnabled = true,
    this.vibrationIntensity = VibrationIntensity.medium,
    this.angleMode = AngleMode.deg,
    this.decimalPrecision = -1,
    this.theme = ThemeIds.dynamic,
    this.colorMode = ColorMode.system,
    this.currencySymbol = '₹',
    this.currencyCode = 'INR',
    this.enableGrapher = false,
    this.enablePhysics = false,
    this.edgeEffect = EdgeEffect.fade,
    this.fadeHeight = FadeHeight.medium,
    this.barStyle = BarStyle.solid,
    this.glassTransparency = 70,
    this.glassBlur = GlassBlur.medium,
    this.glassEdge = true,
    this.extras = const <String, Object?>{},
  });

  final bool soundEnabled;
  final bool hapticEnabled;
  final VibrationIntensity vibrationIntensity;
  final AngleMode angleMode;

  /// 2, 4, 6, 8, or -1 for auto.
  final int decimalPrecision;
  final String theme;
  final ColorMode colorMode;
  final String currencySymbol;
  final String currencyCode;
  final bool enableGrapher;

  /// Show the Physics Lab screen (off by default).
  final bool enablePhysics;
  final EdgeEffect edgeEffect;
  final FadeHeight fadeHeight;
  final BarStyle barStyle;

  /// Glass transparency, 0 = frosted ... 100 = clear.
  final int glassTransparency;
  final GlassBlur glassBlur;

  /// Thin light rim around the glass bars.
  final bool glassEdge;

  /// Keys found in the saved JSON that this build does not know. The web app spreads the whole saved object over the
  /// defaults, so unknown keys survive a save; they do here too.
  final Map<String, Object?> extras;

  AppSettings copyWith({
    bool? soundEnabled,
    bool? hapticEnabled,
    VibrationIntensity? vibrationIntensity,
    AngleMode? angleMode,
    int? decimalPrecision,
    String? theme,
    ColorMode? colorMode,
    String? currencySymbol,
    String? currencyCode,
    bool? enableGrapher,
    bool? enablePhysics,
    EdgeEffect? edgeEffect,
    FadeHeight? fadeHeight,
    BarStyle? barStyle,
    int? glassTransparency,
    GlassBlur? glassBlur,
    bool? glassEdge,
  }) {
    return AppSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      vibrationIntensity: vibrationIntensity ?? this.vibrationIntensity,
      angleMode: angleMode ?? this.angleMode,
      decimalPrecision: decimalPrecision ?? this.decimalPrecision,
      theme: theme ?? this.theme,
      colorMode: colorMode ?? this.colorMode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      currencyCode: currencyCode ?? this.currencyCode,
      enableGrapher: enableGrapher ?? this.enableGrapher,
      enablePhysics: enablePhysics ?? this.enablePhysics,
      edgeEffect: edgeEffect ?? this.edgeEffect,
      fadeHeight: fadeHeight ?? this.fadeHeight,
      barStyle: barStyle ?? this.barStyle,
      glassTransparency: glassTransparency ?? this.glassTransparency,
      glassBlur: glassBlur ?? this.glassBlur,
      glassEdge: glassEdge ?? this.glassEdge,
      extras: extras,
    );
  }

  static const Set<String> _knownKeys = {
    'soundEnabled',
    'hapticEnabled',
    'vibrationIntensity',
    'angleMode',
    'decimalPrecision',
    'theme',
    'colorMode',
    'currencySymbol',
    'currencyCode',
    'enableGrapher',
    'enablePhysics',
    'edgeEffect',
    'fadeHeight',
    'barStyle',
    'glassTransparency',
    'glassBlur',
    'glassEdge',
  };

  /// `{ ...DEFAULT_SETTINGS, ...JSON.parse(saved) }`. A saved value of the wrong type falls back to the default
  /// (JavaScript would keep it as is; a typed model cannot).
  factory AppSettings.fromJson(Map<String, Object?> json) {
    const d = AppSettings();
    return AppSettings(
      soundEnabled: _boolOr(json['soundEnabled'], d.soundEnabled),
      hapticEnabled: _boolOr(json['hapticEnabled'], d.hapticEnabled),
      vibrationIntensity: _enumOr(VibrationIntensity.values, json['vibrationIntensity'], d.vibrationIntensity),
      angleMode: json['angleMode'] is String ? AngleMode.parse(json['angleMode']! as String) : d.angleMode,
      decimalPrecision: _intOr(json['decimalPrecision'], d.decimalPrecision),
      theme: _stringOr(json['theme'], d.theme),
      colorMode: _enumOr(ColorMode.values, json['colorMode'], d.colorMode),
      currencySymbol: _stringOr(json['currencySymbol'], d.currencySymbol),
      currencyCode: _stringOr(json['currencyCode'], d.currencyCode),
      enableGrapher: _boolOr(json['enableGrapher'], d.enableGrapher),
      enablePhysics: _boolOr(json['enablePhysics'], d.enablePhysics),
      edgeEffect: _enumOr(EdgeEffect.values, json['edgeEffect'], d.edgeEffect),
      fadeHeight: _enumOr(FadeHeight.values, json['fadeHeight'], d.fadeHeight),
      barStyle: _enumOr(BarStyle.values, json['barStyle'], d.barStyle),
      glassTransparency: _intOr(json['glassTransparency'], d.glassTransparency),
      glassBlur: _enumOr(GlassBlur.values, json['glassBlur'], d.glassBlur),
      glassEdge: _boolOr(json['glassEdge'], d.glassEdge),
      extras: {
        for (final e in json.entries)
          if (!_knownKeys.contains(e.key)) e.key: e.value,
      },
    );
  }

  /// Key order follows DEFAULT_SETTINGS (as JavaScript's object spread does), then any unknown keys.
  Map<String, Object?> toJson() => <String, Object?>{
        'soundEnabled': soundEnabled,
        'hapticEnabled': hapticEnabled,
        'vibrationIntensity': vibrationIntensity.name,
        'angleMode': angleMode.id,
        'decimalPrecision': decimalPrecision,
        'theme': theme,
        'colorMode': colorMode.name,
        'currencySymbol': currencySymbol,
        'currencyCode': currencyCode,
        'enableGrapher': enableGrapher,
        'enablePhysics': enablePhysics,
        'edgeEffect': edgeEffect.name,
        'fadeHeight': fadeHeight.name,
        'barStyle': barStyle.name,
        'glassTransparency': glassTransparency,
        'glassBlur': glassBlur.name,
        'glassEdge': glassEdge,
        ...extras,
      };
}
