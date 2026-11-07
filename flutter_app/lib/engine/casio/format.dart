// Result formatting of the Casio engine (Phase 7b): Norm1/Norm2/Fix/Sci/ENG, fractions, √ and π forms, recurring decimals,
// DMS, and the S⇔D cycle (manual p.18-31, p.11-12).

import '../js_number.dart';
import 'config.dart';
import 'cval.dart';
import 'exact.dart';
import 'rat.dart';

/// One way of showing a result. [display] is what the screen shows, [expr] is re-parsable text (what becomes the expression
/// when the result is reused). Both are the same for plain numbers.
class CasioShown {
  const CasioShown(this.display, this.expr, {this.kind = CasioShownKind.decimal});
  final String display;
  final String expr;
  final CasioShownKind kind;
}

enum CasioShownKind { integer, fraction, mixed, surd, piForm, recurring, decimal, dms }

class CasioFormatter {
  const CasioFormatter(this.cfg);
  final CasioConfig cfg;

  static const Map<String, String> _sup = <String, String>{
    '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹', '-': '⁻',
  };

  // ----- cycle (S⇔D) ----------------------------------------------------------------------------------------------

  /// The forms a result can be switched between with S⇔D, in order; the first one is what `=` shows.
  List<CasioShown> forms(CVal v) {
    if (v.dms) {
      return <CasioShown>[_dms(v.v), _decimalShown(v.v)];
    }
    final exact = _exactForm(v);
    final decimal = _decimalShown(v.v);
    final recurring = cfg.recurring ? _recurring(v) : null;
    final isInt = exact != null && exact.kind == CasioShownKind.integer;
    if (exact == null || isInt) return <CasioShown>[decimal];
    final decimalFirst = cfg.decimalFirst || cfg.displayFormat != CasioDisplayFormat.mathO;
    final out = <CasioShown>[];
    if (decimalFirst) {
      out.add(decimal);
      out.add(exact);
      if (recurring != null) out.add(recurring);
    } else {
      out.add(exact);
      if (recurring != null) out.add(recurring);
      out.add(decimal);
    }
    return out;
  }

  CasioShown first(CVal v) => forms(v).first;

  /// Mixed ⇔ improper (SHIFT S⇔D). Null when the result is not a fraction.
  CasioShown? toggleMixed(CVal v) {
    final r = v.ex != null && v.ex!.isRational ? v.ex!.rational : null;
    if (r == null || r.isInteger || r.n.abs() < r.d) return null; // only an improper fraction has a mixed form
    final wantMixed = !cfg.mixedFractions;
    return _fraction(r, mixed: wantMixed, force: true);
  }

  // ----- exact forms ---------------------------------------------------------------------------------------------------

  CasioShown? _exactForm(CVal v) {
    final ex = v.ex;
    if (ex == null) return null;
    if (ex.isRational) {
      final r = ex.rational;
      if (r.isInteger) {
        if (r.n.abs() >= BigInt.from(10).pow(10)) return null;
        return CasioShown(r.n.toString(), r.n.toString(), kind: CasioShownKind.integer);
      }
      return _fraction(r, mixed: cfg.mixedFractions);
    }
    if (ex.isPi) return _piForm(ex.pi, v.v);
    return _surd(ex);
  }

  /// Improper or mixed fraction. A fraction needs numerator + denominator of at most 10 digits (manual p.22).
  CasioShown? _fraction(Rat r, {required bool mixed, bool force = false}) {
    final neg = r.isNegative ? '-' : '';
    final n = r.n.abs();
    final d = r.d;
    final whole = n ~/ d;
    final mixedUsable = mixed && whole > BigInt.zero;
    if (mixedUsable) {
      final rem = n - whole * d;
      final digits = whole.toString().length + rem.toString().length + d.toString().length + 2;
      if (digits <= 10) {
        return CasioShown('$neg$whole⌟$rem⌟$d', '$neg($whole+$rem÷$d)', kind: CasioShownKind.mixed);
      }
      if (force) return null;
    }
    final digits = n.toString().length + d.toString().length + 1;
    if (digits > 10) return null;
    return CasioShown('$neg$n⌟$d', '$neg($n÷$d)', kind: CasioShownKind.fraction);
  }

  CasioShown? _piForm(Rat coef, double value) {
    if (value.abs() >= 1e6) return null;
    final neg = coef.isNegative ? '-' : '';
    final n = coef.n.abs();
    final d = coef.d;
    if (n > BigInt.from(1000000) || d > BigInt.from(1000000)) return null;
    final String body;
    if (d == BigInt.one) {
      body = n == BigInt.one ? 'π' : '${n}π';
    } else {
      body = '${n == BigInt.one ? '' : n}π÷$d';
    }
    return CasioShown('$neg$body', '$neg($body)', kind: CasioShownKind.piForm);
  }

  /// Two terms at most, coefficients in the ranges of manual p.18-19.
  CasioShown? _surd(Ex ex) {
    if (ex.terms.isEmpty || ex.terms.length > 2) return null;
    var den = BigInt.one;
    for (final c in ex.terms.values) {
      den = den * c.d ~/ den.gcd(c.d);
    }
    if (den >= BigInt.from(100)) return null;
    final items = <(int, BigInt)>[]; // radicand, integer numerator
    for (final e in ex.terms.entries) {
      final num = e.value.n * (den ~/ e.value.d);
      if (num.abs() >= BigInt.from(100)) return null;
      if (e.key >= 1000) return null;
      items.add((e.key, num));
    }
    // integer term first, then radicals with the largest radicand first
    items.sort((a, b) {
      if (a.$1 == 1) return -1;
      if (b.$1 == 1) return 1;
      return b.$1.compareTo(a.$1);
    });
    final sb = StringBuffer();
    for (var i = 0; i < items.length; i++) {
      final (k, num) = items[i];
      final neg = num.isNegative;
      final mag = num.abs();
      if (i == 0) {
        if (neg) sb.write('-');
      } else {
        sb.write(neg ? '-' : '+');
      }
      if (k == 1) {
        sb.write(mag);
      } else {
        if (mag != BigInt.one) sb.write(mag);
        sb.write('√$k');
      }
    }
    var body = sb.toString();
    if (den != BigInt.one) {
      body = items.length > 1 ? '($body)÷$den' : '$body÷$den';
    }
    return CasioShown(body, '($body)', kind: CasioShownKind.surd);
  }

  // ----- recurring decimals ------------------------------------------------------------------------------------------

  CasioShown? _recurring(CVal v) {
    final ex = v.ex;
    if (ex == null || !ex.isRational) return null;
    final r = ex.rational;
    if (r.isInteger) return null;
    final n = r.n.abs();
    final d = r.d;
    final whole = n ~/ d;
    final digitsOk = whole.toString().length + (n - whole * d).toString().length + d.toString().length + 2 <= 10;
    if (!digitsOk) return null;
    // d = 2^a 5^b m: non-terminating only when m > 1
    var m = d;
    var pre = 0;
    var twos = 0;
    var fives = 0;
    while (m % BigInt.two == BigInt.zero) {
      m ~/= BigInt.two;
      twos++;
    }
    while (m % BigInt.from(5) == BigInt.zero) {
      m ~/= BigInt.from(5);
      fives++;
    }
    pre = twos > fives ? twos : fives;
    if (m == BigInt.one) return null; // terminating
    // period: multiplicative order of 10 mod m
    var period = 1;
    var p = BigInt.from(10) % m;
    while (p != BigInt.one) {
      p = p * BigInt.from(10) % m;
      period++;
      if (period > 98) return null;
    }
    if (pre + period + 2 > 99) return null;
    // long division
    final sb = StringBuffer(r.isNegative ? '-' : '');
    sb.write(whole);
    sb.write('.');
    var rem = n - whole * d;
    final ten = BigInt.from(10);
    final preDigits = StringBuffer();
    for (var i = 0; i < pre; i++) {
      rem *= ten;
      preDigits.write(rem ~/ d);
      rem = rem % d;
    }
    final per = StringBuffer();
    for (var i = 0; i < period; i++) {
      rem *= ten;
      per.write(rem ~/ d);
      rem = rem % d;
    }
    sb.write(preDigits);
    for (final ch in per.toString().split('')) {
      sb.write(ch);
      sb.write('̅'); // combining overline over each digit of the period
    }
    final fraction = _fraction(r, mixed: false, force: true);
    return CasioShown(sb.toString(), fraction?.expr ?? '${r.n}÷${r.d}', kind: CasioShownKind.recurring);
  }

  // ----- decimals ---------------------------------------------------------------------------------------------------

  CasioShown _decimalShown(double x) {
    final s = decimalText(x);
    return CasioShown(_present(s.$1), s.$2, kind: CasioShownKind.decimal);
  }

  String _present(String s) => cfg.commaDecimal ? s.replaceAll('.', ',') : s;

  /// (display, re-parsable) text of a decimal in the current number format.
  (String, String) decimalText(double x) {
    if (!x.isFinite) return ('Math ERROR', 'Math ERROR');
    if (x == 0) {
      if (cfg.numberFormat == CasioNumberFormat.fix && cfg.digits > 0) {
        final z = '0.${'0' * cfg.digits}';
        return (z, z);
      }
      return ('0', '0');
    }
    final neg = x < 0 ? '-' : '';
    final a = x.abs();
    switch (cfg.numberFormat) {
      case CasioNumberFormat.fix:
        if (a < 1e10) {
          final f = jsToFixed(a, cfg.digits);
          return ('$neg$f', '$neg$f');
        }
        return _sci(a, 10, neg);
      case CasioNumberFormat.sci:
        return _sci(a, cfg.digits == 0 ? 10 : cfg.digits, neg);
      case CasioNumberFormat.norm1:
      case CasioNumberFormat.norm2:
        final (digits, e) = _digitsAndExp(a, 10);
        final lowLimit = cfg.numberFormat == CasioNumberFormat.norm1 ? -2 : -9;
        if (e >= 10 || e < lowLimit) return _sciFromDigits(digits, e, neg, trim: true);
        if (cfg.legacyPrecision > 0 && cfg.numberFormat == CasioNumberFormat.norm1) {
          // OmniCalc's own "decimal places" setting: round, then drop trailing zeros (legacy formatResult)
          final t = jsToString(jsParseFloat(jsToFixed(a, cfg.legacyPrecision)));
          return ('$neg$t', '$neg$t');
        }
        final plain = _plain(digits, e);
        return ('$neg$plain', '$neg$plain');
    }
  }

  /// Significant digits (as a string of exactly [count] digits) and the decimal exponent of a positive number.
  (String, int) _digitsAndExp(double a, int count) {
    final s = jsToExponential(a, count - 1); // d.ddde+n
    final parts = s.split('e');
    final digits = parts[0].replaceAll('.', '');
    return (digits, int.parse(parts[1].replaceFirst('+', '')));
  }

  String _plain(String digits, int e) {
    final d = digits.replaceFirst(RegExp(r'0+$'), '');
    final dd = d.isEmpty ? '0' : d;
    if (e >= 0) {
      final intPart = dd.length > e + 1 ? dd.substring(0, e + 1) : dd.padRight(e + 1, '0');
      final frac = dd.length > e + 1 ? dd.substring(e + 1) : '';
      return frac.isEmpty ? intPart : '$intPart.$frac';
    }
    return '0.${'0' * (-e - 1)}$dd';
  }

  (String, String) _sci(double a, int sig, String neg) {
    final (digits, e) = _digitsAndExp(a, sig);
    return _sciFromDigits(digits, e, neg, trim: false);
  }

  (String, String) _sciFromDigits(String digits, int e, String neg, {required bool trim}) {
    var d = digits;
    if (trim) {
      d = d.replaceFirst(RegExp(r'0+$'), '');
      if (d.isEmpty) d = '0';
    }
    final mant = d.length > 1 ? '${d[0]}.${d.substring(1)}' : d;
    final expSup = '$e'.split('').map((c) => _sup[c] ?? c).join();
    return ('$neg$mant×10$expSup', '$neg$mant×10^($e)');
  }

  // ----- ENG --------------------------------------------------------------------------------------------------------

  /// Engineering display with the exponent [n] (a multiple of 3), 10 significant digits at most (manual p.15).
  CasioShown eng(double x, int n) {
    if (x == 0 || !x.isFinite) return _decimalShown(x);
    final neg = x < 0 ? '-' : '';
    final (digits, e) = _digitsAndExp(x.abs(), 10);
    final shifted = e - n; // position of the point relative to the first digit
    final plain = _plain(digits, shifted);
    final expSup = '$n'.split('').map((c) => _sup[c] ?? c).join();
    return CasioShown(_present('$neg$plain×10$expSup'), '$neg$plain×10^($n)');
  }

  /// The next ENG exponent: multiples of 3 to the right (increasing) or left.
  static int nextEng(int n, {required bool right}) => right ? (n ~/ 3 + (n >= 0 ? 1 : (n % 3 == 0 ? 1 : 0))) * 3 : _prevEng(n);

  static int _prevEng(int n) => ((n - 1) / 3).floor() * 3;

  // ----- DMS --------------------------------------------------------------------------------------------------------

  CasioShown _dms(double deg) {
    final neg = deg < 0 ? '-' : '';
    var secondsTotal = double.parse((deg.abs() * 3600).toStringAsFixed(6));
    var d = (secondsTotal / 3600).floor();
    secondsTotal -= d * 3600;
    var m = (secondsTotal / 60).floor();
    var s = double.parse((secondsTotal - m * 60).toStringAsFixed(6));
    if (s >= 60) {
      s -= 60;
      m += 1;
    }
    if (m >= 60) {
      m -= 60;
      d += 1;
    }
    final sText = s == s.truncateToDouble() ? '${s.toInt()}' : jsToString(s);
    final text = '$neg$d°$m′$sText″';
    return CasioShown(text, '$neg${jsToString(deg.abs())}', kind: CasioShownKind.dms);
  }
}
