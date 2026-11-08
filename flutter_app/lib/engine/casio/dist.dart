// DIST mode of the Casio engine (Phase 7e, manual p.87-91): Normal PD / CD, Inverse Normal, Binomial PD / CD and Poisson
// PD / CD. The manual states an accuracy of five significant digits; the values here are computed to full double precision and
// the display rounds them (the List screen shows five significant digits).

import 'dart:math' as math;

import 'cval.dart';
import 'stat.dart';

enum DistType {
  normalPd('Normal PD', <String>['x', 'σ', 'μ']),
  normalCd('Normal CD', <String>['Lower', 'Upper', 'σ', 'μ']),
  invNorm('Inverse Normal', <String>['Area', 'σ', 'μ']),
  binomPd('Binomial PD', <String>['x', 'N', 'p']),
  binomCd('Binomial CD', <String>['x', 'N', 'p']),
  poissonPd('Poisson PD', <String>['x', 'μ']),
  poissonCd('Poisson CD', <String>['x', 'μ']);

  const DistType(this.title, this.variables);

  final String title;

  /// The variables of the input screens, in order.
  final List<String> variables;

  /// These four take a List of samples for `x` (up to 25, manual p.88).
  bool get hasList => this == binomPd || this == binomCd || this == poissonPd || this == poissonCd;
}

/// The most samples the List screen holds (manual p.88).
const int kDistListMax = 25;

class CasioDist {
  const CasioDist._();

  /// One result for [type]. [args] are the variables after `x` / the list: for example Normal PD (x, σ, μ) is `[x, σ, μ]`.
  /// A value outside its allowed range throws Argument ERROR (the manual says "an error message appears" and shows `ERROR`
  /// in the Ans column of the List screen).
  static double compute(DistType type, List<double> args) {
    if (args.length != type.variables.length) throw kArgumentError;
    switch (type) {
      case DistType.normalPd:
        final sigma = args[1];
        if (!(sigma > 0)) throw kArgumentError;
        return NormalDist.pdf(args[0], sigma, args[2]);
      case DistType.normalCd:
        final sigma = args[2];
        if (!(sigma > 0)) throw kArgumentError;
        final lo = NormalDist.cdf((args[0] - args[3]) / sigma);
        final hi = NormalDist.cdf((args[1] - args[3]) / sigma);
        return hi - lo;
      case DistType.invNorm:
        final area = args[0];
        final sigma = args[1];
        if (area < 0 || area > 1 || !(sigma > 0)) throw kArgumentError;
        if (area == 0 || area == 1) throw kMathError; // the tail goes to infinity
        return args[2] + sigma * inverseCdf(area);
      case DistType.binomPd:
      case DistType.binomCd:
        final x = args[0], n = args[1], p = args[2];
        if (!_isCount(x) || !_isCount(n) || p < 0 || p > 1 || x > n) throw kArgumentError;
        return type == DistType.binomPd ? _binomPmf(x.toInt(), n.toInt(), p) : _binomCdf(x.toInt(), n.toInt(), p);
      case DistType.poissonPd:
      case DistType.poissonCd:
        final x = args[0], mu = args[1];
        if (!_isCount(x) || !(mu > 0)) throw kArgumentError;
        return type == DistType.poissonPd ? _poissonPmf(x.toInt(), mu) : _poissonCdf(x.toInt(), mu);
    }
  }

  static bool _isCount(double v) => v >= 0 && v == v.roundToDouble() && v < 1e10;

  // ----- inverse normal -----------------------------------------------------------------------------------------------

  /// Φ⁻¹(p) for 0 < p < 1: Acklam's rational approximation, then Newton steps on the exact curve.
  static double inverseCdf(double p) {
    const a = <double>[-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02, 1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00];
    const b = <double>[-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02, 6.680131188771972e+01, -1.328068155288572e+01];
    const c = <double>[-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00, -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00];
    const d = <double>[7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00, 3.754408661907416e+00];
    const low = 0.02425;
    double x;
    if (p < low) {
      final q = math.sqrt(-2 * math.log(p));
      x = (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
    } else if (p > 1 - low) {
      final q = math.sqrt(-2 * math.log(1 - p));
      x = -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
    } else {
      final q = p - 0.5;
      final r = q * q;
      x = (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q / (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1);
    }
    for (var i = 0; i < 4; i++) {
      final err = (p < 0.5 ? NormalDist.cdf(x) - p : -(NormalDist.r(x) - (1 - p)));
      final pdf = math.exp(-0.5 * x * x) / math.sqrt(2 * math.pi);
      if (pdf == 0) break;
      x -= err / pdf;
    }
    return x;
  }

  // ----- binomial and Poisson -----------------------------------------------------------------------------------------

  /// ln Γ(x) for x > 0 (Lanczos, g = 7), about 1e-15 relative.
  static double lnGamma(double x) {
    const g = <double>[
      0.99999999999980993, 676.5203681218851, -1259.1392167224028, 771.32342877765313, -176.61502916214059,
      12.507343278686905, -0.13857109526572012, 9.9843695780195716e-6, 1.5056327351493116e-7,
    ];
    if (x < 0.5) return math.log(math.pi / math.sin(math.pi * x).abs()) - lnGamma(1 - x);
    x -= 1;
    var a = g[0];
    final t = x + 7.5;
    for (var i = 1; i < 9; i++) {
      a += g[i] / (x + i);
    }
    return 0.5 * math.log(2 * math.pi) + (x + 0.5) * math.log(t) - t + math.log(a);
  }

  static double _lnChoose(int n, int k) => lnGamma(n + 1.0) - lnGamma(k + 1.0) - lnGamma(n - k + 1.0);

  /// ln(1+x), accurate for small |x| (dart:math has no log1p).
  static double _log1p(double x) {
    if (x.abs() < 1e-4) return x - x * x / 2 + x * x * x / 3 - x * x * x * x / 4;
    return math.log(1 + x);
  }

  static double _binomPmf(int x, int n, double p) {
    if (p == 0) return x == 0 ? 1 : 0;
    if (p == 1) return x == n ? 1 : 0;
    if (n <= 60) {
      // exact product for small N keeps the usual textbook values to the last digit
      var c = 1.0;
      for (var i = 1; i <= x; i++) {
        c = c * (n - x + i) / i;
      }
      return c * math.pow(p, x) * math.pow(1 - p, n - x);
    }
    return math.exp(_lnChoose(n, x) + x * math.log(p) + (n - x) * _log1p(-p));
  }

  /// Up to this many terms the CDFs are summed term by term from 0 (the values the tests were written against). Above it the sum
  /// starts at the sample and walks away from the mean only as far as the terms still matter (Phase 8b: x can be 1e10, which
  /// used to run for minutes on the UI thread).
  static const int _kFullSumLimit = 100000;

  static double _binomCdf(int x, int n, double p) {
    if (x >= n) return 1;
    if (x <= _kFullSumLimit) {
      var s = 0.0;
      for (var k = 0; k <= x; k++) {
        s += _binomPmf(k, n, p);
      }
      return s > 1 ? 1 : s;
    }
    final mean = n * p;
    if (x < mean) {
      // lower tail: walk down from x while the terms still change the sum
      var s = 0.0;
      for (var k = x; k >= 0; k--) {
        final t = _binomPmf(k, n, p);
        s += t;
        if (t == 0 || t < s * 1e-18) break;
      }
      return s > 1 ? 1 : s;
    }
    // upper tail: 1 − P(X > x), walking up from x + 1
    var s = 0.0;
    for (var k = x + 1; k <= n; k++) {
      final t = _binomPmf(k, n, p);
      s += t;
      if (t == 0 || t < s * 1e-18) break;
    }
    final r = 1 - s;
    return r < 0 ? 0 : r;
  }

  static double _poissonPmf(int x, double mu) => math.exp(-mu + x * math.log(mu) - lnGamma(x + 1.0));

  static double _poissonCdf(int x, double mu) {
    if (x <= _kFullSumLimit) {
      var s = 0.0;
      for (var k = 0; k <= x; k++) {
        s += _poissonPmf(k, mu);
      }
      return s > 1 ? 1 : s;
    }
    if (x < mu) {
      var s = 0.0;
      for (var k = x; k >= 0; k--) {
        final t = _poissonPmf(k, mu);
        s += t;
        if (t == 0 || t < s * 1e-18) break;
      }
      return s > 1 ? 1 : s;
    }
    var s = 0.0;
    for (var k = x + 1;; k++) {
      final t = _poissonPmf(k, mu);
      s += t;
      if (t == 0 || t < s * 1e-18) break;
    }
    final r = 1 - s;
    return r < 0 ? 0 : r;
  }
}
