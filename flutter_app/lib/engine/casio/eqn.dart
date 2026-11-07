// EQN mode of the Casio engine (Phase 7d, manual p.70-72): simultaneous linear equations with two or three unknowns, quadratic
// and cubic equations (no quartic). Coefficients are calculator values; exact (rational / √) coefficients give exact answers.

import 'dart:math' as math;

import 'complex.dart';
import 'cval.dart';
import 'exact.dart';
import 'rat.dart';

enum EqnType {
  simul2('aₙx+bₙy=cₙ', 2, 3),
  simul3('aₙx+bₙy+cₙz=dₙ', 3, 4),
  quadratic('ax²+bx+c=0', 1, 3),
  cubic('ax³+bx²+cx+d=0', 1, 4);

  const EqnType(this.title, this.rows, this.cols);

  final String title;

  /// Rows and columns of the Coefficient Editor.
  final int rows;
  final int cols;

  bool get isSimultaneous => this == EqnType.simul2 || this == EqnType.simul3;
}

/// One line of the solution screen: `X=`, `X1=`, `X-Value Minimum=` …
class EqnLine {
  const EqnLine(this.label, this.value, {this.noSqrt = false});

  final String label;
  final CComplex value;

  /// Simultaneous equations never show a √ form (manual p.71 note).
  final bool noSqrt;
}

/// The message for a system without a solution / with infinitely many (manual p.71 "A message appears …").
class EqnMessage implements Exception {
  const EqnMessage(this.text);
  final String text;
  @override
  String toString() => text;
}

const String kNoSolution = 'No-Solution';
const String kInfiniteSolutions = 'Infinite Solutions';

class CasioEqn {
  const CasioEqn._();

  /// Solves [type] for [coef] (row-major, the Coefficient Editor cells). Throws [EqnMessage] or a CasioError (Math ERROR).
  static List<EqnLine> solve(EqnType type, List<CVal> coef) {
    if (coef.length != type.rows * type.cols) throw kArgumentError;
    switch (type) {
      case EqnType.simul2:
      case EqnType.simul3:
        return _simul(type.rows, coef);
      case EqnType.quadratic:
        return _quadratic(coef[0], coef[1], coef[2]);
      case EqnType.cubic:
        return _cubic(coef[0], coef[1], coef[2], coef[3]);
    }
  }

  // ----- helpers ------------------------------------------------------------------------------------------------------

  static CComplex _re(CVal v) => CComplex(v);

  static CVal _fromEx(Ex? e, double fallback) => e == null ? CVal.dec(fallback) : CVal.exact(e);

  static Rat? _rat(CVal v) => v.ex != null && v.ex!.isRational ? v.ex!.rational : null;

  // ----- simultaneous -------------------------------------------------------------------------------------------------

  static List<EqnLine> _simul(int n, List<CVal> c) {
    final names = <String>['X', 'Y', 'Z'];
    final cols = n + 1;
    final rats = <Rat>[];
    var exact = true;
    for (final v in c) {
      final r = _rat(v);
      if (r == null) {
        exact = false;
        break;
      }
      rats.add(r);
    }
    final List<double> sol;
    if (exact) {
      final m = <List<Rat>>[
        for (var i = 0; i < n; i++) rats.sublist(i * cols, (i + 1) * cols),
      ];
      final res = _gaussRat(m, n);
      return <EqnLine>[
        for (var i = 0; i < n; i++) EqnLine('${names[i]}=', _re(CVal.exact(Ex.rational(res[i]))), noSqrt: true),
      ];
    }
    final m = <List<double>>[
      for (var i = 0; i < n; i++) <double>[for (var j = 0; j < cols; j++) c[i * cols + j].v],
    ];
    sol = _gaussDouble(m, n);
    return <EqnLine>[
      for (var i = 0; i < n; i++) EqnLine('${names[i]}=', _re(CVal.dec(sol[i])), noSqrt: true),
    ];
  }

  static List<Rat> _gaussRat(List<List<Rat>> m, int n) {
    var row = 0;
    final pivotCol = <int>[];
    for (var col = 0; col < n && row < n; col++) {
      var p = -1;
      for (var r = row; r < n; r++) {
        if (!m[r][col].isZero) {
          p = r;
          break;
        }
      }
      if (p < 0) continue;
      final t = m[p];
      m[p] = m[row];
      m[row] = t;
      final pv = m[row][col];
      for (var j = 0; j <= n; j++) {
        m[row][j] = m[row][j] / pv;
      }
      for (var r = 0; r < n; r++) {
        if (r != row && !m[r][col].isZero) {
          final f = m[r][col];
          for (var j = 0; j <= n; j++) {
            m[r][j] = m[r][j] - f * m[row][j];
          }
        }
      }
      pivotCol.add(col);
      row++;
    }
    // a zero row with a non-zero right-hand side: no solution; otherwise fewer pivots than unknowns: infinitely many
    for (var r = row; r < n; r++) {
      if (!m[r][n].isZero) throw const EqnMessage(kNoSolution);
    }
    if (row < n) throw const EqnMessage(kInfiniteSolutions);
    return <Rat>[for (var i = 0; i < n; i++) m[i][n]];
  }

  static List<double> _gaussDouble(List<List<double>> m, int n) {
    var rank = 0;
    for (var col = 0; col < n && rank < n; col++) {
      var p = rank;
      for (var r = rank + 1; r < n; r++) {
        if (m[r][col].abs() > m[p][col].abs()) p = r;
      }
      if (m[p][col].abs() < 1e-12) continue;
      final t = m[p];
      m[p] = m[rank];
      m[rank] = t;
      final pv = m[rank][col];
      for (var j = 0; j <= n; j++) {
        m[rank][j] /= pv;
      }
      for (var r = 0; r < n; r++) {
        if (r != rank) {
          final f = m[r][col];
          for (var j = 0; j <= n; j++) {
            m[r][j] -= f * m[rank][j];
          }
        }
      }
      rank++;
    }
    for (var r = rank; r < n; r++) {
      if (m[r][n].abs() > 1e-12) throw const EqnMessage(kNoSolution);
    }
    if (rank < n) throw const EqnMessage(kInfiniteSolutions);
    return <double>[for (var i = 0; i < n; i++) m[i][n]];
  }

  // ----- quadratic ----------------------------------------------------------------------------------------------------

  static List<EqnLine> _quadratic(CVal a, CVal b, CVal c) {
    if (a.v == 0) throw kMathError;
    final roots = _quadRoots(a, b, c);
    final disc = b.v * b.v - 4 * a.v * c.v;
    final out = <EqnLine>[];
    if (roots.length == 1) {
      out.add(EqnLine('X=', roots[0]));
    } else {
      for (var i = 0; i < roots.length; i++) {
        out.add(EqnLine('X${i + 1}=', roots[i]));
      }
    }
    // vertex: X = -b/2a, Y = -D/4a
    final min = a.v > 0;
    final xv = _div(_neg(b), _mul(CVal.int(2), a));
    final dv = _sub(_mul(b, b), _mul(CVal.int(4), _mul(a, c)));
    final yv = disc == 0 && dv.v == 0 ? CVal.zero : _div(_neg(dv), _mul(CVal.int(4), a));
    out.add(EqnLine('X-Value ${min ? 'Minimum' : 'Maximum'}=', _re(xv)));
    out.add(EqnLine('Y-Value ${min ? 'Minimum' : 'Maximum'}=', _re(yv)));
    return out;
  }

  // small exact arithmetic on CVal (an exact result when both operands are exact and the result stays simple)
  static CVal _add(CVal x, CVal y) {
    final e = x.ex != null && y.ex != null ? x.ex! + y.ex! : null;
    return _fromEx(e, x.v + y.v);
  }

  static CVal _neg(CVal x) => _fromEx(x.ex == null ? null : -x.ex!, -x.v);
  static CVal _sub(CVal x, CVal y) => _add(x, _neg(y));

  static CVal _mul(CVal x, CVal y) {
    final e = x.ex != null && y.ex != null ? x.ex! * y.ex! : null;
    return _fromEx(e, x.v * y.v);
  }

  static CVal _div(CVal x, CVal y) {
    if (y.v == 0) throw kMathError;
    final e = x.ex != null && y.ex != null ? x.ex! / y.ex! : null;
    return _fromEx(e, x.v / y.v);
  }

  /// Square root of a non-negative value, exact when possible.
  static CVal _sqrtPos(CVal x) {
    final r = _rat(x);
    if (r != null) {
      final e = Ex.sqrtRational(r);
      if (e != null) return CVal.exact(e);
    }
    return CVal.dec(math.sqrt(x.v));
  }

  static List<CComplex> _quadRoots(CVal a, CVal b, CVal c) {
    final d = _sub(_mul(b, b), _mul(CVal.int(4), _mul(a, c)));
    final twoA = _mul(CVal.int(2), a);
    final nb = _neg(b);
    if (d.v == 0) return <CComplex>[_re(_div(nb, twoA))];
    if (d.v > 0) {
      final s = _sqrtPos(d);
      // order of the manual's example: the "+" root first
      return <CComplex>[_re(_div(_add(nb, s), twoA)), _re(_div(_sub(nb, s), twoA))];
    }
    final s = _sqrtPos(_neg(d));
    final re = _div(nb, twoA);
    final im = _div(s, twoA);
    return <CComplex>[CComplex(re, im), CComplex(re, _neg(im))];
  }

  // ----- cubic --------------------------------------------------------------------------------------------------------

  static List<EqnLine> _cubic(CVal a, CVal b, CVal c, CVal d) {
    if (a.v == 0) throw kMathError;
    final rs = <CComplex>[];
    final ar = _rat(a), br = _rat(b), cr = _rat(c), dr = _rat(d);
    Rat? found;
    if (ar != null && br != null && cr != null && dr != null) {
      found = _rationalRoot(ar, br, cr, dr);
    }
    if (found != null) {
      // synthetic division by (x - found): x³ + ... = (x - r)(a x² + p x + q)
      final p = br! + ar! * found;
      final q = cr! + p * found;
      rs.add(_re(CVal.exact(Ex.rational(found))));
      rs.addAll(_quadRoots(CVal.exact(Ex.rational(ar)), CVal.exact(Ex.rational(p)), CVal.exact(Ex.rational(q))));
    } else {
      final x0 = _realCubicRoot(a.v, b.v, c.v, d.v);
      final p = b.v + a.v * x0;
      final q = c.v + p * x0;
      rs.add(_re(CVal.dec(x0)));
      final dd = p * p - 4 * a.v * q;
      if (dd >= 0) {
        final s = math.sqrt(dd);
        rs.add(_re(CVal.dec((-p + s) / (2 * a.v))));
        rs.add(_re(CVal.dec((-p - s) / (2 * a.v))));
      } else {
        final s = math.sqrt(-dd);
        rs.add(CComplex(CVal.dec(-p / (2 * a.v)), CVal.dec(s / (2 * a.v))));
        rs.add(CComplex(CVal.dec(-p / (2 * a.v)), CVal.dec(-s / (2 * a.v))));
      }
    }
    return <EqnLine>[for (var i = 0; i < rs.length; i++) EqnLine('X${i + 1}=', rs[i])];
  }

  /// The smallest rational root of a x³+b x²+c x+d, found by the rational-root theorem on integer coefficients.
  static Rat? _rationalRoot(Rat a, Rat b, Rat c, Rat d) {
    var lcm = BigInt.one;
    for (final r in <Rat>[a, b, c, d]) {
      lcm = lcm ~/ lcm.gcd(r.d) * r.d;
    }
    BigInt s(Rat r) => r.n * (lcm ~/ r.d);
    final ia = s(a), ib = s(b), ic = s(c), id = s(d);
    final roots = <Rat>[];
    if (id == BigInt.zero) {
      roots.add(Rat.zero);
      // remaining roots of a x² + b x + c: search the same way
      final r2 = _rationalRoot2(ia, ib, ic);
      roots.addAll(r2);
    } else {
      final dd = _divisors(id.abs());
      final aa = _divisors(ia.abs());
      if (dd == null || aa == null) return null;
      for (final p in dd) {
        for (final q in aa) {
          for (final sg in <int>[1, -1]) {
            final r = Rat(BigInt.from(sg) * p, q);
            final v = ((ia * r.n * r.n * r.n) + (ib * r.n * r.n * r.d) + (ic * r.n * r.d * r.d) + (id * r.d * r.d * r.d));
            if (v == BigInt.zero) roots.add(r);
          }
        }
      }
    }
    if (roots.isEmpty) return null;
    roots.sort();
    return roots.first;
  }

  static List<Rat> _rationalRoot2(BigInt a, BigInt b, BigInt c) {
    final out = <Rat>[];
    if (c == BigInt.zero) {
      out.add(Rat.zero);
      if (b != BigInt.zero) out.add(Rat(-b, a));
      return out;
    }
    final dd = _divisors(c.abs());
    final aa = _divisors(a.abs());
    if (dd == null || aa == null) return out;
    for (final p in dd) {
      for (final q in aa) {
        for (final sg in <int>[1, -1]) {
          final r = Rat(BigInt.from(sg) * p, q);
          if (a * r.n * r.n + b * r.n * r.d + c * r.d * r.d == BigInt.zero) out.add(r);
        }
      }
    }
    return out;
  }

  static List<BigInt>? _divisors(BigInt v) {
    if (v > BigInt.from(1000000000000)) return null;
    final n = v.toInt();
    final out = <BigInt>[];
    for (var i = 1; i * i <= n; i++) {
      if (n % i == 0) {
        out.add(BigInt.from(i));
        if (i * i != n) out.add(BigInt.from(n ~/ i));
      }
    }
    return out;
  }

  /// A real root of a x³+b x²+c x+d by bisection on a bracket (a cubic always has one), polished with Newton steps.
  static double _realCubicRoot(double a, double b, double c, double d) {
    double f(double x) => ((a * x + b) * x + c) * x + d;
    final bound = 1 + [b / a, c / a, d / a].map((e) => e.abs()).reduce(math.max);
    var lo = -bound, hi = bound;
    final flo = f(lo);
    for (var i = 0; i < 300; i++) {
      final mid = (lo + hi) / 2;
      final fm = f(mid);
      if (fm == 0) return mid;
      if ((fm < 0) == (flo < 0)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    var x = (lo + hi) / 2;
    for (var i = 0; i < 5; i++) {
      final df = (3 * a * x + 2 * b) * x + c;
      if (df == 0) break;
      x -= f(x) / df;
    }
    return x;
  }
}
