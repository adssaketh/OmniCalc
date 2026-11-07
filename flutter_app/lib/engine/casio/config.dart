// Settings and memory of the Casio engine (SETUP of the fx-991ES PLUS, manual p.11-16).

import 'cval.dart';

enum CasioAngle { deg, rad, gra }

/// SETUP ▸ MthIO / LineIO. MathO shows results the way they are written on paper, LineO shows them linearly, LineIO shows
/// input and results linearly (and results start as decimals).
enum CasioDisplayFormat { mathO, lineO, lineIO }

enum CasioNumberFormat { norm1, norm2, fix, sci }

/// SETUP ▸ Complex: a+bi or r∠θ (manual p.13).
enum CasioComplexFormat { rect, polar }

class CasioConfig {
  const CasioConfig({
    this.angle = CasioAngle.deg,
    this.displayFormat = CasioDisplayFormat.mathO,
    this.numberFormat = CasioNumberFormat.norm1,
    this.digits = 0,
    this.mixedFractions = false,
    this.recurring = true,
    this.phonePercent = true,
    this.commaDecimal = false,
    this.decimalFirst = false,
    this.legacyPrecision = -1,
    this.useCasio = true,
    this.complexFormat = CasioComplexFormat.rect,
    this.statFreq = false,
    this.tableFg = false,
  });

  final CasioAngle angle;
  final CasioDisplayFormat displayFormat;
  final CasioNumberFormat numberFormat;

  /// 0-9 for Fix / Sci (Sci 0 means 10 significant digits).
  final int digits;

  /// SETUP ▸ ab/c (true) or d/c (false, the default).
  final bool mixedFractions;

  /// SETUP ▸ Rdec.
  final bool recurring;

  /// "Percent style: OmniCalc" (the default): `100+10%` = 110. False is the manual's postfix percent (`100+10%` = 100.1).
  final bool phonePercent;

  /// SETUP ▸ Disp ▸ Comma.
  final bool commaDecimal;

  /// OmniCalc setting "Result display: Decimal": results start as decimals (S⇔D gives the exact form).
  final bool decimalFirst;

  /// OmniCalc's existing precision setting (2, 4, 6, 8 or -1 for auto). A positive value rounds decimal results to that
  /// many places and drops trailing zeros, exactly as the legacy result formatter did.
  final int legacyPrecision;

  /// "Calculation style: Casio (default)" or false for "OmniCalc (legacy)" (the untouched TypeScript-port evaluator).
  final bool useCasio;

  /// SETUP ▸ Complex.
  final CasioComplexFormat complexFormat;

  /// SETUP ▸ STAT ▸ Frequency column on / off (used by STAT in Phase 7d-2).
  final bool statFreq;

  /// SETUP ▸ Table ▸ f(x),g(x) (true) or f(x) (false) (used by TABLE in Phase 7d-2).
  final bool tableFg;

  @override
  bool operator ==(Object other) =>
      other is CasioConfig &&
      other.angle == angle &&
      other.displayFormat == displayFormat &&
      other.numberFormat == numberFormat &&
      other.digits == digits &&
      other.mixedFractions == mixedFractions &&
      other.recurring == recurring &&
      other.phonePercent == phonePercent &&
      other.commaDecimal == commaDecimal &&
      other.decimalFirst == decimalFirst &&
      other.legacyPrecision == legacyPrecision &&
      other.useCasio == useCasio &&
      other.complexFormat == complexFormat &&
      other.statFreq == statFreq &&
      other.tableFg == tableFg;

  @override
  int get hashCode => Object.hash(angle, displayFormat, numberFormat, digits, mixedFractions, recurring, phonePercent,
      commaDecimal, decimalFirst, legacyPrecision, useCasio, complexFormat, statFreq, tableFg);

  CasioConfig copyWith({
    CasioAngle? angle,
    CasioDisplayFormat? displayFormat,
    CasioNumberFormat? numberFormat,
    int? digits,
    bool? mixedFractions,
    bool? recurring,
    bool? phonePercent,
    bool? commaDecimal,
    bool? decimalFirst,
    int? legacyPrecision,
    bool? useCasio,
    CasioComplexFormat? complexFormat,
    bool? statFreq,
    bool? tableFg,
  }) =>
      CasioConfig(
        angle: angle ?? this.angle,
        displayFormat: displayFormat ?? this.displayFormat,
        numberFormat: numberFormat ?? this.numberFormat,
        digits: digits ?? this.digits,
        mixedFractions: mixedFractions ?? this.mixedFractions,
        recurring: recurring ?? this.recurring,
        phonePercent: phonePercent ?? this.phonePercent,
        commaDecimal: commaDecimal ?? this.commaDecimal,
        decimalFirst: decimalFirst ?? this.decimalFirst,
        legacyPrecision: legacyPrecision ?? this.legacyPrecision,
        useCasio: useCasio ?? this.useCasio,
        complexFormat: complexFormat ?? this.complexFormat,
        statFreq: statFreq ?? this.statFreq,
        tableFg: tableFg ?? this.tableFg,
      );
}

/// Ans, PreAns and the variables A B C D E F M X Y. They survive AC, mode changes and power-off (manual p.35).
class CasioMemory {
  CasioMemory();

  CVal ans = CVal.zero;
  CVal preAns = CVal.zero;
  final Map<String, CVal> vars = <String, CVal>{for (final k in kVariableNames) k: CVal.zero};

  /// The text last shown as a result, so that typing on after `=` can use the full-precision Ans.
  String? ansText;

  void setAns(CVal v) {
    preAns = ans;
    ans = v;
  }

  void clearVariables() {
    for (final k in vars.keys.toList()) {
      vars[k] = CVal.zero;
    }
    ans = CVal.zero;
    preAns = CVal.zero;
    ansText = null;
  }

  CasioMemory copy() {
    final m = CasioMemory()
      ..ans = ans
      ..preAns = preAns
      ..ansText = ansText;
    m.vars
      ..clear()
      ..addAll(vars);
    return m;
  }

  bool get independentMemoryUsed => vars['M']!.v != 0;
}

const List<String> kVariableNames = <String>['A', 'B', 'C', 'D', 'E', 'F', 'M', 'X', 'Y'];
