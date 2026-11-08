import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/casio/config.dart';
import '../engine/casio/engine.dart';
import '../engine/types.dart';
import 'app_settings.dart';
import 'casio_memory_store.dart';

/// Own key: the web-parity `omni_calc_settings` blob is not touched.
const String casioSettingsStorageKey = 'omni_calc_casio_settings';

/// Settings of the Casio calculation engine (Part 9, section 9.1). Calculation style and percent style are OmniCalc's own;
/// the rest are the SETUP choices of the fx-991ES PLUS.
class CasioSettings {
  const CasioSettings({
    this.useCasio = true,
    this.phonePercent = true,
    this.displayFormat = CasioDisplayFormat.mathO,
    this.decimalFirst = false,
    this.numberFormat = CasioNumberFormat.norm1,
    this.digits = 0,
    this.mixedFractions = false,
    this.recurring = true,
    this.commaDecimal = false,
    this.gradians = false,
    this.complexPolar = false,
    this.statFreq = false,
    this.tableFg = false,
  });

  /// "Calculation style: Casio (default)"; false is "OmniCalc (legacy)".
  final bool useCasio;

  /// "Percent style: OmniCalc (default)"; false is the manual's postfix percent.
  final bool phonePercent;
  final CasioDisplayFormat displayFormat;

  /// "Result display: Decimal": results start as decimals.
  final bool decimalFirst;
  final CasioNumberFormat numberFormat;
  final int digits;
  final bool mixedFractions;
  final bool recurring;
  final bool commaDecimal;

  /// Angle unit Gra (OmniCalc's own angle setting has only DEG and RAD).
  final bool gradians;

  /// SETUP ▸ Complex: r∠θ (true) or a+bi (false).
  final bool complexPolar;

  /// SETUP ▸ STAT: Frequency column on (STAT itself arrives in Phase 7d-2).
  final bool statFreq;

  /// SETUP ▸ Table: f(x),g(x) (true) or f(x) (false) (TABLE itself arrives in Phase 7d-2).
  final bool tableFg;

  CasioSettings copyWith({
    bool? useCasio,
    bool? phonePercent,
    CasioDisplayFormat? displayFormat,
    bool? decimalFirst,
    CasioNumberFormat? numberFormat,
    int? digits,
    bool? mixedFractions,
    bool? recurring,
    bool? commaDecimal,
    bool? gradians,
    bool? complexPolar,
    bool? statFreq,
    bool? tableFg,
  }) =>
      CasioSettings(
        useCasio: useCasio ?? this.useCasio,
        phonePercent: phonePercent ?? this.phonePercent,
        displayFormat: displayFormat ?? this.displayFormat,
        decimalFirst: decimalFirst ?? this.decimalFirst,
        numberFormat: numberFormat ?? this.numberFormat,
        digits: digits ?? this.digits,
        mixedFractions: mixedFractions ?? this.mixedFractions,
        recurring: recurring ?? this.recurring,
        commaDecimal: commaDecimal ?? this.commaDecimal,
        gradians: gradians ?? this.gradians,
        complexPolar: complexPolar ?? this.complexPolar,
        statFreq: statFreq ?? this.statFreq,
        tableFg: tableFg ?? this.tableFg,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'useCasio': useCasio,
        'phonePercent': phonePercent,
        'displayFormat': displayFormat.name,
        'decimalFirst': decimalFirst,
        'numberFormat': numberFormat.name,
        'digits': digits,
        'mixedFractions': mixedFractions,
        'recurring': recurring,
        'commaDecimal': commaDecimal,
        'gradians': gradians,
        'complexPolar': complexPolar,
        'statFreq': statFreq,
        'tableFg': tableFg,
      };

  factory CasioSettings.fromJson(Map<String, Object?> j) {
    const d = CasioSettings();
    bool b(String k, bool f) => j[k] is bool ? j[k]! as bool : f;
    T e<T extends Enum>(List<T> values, String k, T f) {
      for (final v in values) {
        if (v.name == j[k]) return v;
      }
      return f;
    }

    final digits = j['digits'] is int ? (j['digits']! as int).clamp(0, 9) : d.digits;
    return CasioSettings(
      useCasio: b('useCasio', d.useCasio),
      phonePercent: b('phonePercent', d.phonePercent),
      displayFormat: e(CasioDisplayFormat.values, 'displayFormat', d.displayFormat),
      decimalFirst: b('decimalFirst', d.decimalFirst),
      numberFormat: e(CasioNumberFormat.values, 'numberFormat', d.numberFormat),
      digits: digits,
      mixedFractions: b('mixedFractions', d.mixedFractions),
      recurring: b('recurring', d.recurring),
      commaDecimal: b('commaDecimal', d.commaDecimal),
      gradians: b('gradians', d.gradians),
      complexPolar: b('complexPolar', d.complexPolar),
      statFreq: b('statFreq', d.statFreq),
      tableFg: b('tableFg', d.tableFg),
    );
  }

  /// The engine configuration for these settings plus OmniCalc's angle unit and decimal-places setting.
  CasioConfig toConfig(AngleMode angle, int decimalPrecision) => CasioConfig(
        angle: gradians ? CasioAngle.gra : (angle == AngleMode.rad ? CasioAngle.rad : CasioAngle.deg),
        displayFormat: displayFormat,
        numberFormat: numberFormat,
        digits: digits,
        mixedFractions: mixedFractions,
        recurring: recurring,
        phonePercent: phonePercent,
        commaDecimal: commaDecimal,
        decimalFirst: decimalFirst,
        legacyPrecision: decimalPrecision,
        useCasio: useCasio,
        complexFormat: complexPolar ? CasioComplexFormat.polar : CasioComplexFormat.rect,
        statFreq: statFreq,
        tableFg: tableFg,
      );
}

/// The one engine of the app (Ans, PreAns and the variables survive screens, AC and mode changes, manual p.35) and its settings.
class CasioRuntime extends ChangeNotifier {
  CasioRuntime._();

  static final CasioRuntime instance = CasioRuntime._();

  CasioSettings _settings = const CasioSettings();
  SharedPreferences? _prefs;
  final CasioEngine engine = CasioEngine();

  CasioSettings get settings => _settings;

  /// The mode names saved with the memory (read by the calculator screen on start).
  SavedCasioState saved = const SavedCasioState();

  /// Reads the saved settings; a missing or unreadable blob gives the defaults.
  Future<void> load([SharedPreferences? prefs]) async {
    _prefs = prefs ?? await SharedPreferences.getInstance();
    try {
      final saved = _prefs!.getString(casioSettingsStorageKey);
      if (saved != null) {
        final decoded = jsonDecode(saved);
        if (decoded is Map<String, dynamic>) _settings = CasioSettings.fromJson(decoded.cast<String, Object?>());
      }
    } catch (_) {
      _settings = const CasioSettings();
    }
    // Ans, PreAns, the variables and the mode come back as they were (Part 9, R)
    saved = CasioMemoryStore.decode(_prefs!.getString(casioMemoryStorageKey), engine.memory);
    notifyListeners();
  }

  /// Writes Ans, PreAns, the variables and the mode names. Called after each result and mode change.
  void saveMemory({String? mode, String? baseMode, String? statType}) {
    saved = SavedCasioState(mode: mode, baseMode: baseMode, statType: statType);
    try {
      _prefs?.setString(casioMemoryStorageKey, CasioMemoryStore.encode(engine.memory, mode: mode, baseMode: baseMode, statType: statType));
    } catch (_) {}
  }

  void update(CasioSettings Function(CasioSettings) change) {
    _settings = change(_settings);
    try {
      _prefs?.setString(casioSettingsStorageKey, jsonEncode(_settings.toJson()));
    } catch (_) {}
    notifyListeners();
  }

  /// Back to the defaults (Settings ▸ Reset).
  void reset() => update((_) => const CasioSettings());

  CasioConfig configFor(AppSettings s) => _settings.toConfig(s.angleMode, s.decimalPrecision);
}
