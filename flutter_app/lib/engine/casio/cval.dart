// Value and error types of the Casio engine (Phase 8b).

import 'dart:math' as math;

import '../js_number.dart';
import 'exact.dart';

/// Every error message of the fx-991ES PLUS (manual p.92-95). The text is exactly what the unit shows.
enum CasioErrorKind {
  math('Math ERROR'),
  stack('Stack ERROR'),
  syntax('Syntax ERROR'),
  argument('Argument ERROR'),
  dimension('Dimension ERROR'),
  variable('Variable ERROR'),
  cantSolve("Can't Solve"),
  insufficientMem('Insufficient MEM'),
  timeOut('Time Out');

  const CasioErrorKind(this.message);
  final String message;
}

class CasioError implements Exception {
  const CasioError(this.kind, [this.position]);

  final CasioErrorKind kind;

  /// Character offset in the input where the error was found, when known (◀ ▶ jump there after an error).
  final int? position;

  String get message => kind.message;

  @override
  String toString() => message;
}

const CasioError kMathError = CasioError(CasioErrorKind.math);
const CasioError kSyntaxError = CasioError(CasioErrorKind.syntax);
const CasioError kArgumentError = CasioError(CasioErrorKind.argument);

/// Internal numbers have 15 significant digits.
double round15(double v) {
  if (v == 0 || !v.isFinite) return v;
  return jsParseFloat(jsToPrecision(v, 15));
}

/// A value on the calculator: the 15-digit double [v] plus, when it is known, its exact form.
class CVal {
  const CVal(this.v, [this.ex, this.dms = false]);

  factory CVal.exact(Ex ex, {bool dms = false}) => CVal(round15(ex.toDouble()), ex, dms);

  factory CVal.int(int i) => CVal(i.toDouble(), Ex.int(i));

  factory CVal.dec(double v, {bool dms = false}) => CVal(round15(v), null, dms);

  final double v;
  final Ex? ex;

  /// The value was written or produced in degrees-minutes-seconds and is shown that way (manual p.23).
  final bool dms;

  bool get isExactRational => ex != null && ex!.isRational;

  /// The magnitude limits of the unit: ±1e-99 … ±9.999999999e99, or 0.
  bool get inRange => v.isFinite && (v == 0 || (v.abs() >= 1e-99 && v.abs() < 1e100));

  CVal withDms(bool d) => CVal(v, ex, d);

  static const CVal zero = CVal(0, null);

  @override
  String toString() => 'CVal($v${ex != null ? ' = $ex' : ''})';
}

/// The result of a whole calculation.
class CasioResult {
  const CasioResult({
    required this.value,
    this.extra = const <String, CVal>{},
    this.remainder,
    this.disp = const <CVal>[],
    this.factorOf,
  });

  /// The value shown (and stored in Ans).
  final CVal value;

  /// Additional named results, for example `r` and `θ` of Pol, or `X` and `Y` of Rec.
  final Map<String, CVal> extra;

  /// `÷R`: the quotient is [value]; this is the remainder.
  final CVal? remainder;

  /// Intermediate results of a multi-statement line (the `Disp` annunciator).
  final List<CVal> disp;

  /// Set when the result is the integer that `FACT` may factor.
  final int? factorOf;
}

double degToRad(double d) => d * 3.14159265358980 / 180;

/// pi and e as the unit holds them internally (manual p.36).
const double kPi15 = 3.14159265358980;
const double kE15 = 2.71828182845904;

double dpow(double a, double b) => math.pow(a, b).toDouble();
