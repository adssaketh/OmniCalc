// STAT mode of the Casio engine (Phase 7d-2, manual p.57-66): the eight calculation types, the Statistics Editor data, the
// Sum / Var / Reg / MinMax / Distr commands, estimated values and the normal distribution functions P( Q( R( ▸t.

import 'dart:math' as math;

import 'cval.dart';
import 'engine.dart';
import 'exact.dart';
import 'rat.dart';

/// Calculation types of the STAT menu (manual p.58).
enum StatType {
  oneVar('1-VAR', false),
  linear('A+BX', true),
  quadratic('_+CX²', true),
  ln('ln X', true),
  exp('e^X', true),
  abExp('A·B^X', true),
  power('A·X^B', true),
  inverse('1/X', true);

  const StatType(this.title, this.paired);

  final String title;
  final bool paired;
}

/// Rows the Statistics Editor offers (manual p.59): 40 with X only or X and Y, 20 with X and FREQ, 26 with X, Y and FREQ.
int statEditorRows(StatType type, bool freq) {
  if (!freq) return 40;
  return type.paired ? 26 : 20;
}

/// The data of the Statistics Editor: one entry per row, null for an empty cell.
class StatData {
  StatData(this.type, this.freqColumn)
      : xs = List<CVal?>.filled(statEditorRows(type, freqColumn), null),
        ys = List<CVal?>.filled(statEditorRows(type, freqColumn), null),
        fs = List<CVal?>.filled(statEditorRows(type, freqColumn), null);

  final StatType type;
  final bool freqColumn;
  final List<CVal?> xs;
  final List<CVal?> ys;
  final List<CVal?> fs;

  int get rows => xs.length;

  /// The same cells under another calculation type of the same kind (1-VAR, or paired): STAT/DIST ▸ Type keeps the data.
  StatData withType(StatType t) {
    final d = StatData(t, freqColumn);
    for (var i = 0; i < rows && i < d.rows; i++) {
      d.xs[i] = xs[i];
      d.ys[i] = ys[i];
      d.fs[i] = fs[i];
    }
    return d;
  }

  /// Del-A.
  void clear() {
    for (var i = 0; i < rows; i++) {
      xs[i] = null;
      ys[i] = null;
      fs[i] = null;
    }
  }

  /// DEL on a line: the rows below move up.
  void deleteRow(int r) {
    if (r < 0 || r >= rows) return;
    for (var i = r; i < rows - 1; i++) {
      xs[i] = xs[i + 1];
      ys[i] = ys[i + 1];
      fs[i] = fs[i + 1];
    }
    xs[rows - 1] = null;
    ys[rows - 1] = null;
    fs[rows - 1] = null;
  }

  /// STAT/DIST ▸ Edit ▸ Ins: an empty line at [r]; the last row falls off.
  void insertRow(int r) {
    if (r < 0 || r >= rows) return;
    for (var i = rows - 1; i > r; i--) {
      xs[i] = xs[i - 1];
      ys[i] = ys[i - 1];
      fs[i] = fs[i - 1];
    }
    xs[r] = null;
    ys[r] = null;
    fs[r] = null;
  }
}

/// The keys of the statistics commands (what the menus insert) and their value names.
class StatKeys {
  const StatKeys._();

  static const List<String> sums1 = <String>['Σx²', 'Σx'];
  static const List<String> vars1 = <String>['n', 'x̄', 'σx', 'sx'];
  static const List<String> minMax1 = <String>['minX', 'maxX', 'Q1', 'med', 'Q3'];
  static const List<String> distr = <String>['P(', 'Q(', 'R(', '▸t'];
  static const List<String> sums2 = <String>['Σx²', 'Σx', 'Σy²', 'Σy', 'Σxy', 'Σx³', 'Σx²y', 'Σx⁴'];
  static const List<String> vars2 = <String>['n', 'x̄', 'σx', 'sx', 'ȳ', 'σy', 'sy'];
  static const List<String> reg = <String>['RegA', 'RegB', 'r', 'x̂', 'ŷ'];
  static const List<String> regQuad = <String>['RegA', 'RegB', 'RegC', 'x̂₁', 'x̂₂', 'ŷ'];
  static const List<String> minMax2 = <String>['minX', 'maxX', 'minY', 'maxY'];
}

/// Statistical results for a set of data points.
class CasioStat {
  CasioStat._(this.type, this._x, this._y, this._f, this._rx, this._ry, this._rf);

  /// Builds the calculation from the editor. Rows without an X value are skipped. A missing FREQ counts as 1 (unverified);
  /// a FREQ that is not a whole number ≥ 0, or a paired row with X but no Y, is an Argument ERROR.
  factory CasioStat.fromData(StatData d) {
    final x = <double>[];
    final y = <double>[];
    final f = <double>[];
    final rx = <Rat?>[];
    final ry = <Rat?>[];
    final rf = <Rat?>[];
    Rat? rat(CVal? v) => v == null ? null : (v.ex != null && v.ex!.isRational ? v.ex!.rational : null);
    for (var i = 0; i < d.rows; i++) {
      final xv = d.xs[i];
      if (xv == null) continue;
      CVal? yv;
      if (d.type.paired) {
        yv = d.ys[i];
        if (yv == null) throw kArgumentError;
      }
      var fv = d.freqColumn ? d.fs[i] : null;
      if (fv != null) {
        if (fv.v < 0 || fv.v != fv.v.roundToDouble()) throw kArgumentError;
      }
      fv ??= CVal.int(1);
      if (fv.v == 0) continue;
      x.add(xv.v);
      y.add(yv?.v ?? 0);
      f.add(fv.v);
      rx.add(rat(xv));
      ry.add(yv == null ? Rat.zero : rat(yv));
      rf.add(rat(fv));
    }
    return CasioStat._(d.type, x, y, f, rx, ry, rf);
  }

  /// From plain lists (tests).
  factory CasioStat.fromLists(StatType type, List<double> xs, [List<double>? ys, List<double>? fs]) {
    final f = fs ?? List<double>.filled(xs.length, 1);
    Rat? r(double v) => v == v.roundToDouble() && v.abs() < 1e15 ? Rat.fromInt(v.toInt()) : null;
    return CasioStat._(type, xs, ys ?? List<double>.filled(xs.length, 0), f, [for (final v in xs) r(v)],
        [for (final v in ys ?? List<double>.filled(xs.length, 0)) r(v)], [for (final v in f) r(v)]);
  }

  final StatType type;
  final List<double> _x;
  final List<double> _y;
  final List<double> _f;
  final List<Rat?> _rx;
  final List<Rat?> _ry;
  final List<Rat?> _rf;

  bool get _exact => !_rx.contains(null) && !_ry.contains(null) && !_rf.contains(null);

  // ----- plain sums ---------------------------------------------------------------------------------------------------

  double _sum(double Function(double x, double y) g) {
    var s = 0.0;
    for (var i = 0; i < _x.length; i++) {
      s += _f[i] * g(_x[i], _y[i]);
    }
    return s;
  }

  Rat _rsum(Rat Function(Rat x, Rat y) g) {
    var s = Rat.zero;
    for (var i = 0; i < _x.length; i++) {
      s = s + _rf[i]! * g(_rx[i]!, _ry[i]!);
    }
    return s;
  }

  CVal _sumVal(double Function(double, double) g, Rat Function(Rat, Rat) rg) {
    if (_exact) return CVal.exact(Ex.rational(_rsum(rg)));
    return CVal.dec(_sum(g));
  }

  double get _n => _f.fold<double>(0, (a, b) => a + b);

  void _needData() {
    if (_x.isEmpty) throw kMathError;
  }

  CVal get n {
    _needData();
    return _exact ? CVal.exact(Ex.rational(_rsum((x, y) => Rat.one))) : CVal.dec(_n);
  }

  CVal _mean(double Function(double, double) g, Rat Function(Rat, Rat) rg) {
    _needData();
    if (_exact) {
      final nn = _rsum((x, y) => Rat.one);
      return CVal.exact(Ex.rational(_rsum(rg) / nn));
    }
    return CVal.dec(_sum(g) / _n);
  }

  /// Population (`pop`) or sample variance of a quantity.
  double _variance(double Function(double, double) g, Rat Function(Rat, Rat) rg, {required bool pop}) {
    _needData();
    final nn = _n;
    if (!pop && nn <= 1) throw kMathError;
    double ss;
    if (_exact) {
      final nr = _rsum((x, y) => Rat.one);
      final s1 = _rsum(rg);
      final s2 = _rsum((x, y) => rg(x, y) * rg(x, y));
      final centered = s2 - s1 * s1 / nr;
      ss = centered.toDouble();
    } else {
      final m = _sum(g) / nn;
      ss = _sum((x, y) => (g(x, y) - m) * (g(x, y) - m));
    }
    if (ss < 0) ss = 0;
    return ss / (pop ? nn : nn - 1);
  }

  CVal _sd(double Function(double, double) g, Rat Function(Rat, Rat) rg, {required bool pop}) =>
      CVal.dec(math.sqrt(_variance(g, rg, pop: pop)));

  static double _gx(double x, double y) => x;
  static double _gy(double x, double y) => y;
  static Rat _rgx(Rat x, Rat y) => x;
  static Rat _rgy(Rat x, Rat y) => y;

  // ----- named values -------------------------------------------------------------------------------------------------

  /// Value of a statistics command by its key (see [StatKeys]). Throws Math ERROR when there is no data or the value does
  /// not exist, and Argument ERROR for a key the current type does not offer.
  CVal value(String key) {
    switch (key) {
      case 'n':
        return n;
      case 'Σx':
        _needData();
        return _sumVal(_gx, _rgx);
      case 'Σx²':
        _needData();
        return _sumVal((x, y) => x * x, (x, y) => x * x);
      case 'x̄':
        return _mean(_gx, _rgx);
      case 'σx':
        return _sd(_gx, _rgx, pop: true);
      case 'sx':
        return _sd(_gx, _rgx, pop: false);
      case 'minX':
        _needData();
        return _pick(_x, _rx, min: true);
      case 'maxX':
        _needData();
        return _pick(_x, _rx, min: false);
      case 'Q1':
        return _quartile(1);
      case 'med':
        return _quartile(2);
      case 'Q3':
        return _quartile(3);
    }
    if (!type.paired) throw kArgumentError;
    switch (key) {
      case 'Σy':
        _needData();
        return _sumVal(_gy, _rgy);
      case 'Σy²':
        _needData();
        return _sumVal((x, y) => y * y, (x, y) => y * y);
      case 'Σxy':
        _needData();
        return _sumVal((x, y) => x * y, (x, y) => x * y);
      case 'Σx³':
        _needData();
        return _sumVal((x, y) => x * x * x, (x, y) => x * x * x);
      case 'Σx²y':
        _needData();
        return _sumVal((x, y) => x * x * y, (x, y) => x * x * y);
      case 'Σx⁴':
        _needData();
        return _sumVal((x, y) => x * x * x * x, (x, y) => x * x * x * x);
      case 'ȳ':
        return _mean(_gy, _rgy);
      case 'σy':
        return _sd(_gy, _rgy, pop: true);
      case 'sy':
        return _sd(_gy, _rgy, pop: false);
      case 'minY':
        _needData();
        return _pick(_y, _ry, min: true);
      case 'maxY':
        _needData();
        return _pick(_y, _ry, min: false);
      case 'RegA':
        return CVal.dec(_regression().a);
      case 'RegB':
        return CVal.dec(_regression().b);
      case 'RegC':
        if (type != StatType.quadratic) throw kArgumentError;
        return CVal.dec(_regression().c);
      case 'r':
        if (type == StatType.quadratic) throw kArgumentError;
        return CVal.dec(_regression().r);
    }
    throw kArgumentError;
  }

  CVal _pick(List<double> v, List<Rat?> r, {required bool min}) {
    var best = 0;
    for (var i = 1; i < v.length; i++) {
      if (min ? v[i] < v[best] : v[i] > v[best]) best = i;
    }
    final rr = r[best];
    return rr != null ? CVal.exact(Ex.rational(rr)) : CVal.dec(v[best]);
  }

  // ----- quartiles (the data is read as if every item stood [freq] times; the median is left out of Q1 and Q3) ---------

  CVal _quartile(int which) {
    _needData();
    final idx = List<int>.generate(_x.length, (i) => i)..sort((a, b) => _x[a].compareTo(_x[b]));
    var total = 0;
    for (final i in idx) {
      total += _f[i].toInt();
    }
    double at(int k) {
      var acc = 0;
      for (final i in idx) {
        acc += _f[i].toInt();
        if (k < acc) return _x[i];
      }
      return _x[idx.last];
    }

    Rat? ratAt(int k) {
      var acc = 0;
      for (final i in idx) {
        acc += _f[i].toInt();
        if (k < acc) return _rx[i];
      }
      return _rx[idx.last];
    }

    CVal medianOf(int lo, int hi) {
      final m = hi - lo;
      if (m <= 0) throw kMathError;
      if (m.isOdd) {
        final k = lo + (m - 1) ~/ 2;
        final r = ratAt(k);
        return r != null ? CVal.exact(Ex.rational(r)) : CVal.dec(at(k));
      }
      final k1 = lo + m ~/ 2 - 1;
      final r1 = ratAt(k1);
      final r2 = ratAt(k1 + 1);
      if (r1 != null && r2 != null) return CVal.exact(Ex.rational((r1 + r2) / Rat.fromInt(2)));
      return CVal.dec((at(k1) + at(k1 + 1)) / 2);
    }

    final half = total ~/ 2;
    switch (which) {
      case 1:
        return medianOf(0, half);
      case 2:
        return medianOf(0, total);
      default:
        return medianOf(total - half, total);
    }
  }

  // ----- regression ---------------------------------------------------------------------------------------------------

  Regression? _cache;

  Regression _regression() => _cache ??= _computeRegression();

  Regression _computeRegression() {
    _needData();
    if (_x.length < 2 && type != StatType.quadratic) throw kMathError;
    final u = <double>[];
    final v = <double>[];
    for (var i = 0; i < _x.length; i++) {
      double xx = _x[i];
      double yy = _y[i];
      switch (type) {
        case StatType.ln:
        case StatType.power:
          if (xx <= 0) throw kMathError;
          xx = math.log(xx);
        case StatType.inverse:
          if (xx == 0) throw kMathError;
          xx = 1 / xx;
        default:
          break;
      }
      switch (type) {
        case StatType.exp:
        case StatType.abExp:
        case StatType.power:
          if (yy <= 0) throw kMathError;
          yy = math.log(yy);
        default:
          break;
      }
      u.add(xx);
      v.add(yy);
    }
    if (type == StatType.quadratic) return _quad();
    var s = 0.0, su = 0.0, sv = 0.0, suu = 0.0, suv = 0.0, svv = 0.0;
    for (var i = 0; i < u.length; i++) {
      final w = _f[i];
      s += w;
      su += w * u[i];
      sv += w * v[i];
      suu += w * u[i] * u[i];
      suv += w * u[i] * v[i];
      svv += w * v[i] * v[i];
    }
    final dx = s * suu - su * su;
    if (dx == 0) throw kMathError;
    final b = (s * suv - su * sv) / dx;
    final a = (sv - b * su) / s;
    final dy = s * svv - sv * sv;
    final rden = dx * dy;
    final r = rden <= 0 ? double.nan : (s * suv - su * sv) / math.sqrt(rden);
    switch (type) {
      case StatType.exp:
        return Regression(math.exp(a), b, 0, r);
      case StatType.abExp:
        return Regression(math.exp(a), math.exp(b), 0, r);
      case StatType.power:
        return Regression(math.exp(a), b, 0, r);
      default:
        return Regression(a, b, 0, r);
    }
  }

  Regression _quad() {
    final s = _n;
    final sx = _sum((x, y) => x);
    final sx2 = _sum((x, y) => x * x);
    final sx3 = _sum((x, y) => x * x * x);
    final sx4 = _sum((x, y) => x * x * x * x);
    final sy = _sum((x, y) => y);
    final sxy = _sum((x, y) => x * y);
    final sx2y = _sum((x, y) => x * x * y);
    final m = <List<double>>[
      [s, sx, sx2, sy],
      [sx, sx2, sx3, sxy],
      [sx2, sx3, sx4, sx2y],
    ];
    for (var col = 0; col < 3; col++) {
      var p = col;
      for (var r = col + 1; r < 3; r++) {
        if (m[r][col].abs() > m[p][col].abs()) p = r;
      }
      if (m[p][col].abs() < 1e-12 * (1 + m[col].fold<double>(0, (a, b) => math.max(a, b.abs())))) throw kMathError;
      final t = m[p];
      m[p] = m[col];
      m[col] = t;
      for (var r = col + 1; r < 3; r++) {
        final f = m[r][col] / m[col][col];
        for (var j = col; j < 4; j++) {
          m[r][j] -= f * m[col][j];
        }
      }
    }
    final c = m[2][3] / m[2][2];
    final b = (m[1][3] - m[1][2] * c) / m[1][1];
    final a = (m[0][3] - m[0][2] * c - m[0][1] * b) / m[0][0];
    return Regression(a, b, c, double.nan);
  }

  // ----- estimated values ---------------------------------------------------------------------------------------------

  /// ŷ for an x value.
  CVal estimateY(double x) {
    final g = _regression();
    double y;
    switch (type) {
      case StatType.linear:
        y = g.a + g.b * x;
      case StatType.quadratic:
        y = g.a + g.b * x + g.c * x * x;
      case StatType.ln:
        if (x <= 0) throw kMathError;
        y = g.a + g.b * math.log(x);
      case StatType.exp:
        y = g.a * math.exp(g.b * x);
      case StatType.abExp:
        y = g.a * math.pow(g.b, x).toDouble();
      case StatType.power:
        if (x < 0) throw kMathError;
        y = g.a * math.pow(x, g.b).toDouble();
      case StatType.inverse:
        if (x == 0) throw kMathError;
        y = g.a + g.b / x;
      case StatType.oneVar:
        throw kArgumentError;
    }
    if (!y.isFinite) throw kMathError;
    return CVal.dec(y);
  }

  /// x̂ for a y value (x̂₁ and x̂₂ for the quadratic type; [which] is 0 for the single x̂).
  CVal estimateX(double y, {int which = 0}) {
    final g = _regression();
    double x;
    switch (type) {
      case StatType.linear:
        if (g.b == 0) throw kMathError;
        x = (y - g.a) / g.b;
      case StatType.quadratic:
        if (g.c == 0) throw kMathError;
        final disc = g.b * g.b - 4 * g.c * (g.a - y);
        if (disc < 0) throw kMathError;
        final sq = math.sqrt(disc);
        x = which == 2 ? (-g.b - sq) / (2 * g.c) : (-g.b + sq) / (2 * g.c);
      case StatType.ln:
        if (g.b == 0) throw kMathError;
        x = math.exp((y - g.a) / g.b);
      case StatType.exp:
        if (g.a == 0 || y / g.a <= 0 || g.b == 0) throw kMathError;
        x = math.log(y / g.a) / g.b;
      case StatType.abExp:
        if (g.a == 0 || y / g.a <= 0 || g.b <= 0 || g.b == 1) throw kMathError;
        x = math.log(y / g.a) / math.log(g.b);
      case StatType.power:
        if (g.a == 0 || y / g.a <= 0 || g.b == 0) throw kMathError;
        x = math.pow(y / g.a, 1 / g.b).toDouble();
      case StatType.inverse:
        if (y == g.a) throw kMathError;
        x = g.b / (y - g.a);
      case StatType.oneVar:
        throw kArgumentError;
    }
    if (!x.isFinite) throw kMathError;
    return CVal.dec(x);
  }

  // ----- normal distribution on the 1-VAR data -----------------------------------------------------------------------

  /// ▸t: (x − x̄) / σx.
  CVal normalized(double x) {
    final sd = value('σx').v;
    if (sd == 0) throw kMathError;
    return CVal.dec((x - value('x̄').v) / sd);
  }
}

/// Coefficients of a regression (`c` only for the quadratic type, `r` is NaN where the type has none).
class Regression {
  const Regression(this.a, this.b, this.c, this.r);
  final double a;
  final double b;
  final double c;
  final double r;
}

// ----- normal distribution --------------------------------------------------------------------------------------------

class NormalDist {
  const NormalDist._();

  /// erfc to about 1e-15 (series for small |x|, continued fraction for the tail).
  static double erfc(double x) {
    if (x.isNaN) return x;
    if (x < 0) return 2 - erfc(-x);
    if (x < 2.5) {
      // erf by its Maclaurin series
      var term = x;
      var sum = x;
      for (var n = 1; n < 200; n++) {
        term *= -x * x / n;
        final add = term / (2 * n + 1);
        sum += add;
        if (add.abs() < 1e-17 * sum.abs()) break;
      }
      return 1 - 2 / math.sqrt(math.pi) * sum;
    }
    // continued fraction: erfc(x) = exp(-x²)/(x√π) · 1/(1+ 1/(2x²)/(1+2/(2x²)/(1+ …)))
    var f = 0.0;
    for (var k = 60; k >= 1; k--) {
      f = (k / 2) / (x + f);
    }
    return math.exp(-x * x) / math.sqrt(math.pi) / (x + f);
  }

  /// Φ(t), the area from −∞ to t of the standard normal curve.
  static double cdf(double t) => 0.5 * erfc(-t / math.sqrt2);

  /// P(t): −∞ … t (manual p.66, example 5: t = −0.762 gives 0.223).
  static double p(double t) => cdf(t);

  /// Q(t): 0 … t.
  static double q(double t) => cdf(t) - 0.5;

  /// R(t): t … ∞.
  static double r(double t) => 1 - cdf(t);

  static double pdf(double x, double sigma, double mu) {
    final z = (x - mu) / sigma;
    return math.exp(-0.5 * z * z) / (sigma * math.sqrt(2 * math.pi));
  }
}

// ----- expressions in STAT mode ---------------------------------------------------------------------------------------

/// Evaluates a line typed in STAT mode: the statistics commands inside it are replaced by their values (as exact fractions
/// where they are exact), then the Casio engine does the rest.
class StatCalc {
  const StatCalc._();

  static final List<String> _symbols = <String>[
    'Σx²y', 'Σx²', 'Σx³', 'Σx⁴', 'Σxy', 'Σy²', 'Σx', 'Σy', 'minX', 'maxX', 'minY', 'maxY', 'RegA', 'RegB', 'RegC', 'med', 'Q1', 'Q3',
    'x̄', 'ȳ', 'σx', 'σy', 'sx', 'sy', 'n', 'r',
  ];

  static String _literal(CVal v) {
    final ex = v.ex;
    if (ex != null && ex.isRational) {
      final r = ex.rational;
      return r.isInteger ? '(${r.n})' : '((${r.n})÷(${r.d}))';
    }
    final s = v.v.toStringAsPrecision(15);
    return '($s)';
  }

  static final RegExp _postfix = RegExp(r'x̂₁|x̂₂|x̂|ŷ|▸t');

  /// `P(`, `Q(`, `R(`: the argument is in the text up to the matching parenthesis.
  static String _distr(String s, CasioStat stat, CasioEngine engine) {
    final re = RegExp(r'(?<![A-Za-z])([PQR])\(');
    while (true) {
      final m = re.firstMatch(s);
      if (m == null) return s;
      var depth = 1;
      var i = m.end;
      for (; i < s.length && depth > 0; i++) {
        if (s[i] == '(') {
          depth++;
        } else if (s[i] == ')') {
          depth--;
        }
      }
      final inner = depth == 0 ? s.substring(m.end, i - 1) : s.substring(m.end);
      final tail = depth == 0 ? s.substring(i) : '';
      final t = _evalValue(inner, stat, engine).v;
      final double r;
      switch (m.group(1)) {
        case 'P':
          r = NormalDist.p(t);
        case 'Q':
          r = NormalDist.q(t);
        default:
          r = NormalDist.r(t);
      }
      s = '${s.substring(0, m.start)}${_literal(CVal.dec(r))}$tail';
    }
  }

  /// The operand just before position [end] in [s]: a parenthesised group, or a run of number / constant characters.
  static int _operandStart(String s, int end) {
    var i = end;
    if (i > 0 && s[i - 1] == ')') {
      var depth = 0;
      for (var k = i - 1; k >= 0; k--) {
        if (s[k] == ')') depth++;
        if (s[k] == '(') {
          depth--;
          if (depth == 0) return k;
        }
      }
      throw kSyntaxError;
    }
    while (i > 0 && RegExp(r'[0-9.πeE]').hasMatch(s[i - 1])) {
      i--;
    }
    if (i > 0 && s[i - 1] == '−') {
      // a leading minus belongs to the operand only when it starts the expression or follows an operator
      if (i - 1 == 0 || RegExp(r'[+\-−×÷(]').hasMatch(s[i - 2])) i--;
    }
    if (i == end) throw kSyntaxError;
    return i;
  }

  static String _postfixCommands(String s, CasioStat stat, CasioEngine engine) {
    while (true) {
      final m = _postfix.firstMatch(s);
      if (m == null) return s;
      final start = _operandStart(s, m.start);
      final arg = _evalValue(s.substring(start, m.start), stat, engine).v;
      final CVal res;
      switch (m.group(0)) {
        case 'x̂₁':
          res = stat.estimateX(arg, which: 1);
        case 'x̂₂':
          res = stat.estimateX(arg, which: 2);
        case 'x̂':
          res = stat.estimateX(arg);
        case 'ŷ':
          res = stat.estimateY(arg);
        default:
          res = stat.normalized(arg);
      }
      s = '${s.substring(0, start)}${_literal(res)}${s.substring(m.end)}';
    }
  }

  static String substitute(String expr, CasioStat stat, CasioEngine engine) {
    var s = _distr(expr, stat, engine);
    s = _postfixCommands(s, stat, engine);
    for (final sym in _symbols) {
      if (!s.contains(sym)) continue;
      final pattern = RegExp(sym.length > 1 && !RegExp(r'^[A-Za-z0-9]+$').hasMatch(sym)
          ? RegExp.escape(sym)
          : '(?<![A-Za-z])${RegExp.escape(sym)}(?![A-Za-z])');
      s = s.replaceAllMapped(pattern, (_) => _literal(stat.value(sym)));
    }
    return s;
  }

  static CVal _evalValue(String text, CasioStat stat, CasioEngine engine) {
    final s = substitute(text, stat, engine);
    final o = engine.evaluate(s, commit: false);
    return o.value ?? CVal.zero;
  }

  /// One `=` in STAT mode.
  static CasioOutcome evaluate(String expr, CasioStat stat, CasioEngine engine) {
    final s = substitute(expr, stat, engine);
    return engine.evaluate(s);
  }
}
