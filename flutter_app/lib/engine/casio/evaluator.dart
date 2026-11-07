// Evaluator of the Casio engine (Phase 7b). Works on the AST of parser.dart with 15-digit values plus the exact layer.
// Every domain check below is a row of "Function Calculation Input Ranges and Precision" (manual p.98-100).

import 'dart:math' as math;

import '../js_number.dart';
import 'casio_constants_data.dart';
import 'casio_conversions.dart';
import 'config.dart';
import 'cval.dart';
import 'exact.dart';
import 'parser.dart';
import 'rat.dart';

/// Values of the OmniCalc constant words (Constants tab), identical to the legacy evaluator's table.
const Map<String, double> kLegacyConstants = <String, double>{
  'hbar': 1.054571817e-34,
  'h': 6.62607015e-34,
  'c': 299792458,
  'G': 6.67430e-11,
  'qe': 1.602176634e-19,
  'me': 9.1093837e-31,
  'mp': 1.67262192e-27,
  'kB': 1.380649e-23,
  'NA': 6.02214076e23,
  'eps0': 8.8541878128e-12,
  'mu0': 1.256637062e-6,
  'ke': 8.9875517923e9,
  'mn': 1.67492749804e-27,
  'R': 8.314462618,
  'sigma': 5.670374419e-8,
  'atm': 101325,
  'au': 1.495978707e11,
  'g': 9.80665,
  'phi': 1.618033988749895,
};

class CasioEvaluator {
  CasioEvaluator(this.cfg, this.mem, {math.Random? random}) : _rng = random ?? math.Random();

  final CasioConfig cfg;
  final CasioMemory mem;
  final math.Random _rng;

  // ----- public ---------------------------------------------------------------------------------------------------

  CasioResult run(Node root) {
    if (root is NSeq) {
      final disp = <CVal>[];
      CVal last = CVal.zero;
      for (var i = 0; i < root.stmts.length; i++) {
        last = eval(root.stmts[i]);
        if (i < root.stmts.length - 1) disp.add(last);
      }
      return CasioResult(value: last, disp: disp);
    }
    // a top-level ÷R keeps its remainder
    if (root is NBin && root.op == '÷R') {
      final a = eval(root.a);
      final b = eval(root.b);
      final qr = _divRem(a, b);
      if (qr != null) return CasioResult(value: qr.$1, remainder: qr.$2);
      return CasioResult(value: _div(a, b));
    }
    if (root is NCall && (root.name == 'pol' || root.name == 'rec')) {
      final pair = _polRec(root);
      return CasioResult(
        value: pair.$1,
        extra: <String, CVal>{root.name == 'pol' ? 'θ' : 'Y': pair.$2},
      );
    }
    final v = eval(root);
    final intResult = v.ex != null && v.ex!.isRational && v.ex!.rational.isInteger ? v.ex!.rational : null;
    return CasioResult(
      value: v,
      factorOf: intResult != null && !intResult.isNegative && intResult.n > BigInt.one && intResult.n < BigInt.from(10).pow(10)
          ? intResult.n.toInt()
          : null,
    );
  }

  CVal eval(Node n) {
    switch (n) {
      case NNum():
        return _number(n);
      case NName():
        return _name(n);
      case NNeg():
        return _neg(eval(n.a));
      case NBin():
        return _binary(n);
      case NPow():
        return _pow(eval(n.a), eval(n.b));
      case NPost():
        return _postfix(n);
      case NCall():
        return _call(n);
      case NSto():
        // only the quotient of a ÷R is stored (manual p.25)
        final v = eval(n.a);
        mem.vars[n.name] = v;
        return v;
      case NSeq():
        CVal last = CVal.zero;
        for (final s in n.stmts) {
          last = eval(s);
        }
        return last;
      case NDms():
        return _dmsLiteral(n);
    }
  }

  // ----- literals and names ----------------------------------------------------------------------------------------

  CVal _number(NNum n) {
    if (!n.decimal) {
      final r = Rat.parseDecimal(n.text);
      if (r == null) throw const CasioError(CasioErrorKind.syntax);
      return _check(CVal.exact(Ex.rational(r)));
    }
    final v = double.tryParse(n.text);
    if (v == null) throw const CasioError(CasioErrorKind.syntax);
    return _check(CVal.dec(v));
  }

  CVal _name(NName n) {
    switch (n.name) {
      case 'π':
        return CVal(kPi15, Ex.piMultiple(Rat.one));
      case 'e':
        return const CVal(kE15);
      case 'Ans':
        return mem.ans;
      case 'PreAns':
        return mem.preAns;
      case 'Ran#':
        final k = _rng.nextInt(1000);
        return CVal.exact(Ex.rational(Rat(BigInt.from(k), BigInt.from(1000))));
    }
    final v = mem.vars[n.name];
    if (v != null) return v;
    final c = kLegacyConstants[n.name];
    if (c != null) return CVal.dec(c);
    throw CasioError(CasioErrorKind.syntax, n.pos);
  }

  // ----- range ------------------------------------------------------------------------------------------------------

  /// Results outside ±9.999999999e99 are a Math ERROR; below 1e-99 they are 0 (manual p.97).
  CVal _check(CVal v) {
    if (!v.v.isFinite || v.v.abs() >= 1e100) throw kMathError;
    if (v.v != 0 && v.v.abs() < 1e-99) return CVal.zero;
    return v;
  }

  // ----- arithmetic -------------------------------------------------------------------------------------------------

  CVal _neg(CVal a) => CVal(-a.v, a.ex == null ? null : (-a.ex!), a.dms);

  CVal _add(CVal a, CVal b, {bool sub = false}) {
    final bb = sub ? _neg(b) : b;
    final ex = (a.ex != null && bb.ex != null) ? (a.ex! + bb.ex!) : null;
    final dms = a.dms && bb.dms;
    if (ex != null) return _check(CVal.exact(ex, dms: dms));
    return _check(CVal.dec(a.v + bb.v, dms: dms));
  }

  CVal _mul(CVal a, CVal b) {
    final ex = (a.ex != null && b.ex != null) ? (a.ex! * b.ex!) : null;
    final dms = (a.dms && !b.dms) || (!a.dms && b.dms);
    if (ex != null) return _check(CVal.exact(ex, dms: dms));
    return _check(CVal.dec(a.v * b.v, dms: dms));
  }

  CVal _div(CVal a, CVal b) {
    if (b.v == 0) throw kMathError;
    final dms = a.dms && !b.dms;
    if (a.ex != null && b.ex != null) {
      final ex = a.ex! / b.ex!;
      if (ex != null) return _check(CVal.exact(ex, dms: dms));
    }
    return _check(CVal.dec(a.v / b.v, dms: dms));
  }

  CVal _binary(NBin n) {
    switch (n.op) {
      case '+':
        return _add(eval(n.a), eval(n.b));
      case '-':
        return _add(eval(n.a), eval(n.b), sub: true);
      case '*':
        if (n.b is NCall && (n.b as NCall).name == 'conv' && n.implicit) {
          return _convert(eval(n.a), (n.b as NCall));
        }
        return _mul(eval(n.a), eval(n.b));
      case '/':
        return _div(eval(n.a), eval(n.b));
      case '÷R':
        final a = eval(n.a);
        final b = eval(n.b);
        final qr = _divRem(a, b);
        return qr != null ? qr.$1 : _div(a, b);
      case 'nPr':
        return _permComb(eval(n.a), eval(n.b), perm: true);
      case 'nCr':
        return _permComb(eval(n.a), eval(n.b), perm: false);
    }
    throw CasioError(CasioErrorKind.syntax, n.pos);
  }

  /// Quotient and remainder (manual p.25). Null when the calculation is an ordinary division instead.
  (CVal, CVal)? _divRem(CVal a, CVal b) {
    if (a.ex == null || b.ex == null || !a.ex!.isRational || !b.ex!.isRational) return null;
    final x = a.ex!.rational;
    final y = b.ex!.rational;
    if (!x.isInteger || !y.isInteger) return null;
    if (y.isZero || x.isNegative || y.isNegative) return null;
    if (x.abs().compareTo(Rat.fromInt(10000000000)) >= 0 || y.abs().compareTo(Rat.fromInt(10000000000)) >= 0) return null;
    final q = x / y;
    final qInt = q.n ~/ q.d; // floor, both positive
    if (qInt == BigInt.zero) return null; // quotient not a positive integer
    final rem = x - Rat(qInt) * y;
    if (rem.isZero || rem.isNegative) return null;
    return (CVal.exact(Ex.rational(Rat(qInt))), CVal.exact(Ex.rational(rem)));
  }

  // ----- power and roots --------------------------------------------------------------------------------------------

  CVal _pow(CVal a, CVal b) {
    final x = a.v;
    final y = b.v;
    // special cases of the domain table: x^y
    if (x == 0) {
      if (y <= 0) throw kMathError;
      return CVal.exact(Ex.zero);
    }
    final yIsInt = y == y.truncateToDouble();
    if (x < 0 && !yIsInt) {
      // only odd roots of negatives: y = m / (2n+1)
      final r = b.ex != null && b.ex!.isRational ? b.ex!.rational : null;
      if (r == null || r.d.isEven) throw kMathError;
    }
    if (y * (math.log(x.abs()) / math.ln10) >= 100 || y * (math.log(x.abs()) / math.ln10) <= -100) {
      if (y * (math.log(x.abs()) / math.ln10) >= 100) throw kMathError;
      return CVal.zero;
    }
    // exact integer powers
    if (a.ex != null && b.ex != null && b.ex!.isRational) {
      final r = b.ex!.rational;
      if (r.isInteger && r.n.abs() <= BigInt.from(64)) {
        final ex = a.ex!.powInt(r.n.toInt());
        if (ex != null) return _check(CVal.exact(ex));
      } else if (!r.isInteger && a.ex!.isRational && !a.ex!.rational.isNegative && r.d <= BigInt.from(12)) {
        final ex = _exactRationalPower(a.ex!.rational, r);
        if (ex != null) return _check(CVal.exact(ex));
      }
    }
    double res;
    if (x < 0) {
      // odd root of a negative number: the sign follows the numerator of the exponent
      final r = b.ex!.rational;
      final mag = dpow(-x, y);
      res = r.n.isOdd ? -mag : mag;
    } else {
      res = dpow(x, y);
    }
    return _check(CVal.dec(res));
  }

  Ex? _exactRationalPower(Rat base, Rat e) {
    // base^(p/q) with a perfect q-th root of numerator and denominator, or q = 2 (square roots)
    final q = e.d.toInt();
    final p = e.n.toInt();
    if (p.abs() > 64) return null;
    final rn = exactRoot(base.n, q);
    final rd = exactRoot(base.d, q);
    if (rn != null && rd != null) {
      return Ex.rational(Rat(rn, rd).pow(p));
    }
    if (q == 2) {
      final s = Ex.sqrtRational(base.pow(p));
      return s;
    }
    return null;
  }

  CVal _sqrt(CVal a) {
    if (a.v < 0) throw kMathError;
    if (a.v >= 1e100) throw kMathError;
    if (a.ex != null) {
      final ex = a.ex!.sqrt();
      if (ex != null) return CVal.exact(ex);
    }
    return _check(CVal.dec(math.sqrt(a.v)));
  }

  CVal _cbrt(CVal a) {
    if (a.v.abs() >= 1e100) throw kMathError;
    if (a.ex != null && a.ex!.isRational) {
      final r = a.ex!.rational;
      final rn = exactRoot(r.n.abs(), 3);
      final rd = exactRoot(r.d, 3);
      if (rn != null && rd != null) {
        final v = Rat(rn, rd);
        return CVal.exact(Ex.rational(r.isNegative ? -v : v));
      }
    }
    return _check(CVal.dec(jsCbrt(a.v)));
  }

  CVal _root(CVal n, CVal x) {
    if (n.v == 0) throw kMathError;
    if (x.v < 0) {
      // odd integer roots only
      if (n.v != n.v.truncateToDouble() || n.v.truncate().isEven) throw kMathError;
      final pos = _root(n, _neg(x));
      return _neg(pos);
    }
    if (x.v == 0) {
      if (n.v < 0) throw kMathError;
      return CVal.exact(Ex.zero);
    }
    final inv = _div(CVal.int(1), n);
    return _pow(x, inv);
  }

  // ----- postfix ------------------------------------------------------------------------------------------------------

  CVal _postfix(NPost n) {
    final a = eval(n.a);
    switch (n.op) {
      case '!':
        return _factorial(a);
      case '%':
        // Casio postfix percent: divide by 100
        return _div(a, CVal.int(100));
      case '°':
        return _angleIn(a, CasioAngle.deg);
      case 'r':
        return _angleIn(a, CasioAngle.rad);
      case 'g':
        return _angleIn(a, CasioAngle.gra);
    }
    throw CasioError(CasioErrorKind.syntax, n.pos);
  }

  /// `x°`, `xʳ`, `xᵍ`: the value is an angle in that unit; the result is in the current angle unit.
  CVal _angleIn(CVal a, CasioAngle unit) {
    if (unit == cfg.angle) return a;
    // degrees per unit
    CVal toDeg(CVal v) {
      switch (unit) {
        case CasioAngle.deg:
          return v;
        case CasioAngle.rad:
          return _mul(_mul(v, CVal.int(180)), _invPi);
        case CasioAngle.gra:
          return _mul(v, CVal.exact(Ex.rational(Rat(BigInt.from(9), BigInt.from(10)))));
      }
    }

    final deg = toDeg(a);
    switch (cfg.angle) {
      case CasioAngle.deg:
        return deg;
      case CasioAngle.rad:
        return _mul(_div(deg, CVal.int(180)), CVal(kPi15, Ex.piMultiple(Rat.one)));
      case CasioAngle.gra:
        return _mul(deg, CVal.exact(Ex.rational(Rat(BigInt.from(10), BigInt.from(9)))));
    }
  }

  CVal get _invPi => CVal.dec(1 / kPi15);

  CVal _factorial(CVal a) {
    final r = a.ex != null && a.ex!.isRational ? a.ex!.rational : null;
    if (r == null || !r.isInteger || r.isNegative) {
      if (a.v == a.v.truncateToDouble() && a.v >= 0 && a.v <= 69) {
        return _factorialInt(a.v.toInt());
      }
      throw kMathError;
    }
    if (r.n > BigInt.from(69)) throw kMathError;
    return _factorialInt(r.n.toInt());
  }

  CVal _factorialInt(int k) {
    var f = BigInt.one;
    for (var i = 2; i <= k; i++) {
      f *= BigInt.from(i);
    }
    return CVal.exact(Ex.rational(Rat(f)));
  }

  // ----- nPr, nCr -----------------------------------------------------------------------------------------------------

  CVal _permComb(CVal an, CVal ar, {required bool perm}) {
    final nn = _intArg(an);
    final rr = _intArg(ar);
    if (nn == null || rr == null) throw kMathError;
    if (nn.isNegative || rr.isNegative || rr > nn || nn >= BigInt.from(10).pow(10)) throw kMathError;
    var result = BigInt.one;
    final limit = BigInt.from(10).pow(100);
    if (perm) {
      for (var i = BigInt.zero; i < rr; i += BigInt.one) {
        result *= nn - i;
        if (result >= limit) throw kMathError;
      }
    } else {
      final k = rr < nn - rr ? rr : nn - rr;
      for (var i = BigInt.one; i <= k; i += BigInt.one) {
        result = result * (nn - k + i) ~/ i;
        if (result >= limit) throw kMathError;
      }
    }
    if (result >= limit) throw kMathError;
    return CVal.exact(Ex.rational(Rat(result)));
  }

  BigInt? _intArg(CVal a) {
    if (a.ex != null && a.ex!.isRational && a.ex!.rational.isInteger) return a.ex!.rational.n;
    if (a.v.isFinite && a.v == a.v.truncateToDouble() && a.v.abs() < 1e15) return BigInt.from(a.v);
    return null;
  }

  // ----- angles and trigonometry ------------------------------------------------------------------------------------

  /// The argument in degrees as an exact rational, when it is one.
  Rat? _exactDegrees(CVal a) {
    final ex = a.ex;
    if (ex == null) return null;
    switch (cfg.angle) {
      case CasioAngle.deg:
        return ex.isRational ? ex.rational : null;
      case CasioAngle.rad:
        if (ex.isPi) return ex.pi * Rat.fromInt(180);
        if (ex.isZero) return Rat.zero;
        return null;
      case CasioAngle.gra:
        return ex.isRational ? ex.rational * Rat(BigInt.from(9), BigInt.from(10)) : null;
    }
  }

  void _checkTrigRange(double v) {
    final x = v.abs();
    switch (cfg.angle) {
      case CasioAngle.deg:
        if (x >= 9e9) throw kMathError;
      case CasioAngle.rad:
        if (x >= 157079632.7) throw kMathError;
      case CasioAngle.gra:
        if (x >= 1e10) throw kMathError;
    }
  }

  /// Exact sin and cos of a multiple of 15 degrees.
  (Ex, Ex)? _specialSinCos(Rat deg) {
    final k15 = deg / Rat.fromInt(15);
    if (!k15.isInteger) return null;
    var k = (k15.n % BigInt.from(24)).toInt();
    if (k < 0) k += 24;
    // k * 15 degrees, k in 0..23
    Ex h(int num, int den) => Ex.rational(Rat(BigInt.from(num), BigInt.from(den)));
    Ex sq(int radicand, int coef, int den) => Ex.piMultiple(Rat.zero) == Ex.zero
        ? Ex.sqrtRational(Rat.fromInt(radicand))!.mulRat(Rat(BigInt.from(coef), BigInt.from(den)))
        : Ex.zero;
    final sixMinusTwo = (Ex.sqrtRational(Rat.fromInt(6))! - Ex.sqrtRational(Rat.fromInt(2))!)!;
    final sixPlusTwo = (Ex.sqrtRational(Rat.fromInt(6))! + Ex.sqrtRational(Rat.fromInt(2))!)!;
    // first quadrant values: 0, 15, 30, 45, 60, 75, 90
    final sin1 = <Ex>[
      Ex.zero,
      sixMinusTwo.mulRat(Rat(BigInt.one, BigInt.from(4))),
      h(1, 2),
      sq(2, 1, 2),
      sq(3, 1, 2),
      sixPlusTwo.mulRat(Rat(BigInt.one, BigInt.from(4))),
      Ex.one,
    ];
    Ex sinOf(int j) {
      // j: multiple of 15 in 0..23
      final q = j ~/ 6; // quadrant
      final i = j % 6;
      switch (q) {
        case 0:
          return sin1[i];
        case 1:
          return sin1[6 - i];
        case 2:
          return (-sin1[i])!;
        default:
          return (-sin1[6 - i])!;
      }
    }

    return (sinOf(k), sinOf((k + 6) % 24));
  }

  CVal _trig(String fn, CVal a) {
    _checkTrigRange(a.v);
    final exact = _exactDegrees(a);
    if (exact != null) {
      final sc = _specialSinCos(exact);
      if (sc != null) {
        final (s, c) = sc;
        switch (fn) {
          case 'sin':
            return CVal.exact(s);
          case 'cos':
            return CVal.exact(c);
          case 'tan':
            if (c.isZero) throw kMathError;
            final t = s / c;
            if (t != null) return CVal.exact(t);
            break;
        }
      }
    }
    // reduce the angle first so that sin(180°) is 0 and tan(90°) is an error, as on the unit
    var v = a.v;
    double rad;
    switch (cfg.angle) {
      case CasioAngle.deg:
        v = v.remainder(360);
        rad = v * kPi15 / 180;
      case CasioAngle.gra:
        v = v.remainder(400);
        rad = v * kPi15 / 200;
      case CasioAngle.rad:
        rad = v;
    }
    switch (fn) {
      case 'sin':
        return _check(CVal.dec(_clean(math.sin(rad))));
      case 'cos':
        return _check(CVal.dec(_clean(math.cos(rad))));
      case 'tan':
        final c = math.cos(rad);
        if (c.abs() < 1e-13) throw kMathError;
        return _check(CVal.dec(_clean(math.tan(rad))));
      case 'sec':
        final c = math.cos(rad);
        if (c.abs() < 1e-13) throw kMathError;
        return _check(CVal.dec(1 / c));
      case 'csc':
        final s = math.sin(rad);
        if (s.abs() < 1e-13) throw kMathError;
        return _check(CVal.dec(1 / s));
      case 'cot':
        final t = math.tan(rad);
        if (t.abs() < 1e-13) throw kMathError;
        return _check(CVal.dec(1 / t));
    }
    throw kMathError;
  }

  double _clean(double v) => v.abs() < 1e-14 ? 0 : v;

  CVal _inverseTrig(String fn, CVal a) {
    double r;
    switch (fn) {
      case 'asin':
        if (a.v.abs() > 1) throw kMathError;
        r = math.asin(a.v);
      case 'acos':
        if (a.v.abs() > 1) throw kMathError;
        r = math.acos(a.v);
      default:
        r = math.atan(a.v);
    }
    return _angleResult(r);
  }

  /// Radians -> the current angle unit, with an exact form when the result is a nice angle.
  CVal _angleResult(double rad) {
    switch (cfg.angle) {
      case CasioAngle.rad:
        final q = rad / kPi15;
        for (final den in const <int>[1, 2, 3, 4, 6, 12]) {
          final num = (q * den).roundToDouble();
          if ((q * den - num).abs() < 1e-12 && num != 0) {
            return CVal(round15(rad), Ex.piMultiple(Rat(BigInt.from(num.toInt()), BigInt.from(den))));
          }
        }
        return CVal.dec(rad);
      case CasioAngle.deg:
        final d = round15(rad * 180 / kPi15);
        return _niceAngle(d);
      case CasioAngle.gra:
        final g = round15(rad * 200 / kPi15);
        return _niceAngle(g);
    }
  }

  CVal _niceAngle(double d) {
    final r = d.roundToDouble();
    if ((d - r).abs() < 1e-10) return CVal.exact(Ex.int(r.toInt()));
    return CVal.dec(d);
  }

  // ----- logarithms and exponentials ---------------------------------------------------------------------------------

  CVal _ln(CVal a) {
    if (a.v <= 0 || a.v > 9.999999999e99) throw kMathError;
    if (a.ex != null && a.ex!.isRational && a.ex!.rational == Rat.one) return CVal.exact(Ex.zero);
    return _check(CVal.dec(math.log(a.v)));
  }

  CVal _log10(CVal a) {
    if (a.v <= 0 || a.v > 9.999999999e99) throw kMathError;
    final ex = _exactLog(10, a);
    if (ex != null) return ex;
    return _check(CVal.dec(jsLog10(a.v)));
  }

  /// log base `b` of x, `b` > 1 an integer: exact when x is a power of b.
  CVal? _exactLog(int b, CVal a) {
    if (a.ex == null || !a.ex!.isRational) return null;
    var r = a.ex!.rational;
    if (r.isNegative || r.isZero) return null;
    final base = Rat.fromInt(b);
    var k = 0;
    if (r == Rat.one) return CVal.exact(Ex.zero);
    if (r.compareTo(Rat.one) > 0) {
      while (r.compareTo(Rat.one) > 0 && k < 400) {
        r = r / base;
        k++;
      }
      return r == Rat.one ? CVal.exact(Ex.int(k)) : null;
    }
    while (r.compareTo(Rat.one) < 0 && k < 400) {
      r = r * base;
      k++;
    }
    return r == Rat.one ? CVal.exact(Ex.int(-k)) : null;
  }

  CVal _logBase(CVal base, CVal x) {
    if (x.v <= 0 || base.v <= 0 || base.v == 1) throw kMathError;
    if (x.v > 9.999999999e99 || base.v > 9.999999999e99) throw kMathError;
    if (base.ex != null && base.ex!.isRational && base.ex!.rational.isInteger && base.ex!.rational.n > BigInt.one) {
      final ex = _exactLog(base.ex!.rational.n.toInt(), x);
      if (ex != null) return ex;
    }
    return _check(CVal.dec(math.log(x.v) / math.log(base.v)));
  }

  CVal _expE(CVal a) {
    if (a.v > 230.2585092) throw kMathError;
    if (a.v < -230.2585092) return CVal.zero;
    if (a.ex != null && a.ex!.isZero) return CVal.exact(Ex.one);
    return _check(CVal.dec(math.exp(a.v)));
  }

  // ----- hyperbolic ---------------------------------------------------------------------------------------------------

  CVal _hyperbolic(String fn, CVal a) {
    final x = a.v;
    switch (fn) {
      case 'sinh':
        if (x.abs() > 230.2585092) throw kMathError;
        return _check(CVal.dec(jsSinh(x)));
      case 'cosh':
        if (x.abs() > 230.2585092) throw kMathError;
        return _check(CVal.dec(jsCosh(x)));
      case 'tanh':
        return _check(CVal.dec(jsTanh(x)));
      case 'asinh':
        if (x.abs() > 4.999999999e99) throw kMathError;
        return _check(CVal.dec(jsAsinh(x)));
      case 'acosh':
        if (x < 1 || x > 4.999999999e99) throw kMathError;
        return _check(CVal.dec(x == 1 ? 0 : jsAcosh(x)));
      case 'atanh':
        if (x.abs() > 0.9999999999) throw kMathError;
        return _check(CVal.dec(jsAtanh(x)));
      case 'sech':
        if (x.abs() > 230.2585092) throw kMathError;
        return _check(CVal.dec(1 / jsCosh(x)));
      case 'csch':
        if (x == 0 || x.abs() > 230.2585092) throw kMathError;
        return _check(CVal.dec(1 / jsSinh(x)));
      case 'coth':
        if (x == 0) throw kMathError;
        return _check(CVal.dec(1 / jsTanh(x)));
    }
    throw kMathError;
  }

  // ----- DMS ----------------------------------------------------------------------------------------------------------

  CVal _dmsLiteral(NDms n) {
    final d = eval(n.d);
    final m = n.m == null ? CVal.zero : eval(n.m!);
    final s = n.s == null ? CVal.zero : eval(n.s!);
    if (d.v.abs() >= 1e100 || m.v < 0 || s.v < 0) throw kMathError;
    final deg = _add(_add(d, _div(m, CVal.int(60))), _div(s, CVal.int(3600)));
    return deg.withDms(true);
  }

  // ----- rounding functions ---------------------------------------------------------------------------------------------

  CVal _intFromDouble(double v) {
    if (v.abs() < 1e15) return CVal.exact(Ex.rational(Rat(BigInt.from(v))));
    return CVal.dec(v);
  }

  CVal _floorVal(CVal a) {
    if (a.ex != null && a.ex!.isRational) {
      final r = a.ex!.rational;
      var q = r.n ~/ r.d;
      if (r.isNegative && r.n % r.d != BigInt.zero) q -= BigInt.one;
      return CVal.exact(Ex.rational(Rat(q)));
    }
    return _intFromDouble(a.v.floorToDouble());
  }

  CVal _truncVal(CVal a) {
    if (a.ex != null && a.ex!.isRational) {
      final r = a.ex!.rational;
      return CVal.exact(Ex.rational(Rat(r.n ~/ r.d)));
    }
    return _intFromDouble(a.v.truncateToDouble());
  }

  /// `Rnd(x)`: rounds to the current display digits setting and replaces the internal value (manual p.46).
  CVal _rnd(CVal a) {
    switch (cfg.numberFormat) {
      case CasioNumberFormat.fix:
        return CVal.dec(jsParseFloat(jsToFixed(a.v, cfg.digits)));
      case CasioNumberFormat.sci:
        final d = cfg.digits == 0 ? 10 : cfg.digits;
        return CVal.dec(jsParseFloat(jsToPrecision(a.v, d)));
      default:
        return CVal.dec(jsParseFloat(jsToPrecision(a.v, 10)));
    }
  }

  // ----- calls ----------------------------------------------------------------------------------------------------------

  CVal _need1(NCall c) {
    if (c.args.length != 1) throw CasioError(CasioErrorKind.syntax, c.pos);
    return eval(c.args[0]);
  }

  (CVal, CVal) _need2(NCall c) {
    if (c.args.length != 2) throw CasioError(CasioErrorKind.syntax, c.pos);
    return (eval(c.args[0]), eval(c.args[1]));
  }

  CVal _call(NCall c) {
    switch (c.name) {
      case 'sin':
      case 'cos':
      case 'tan':
      case 'sec':
      case 'csc':
      case 'cot':
        return _trig(c.name, _need1(c));
      case 'asin':
      case 'acos':
      case 'atan':
        return _inverseTrig(c.name, _need1(c));
      case 'sinh':
      case 'cosh':
      case 'tanh':
      case 'asinh':
      case 'acosh':
      case 'atanh':
      case 'sech':
      case 'csch':
      case 'coth':
        return _hyperbolic(c.name, _need1(c));
      case 'ln':
        return _ln(_need1(c));
      case 'log':
        if (c.args.length == 2) {
          final (b, x) = _need2(c);
          return _logBase(b, x);
        }
        return _log10(_need1(c));
      case 'log2':
        return _logBase(CVal.int(2), _need1(c));
      case 'logb':
        final (b, x) = _need2(c);
        return _logBase(b, x);
      case 'exp':
        return _expE(_need1(c));
      case 'sqrt':
        return _sqrt(_need1(c));
      case 'cbrt':
        return _cbrt(_need1(c));
      case 'root':
        final (n, x) = _need2(c);
        return _root(n, x);
      case 'abs':
        final a = _need1(c);
        return a.v < 0 ? _neg(a) : a;
      case 'round':
        final a = _need1(c);
        return _intFromDouble(jsRound(a.v));
      case 'floor':
      case 'intg':
        return _floorVal(_need1(c));
      case 'ceil':
        final a = _need1(c);
        return _neg(_floorVal(_neg(a)));
      case 'int':
        return _truncVal(_need1(c));
      case 'sign':
        final a = _need1(c);
        return CVal.int(a.v > 0 ? 1 : (a.v < 0 ? -1 : 0));
      case 'rnd':
        return _rnd(_need1(c));
      case 'mod':
        final (a, b) = _need2(c);
        if (b.v == 0) throw kMathError;
        final r = (a.v % b.v + b.v) % b.v;
        return CVal.dec(r);
      case 'nPr':
        final (a, b) = _need2(c);
        return _permComb(a, b, perm: true);
      case 'nCr':
        final (a, b) = _need2(c);
        return _permComb(a, b, perm: false);
      case 'gcd':
        final (a, b) = _need2(c);
        return _gcdLcm(a, b, gcd: true);
      case 'lcm':
        final (a, b) = _need2(c);
        return _gcdLcm(a, b, gcd: false);
      case 'ranint':
        final (a, b) = _need2(c);
        final lo = _intArg(a);
        final hi = _intArg(b);
        if (lo == null || hi == null) throw kArgumentError;
        final lim = BigInt.from(10).pow(10);
        if (lo >= hi || lo.abs() >= lim || hi.abs() >= lim || hi - lo >= lim) throw kArgumentError;
        final span = (hi - lo + BigInt.one).toInt();
        return CVal.int(lo.toInt() + _rng.nextInt(span));
      case 'const':
        final a = _need1(c);
        final k = _intArg(a);
        if (k == null || k < BigInt.one || k > BigInt.from(40)) throw kArgumentError;
        return CVal.dec(kCasioConstants[k.toInt() - 1].value);
      case 'dms':
        return _need1(c).withDms(true);
      case 'pol':
      case 'rec':
        // as a sub-expression only the first output is used
        return _polRec(c).$1;
      case 'conv':
        // `CONV(n)` on its own (no value before it) converts 1
        return _convert(CVal.int(1), c);
    }
    throw CasioError(CasioErrorKind.syntax, c.pos);
  }

  CVal _gcdLcm(CVal a, CVal b, {required bool gcd}) {
    final x = _intArg(a);
    final y = _intArg(b);
    if (x == null || y == null) throw kArgumentError;
    final lim = BigInt.from(10).pow(10);
    if (x.abs() >= lim || y.abs() >= lim) throw kArgumentError;
    if (!gcd && (x.isNegative || y.isNegative)) throw kArgumentError;
    final g = x.abs().gcd(y.abs());
    final r = gcd ? g : (g == BigInt.zero ? BigInt.zero : x.abs() * y.abs() ~/ g);
    return CVal.exact(Ex.rational(Rat(r)));
  }

  /// Metric conversion: the value before `CONV(n)` (manual p.53-55).
  CVal _convert(CVal value, NCall c) {
    if (c.args.length != 1) throw CasioError(CasioErrorKind.syntax, c.pos);
    final k = _intArg(eval(c.args[0]));
    if (k == null || k < BigInt.one || k > BigInt.from(40)) throw kArgumentError;
    final conv = kCasioConversions[k.toInt() - 1];
    return _check(CVal.dec(conv.apply(value.v)));
  }

  // ----- Pol and Rec ---------------------------------------------------------------------------------------------------

  /// Pol(x, y) -> (r, θ) and Rec(r, θ) -> (x, y). The results are stored in X and Y (manual p.43-44).
  (CVal, CVal) _polRec(NCall c) {
    final (a, b) = _need2(c);
    if (c.name == 'pol') {
      if (a.v.abs() > 9.999999999e99 || b.v.abs() > 9.999999999e99) throw kMathError;
      final x2 = _mul(a, a);
      final y2 = _mul(b, b);
      final sum = _add(x2, y2);
      final r = _sqrt(sum);
      double th;
      if (a.v == 0 && b.v == 0) {
        th = 0;
      } else {
        th = math.atan2(b.v, a.v);
      }
      final theta = _angleResult(th);
      mem.vars['X'] = r;
      mem.vars['Y'] = theta;
      return (r, theta);
    }
    if (a.v < 0 || a.v > 9.999999999e99) throw kMathError;
    _checkTrigRange(b.v);
    final x = _mul(a, _trig('cos', b));
    final y = _mul(a, _trig('sin', b));
    mem.vars['X'] = x;
    mem.vars['Y'] = y;
    return (x, y);
  }
}

extension on Ex {
  /// Multiplication by a rational (never null for a pure rational factor).
  Ex mulRat(Rat r) => (this * Ex.rational(r)) ?? this;
}
