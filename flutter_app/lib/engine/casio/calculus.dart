// Numerical kernels of Phase 7c: integration (Gauss-Kronrod, manual p.39-40) and differentiation (central difference,
// manual p.41-42). They work on plain doubles; the evaluator wraps f(x) so that every call is a 15-digit calculation of the
// Casio engine and a domain error inside f(x) surfaces as the unit's own error.

import 'dart:math' as math;

import 'cval.dart';

/// "Press AC to interrupt" (manual p.36): long calculations check this token and stop with [CasioCancelled].
class CasioCancel {
  bool cancelled = false;

  void check() {
    if (cancelled) throw const CasioCancelled();
  }
}

/// A long calculation was interrupted with AC. Not an error message: the display is simply cleared.
class CasioCancelled implements Exception {
  const CasioCancelled();

  @override
  String toString() => 'cancelled';
}

/// Tolerance the manual gives for ∫ when nothing is input for tol (p.39).
const double kIntegralTol = 1e-5;

/// Tolerance of d/dx when nothing is input for tol (p.41).
const double kDerivativeTol = 1e-10;

// 15-point Gauss-Kronrod rule (QUADPACK qk15): nodes, Kronrod weights and the weights of the embedded 7-point Gauss rule.
const List<double> _xgk = <double>[
  0.991455371120812639206854697526329,
  0.949107912342758524526189684047851,
  0.864864423359769072789712788640926,
  0.741531185599394439863864773280788,
  0.586087235467691130294144838258730,
  0.405845151377397166906606412076961,
  0.207784955007898467600689403773245,
  0.0,
];
const List<double> _wgk = <double>[
  0.022935322010529224963732008058970,
  0.063092092629978553290700663189204,
  0.104790010322250183839876322541518,
  0.140653259715525918745189590510238,
  0.169004726639267902826583426598550,
  0.190350578064785409913256402421014,
  0.204432940075298892414161999234649,
  0.209482141084727828012999174891714,
];
const List<double> _wg = <double>[
  0.129484966168869693270611432679082,
  0.279705391489276667901467771423780,
  0.381830050505118944950369775488975,
  0.417959183673469387755102040816327,
];

class _Piece {
  _Piece(this.a, this.b, this.value, this.err, this.abs);
  final double a;
  final double b;
  final double value;
  final double err;
  final double abs;
}

double _checked(double Function(double) f, double x) {
  final v = f(x);
  if (!v.isFinite) throw kMathError;
  return v;
}

_Piece _qk15(double Function(double) f, double a, double b) {
  const epmach = 2.220446049250313e-16;
  const uflow = 2.2250738585072014e-308;
  final centr = 0.5 * (a + b);
  final hlgth = 0.5 * (b - a);
  final dhlgth = hlgth.abs();
  final fc = _checked(f, centr);
  var resg = fc * _wg[3];
  var resk = fc * _wgk[7];
  var resabs = fc.abs() * _wgk[7];
  final fv1 = List<double>.filled(7, 0);
  final fv2 = List<double>.filled(7, 0);
  for (var j = 0; j < 3; j++) {
    final jtw = 2 * j + 1;
    final absc = hlgth * _xgk[jtw];
    final f1 = _checked(f, centr - absc);
    final f2 = _checked(f, centr + absc);
    fv1[jtw] = f1;
    fv2[jtw] = f2;
    resg += _wg[j] * (f1 + f2);
    resk += _wgk[jtw] * (f1 + f2);
    resabs += _wgk[jtw] * (f1.abs() + f2.abs());
  }
  for (var j = 0; j < 4; j++) {
    final jtwm1 = 2 * j;
    final absc = hlgth * _xgk[jtwm1];
    final f1 = _checked(f, centr - absc);
    final f2 = _checked(f, centr + absc);
    fv1[jtwm1] = f1;
    fv2[jtwm1] = f2;
    resk += _wgk[jtwm1] * (f1 + f2);
    resabs += _wgk[jtwm1] * (f1.abs() + f2.abs());
  }
  final reskh = resk * 0.5;
  var resasc = _wgk[7] * (fc - reskh).abs();
  for (var j = 0; j < 7; j++) {
    resasc += _wgk[j] * ((fv1[j] - reskh).abs() + (fv2[j] - reskh).abs());
  }
  final result = resk * hlgth;
  resabs *= dhlgth;
  resasc *= dhlgth;
  var abserr = ((resk - resg) * hlgth).abs();
  if (resasc != 0 && abserr != 0) {
    abserr = resasc * math.min(1.0, math.pow(200 * abserr / resasc, 1.5).toDouble());
  }
  if (resabs > uflow / (50 * epmach)) {
    abserr = math.max(epmach * 50 * resabs, abserr);
  }
  return _Piece(a, b, result, abserr, resabs);
}

/// ∫ from [a] to [b] of [f] by adaptive Gauss-Kronrod quadrature.
///
/// [tol] is the tolerance of the manual (default 1×10⁻⁵). The result is calculated to the finer of [tol] and 1×10⁻¹⁰
/// (relative), so the 10 displayed digits of the guide's examples come out right; an integral that cannot reach that
/// within the subdivision limit ends in `Time Out` (manual p.95). A result that is only the rounding residue of positive
/// and negative parts cancelling is 0.
double gaussKronrod(double Function(double) f, double a, double b, double tol, {CasioCancel? cancel, int limit = 400}) {
  if (a == b) return 0;
  if (!a.isFinite || !b.isFinite) throw kMathError;
  final eps = math.min(tol, 1e-10);
  final pieces = <_Piece>[_qk15(f, a, b)];
  var total = pieces.first.value;
  var totalErr = pieces.first.err;
  var totalAbs = pieces.first.abs;
  bool converged() => totalErr <= math.max(eps * total.abs(), eps * 1e-3 * math.max(totalAbs, 1e-300));
  var rounds = 0;
  while (!converged()) {
    cancel?.check();
    if (pieces.length >= limit) throw const CasioError(CasioErrorKind.timeOut);
    // bisect the piece with the largest error
    var worst = 0;
    for (var i = 1; i < pieces.length; i++) {
      if (pieces[i].err > pieces[worst].err) worst = i;
    }
    final p = pieces.removeAt(worst);
    final mid = 0.5 * (p.a + p.b);
    if (mid == p.a || mid == p.b) throw const CasioError(CasioErrorKind.timeOut);
    pieces
      ..add(_qk15(f, p.a, mid))
      ..add(_qk15(f, mid, p.b));
    total = 0;
    totalErr = 0;
    totalAbs = 0;
    for (final q in pieces) {
      total += q.value;
      totalErr += q.err;
      totalAbs += q.abs;
    }
    rounds++;
    if (rounds > 4 * limit) throw const CasioError(CasioErrorKind.timeOut);
  }
  if (total.abs() <= 1e-12 * totalAbs) return 0;
  return total;
}

/// d/dx of [f] at [a] by the central difference with Richardson extrapolation (Ridders' method).
///
/// With [tolGiven] false (nothing input for tol, manual p.42) the tolerance starts at [tol] and is relaxed automatically
/// when no convergence is found; with a given tol that cannot be met the calculation ends in `Time Out`.
double centralDifference(double Function(double) f, double a, double tol,
    {required bool tolGiven, CasioCancel? cancel}) {
  if (!a.isFinite) throw kMathError;
  final scale = math.max(1.0, a.abs());
  final h0 = 0.1 * scale;
  const con = 1.4;
  const con2 = con * con;
  const ntab = 10;
  const safe = 2.0;

  var ans = 0.0;
  var err = double.maxFinite;
  final tab = List<List<double>>.generate(ntab, (_) => List<double>.filled(ntab, 0));
  var h = h0;
  tab[0][0] = (_checked(f, a + h) - _checked(f, a - h)) / (2 * h);
  ans = tab[0][0];
  for (var i = 1; i < ntab; i++) {
    cancel?.check();
    h /= con;
    tab[0][i] = (_checked(f, a + h) - _checked(f, a - h)) / (2 * h);
    var fac = con2;
    for (var j = 1; j <= i; j++) {
      tab[j][i] = (tab[j - 1][i] * fac - tab[j - 1][i - 1]) / (fac - 1);
      fac *= con2;
      final errt = math.max((tab[j][i] - tab[j - 1][i]).abs(), (tab[j][i] - tab[j - 1][i - 1]).abs());
      if (errt <= err) {
        err = errt;
        ans = tab[j][i];
      }
    }
    if ((tab[i][i] - tab[i - 1][i - 1]).abs() >= safe * err) break;
  }

  var allowed = tol;
  final relErr = err / math.max(1.0, ans.abs());
  while (relErr > allowed) {
    if (tolGiven || allowed >= 1e-2) throw const CasioError(CasioErrorKind.timeOut);
    allowed *= 10; // omitted tol: adjust it automatically until a solution is found (manual p.42)
  }

  // a derivative that is only noise next to the size of the function is 0 (d/dx sin x at π/2 is 0)
  final big = math.max(_checked(f, a).abs(), math.max(_checked(f, a + h0).abs(), _checked(f, a - h0).abs()));
  if (ans.abs() < 1e-9 * big) return 0;
  return ans;
}
