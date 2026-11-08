// Exact value layer: a rational, a sum of rational multiples of square roots of square-free integers, or a rational
// multiple of pi. That is what the fx-991ES PLUS can show in Natural Display (manual p.18 "√ Form Calculation Range",
// p.21 "Toggling Calculation Results", p.99 pi form). Anything else is carried as a decimal only (`Ex` is null then).

import 'dart:math' as math;

import 'rat.dart';

/// Radicands above this are not tracked (the result falls back to a decimal).
const int kMaxRadicand = 1000000000000;

class Ex {
  Ex._(this.terms, this.pi);

  /// radicand (square free, 1 = the rational part) -> coefficient. No zero coefficients.
  final Map<int, Rat> terms;

  /// Coefficient of pi. Non-zero only when [terms] is empty.
  final Rat pi;

  static final Ex zero = Ex._(const <int, Rat>{}, Rat.zero);
  static final Ex one = Ex.rational(Rat.one);

  factory Ex.rational(Rat r) => r.isZero ? zero : Ex._(<int, Rat>{1: r}, Rat.zero);
  factory Ex.int(int v) => Ex.rational(Rat.fromInt(v));
  factory Ex.piMultiple(Rat r) => r.isZero ? zero : Ex._(const <int, Rat>{}, r);

  bool get isZero => terms.isEmpty && pi.isZero;
  bool get isPi => terms.isEmpty && !pi.isZero;
  bool get isRational => pi.isZero && (terms.isEmpty || (terms.length == 1 && terms.containsKey(1)));
  Rat get rational => terms[1] ?? Rat.zero;

  double toDouble() {
    if (isPi) return pi.toDouble() * math.pi;
    var s = 0.0;
    // smaller magnitudes first keeps the sum accurate
    final entries = terms.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    for (final e in entries) {
      s += e.value.toDouble() * (e.key == 1 ? 1.0 : math.sqrt(e.key.toDouble()));
    }
    return s;
  }

  static Ex? _make(Map<int, Rat> t, Rat pi) {
    final clean = <int, Rat>{
      for (final e in t.entries)
        if (!e.value.isZero) e.key: e.value,
    };
    if (!pi.isZero && clean.isNotEmpty) return null; // a mix of pi and other terms is shown as a decimal
    if (clean.length > 6) return null;
    return Ex._(clean, pi);
  }

  Ex? operator +(Ex o) {
    final t = <int, Rat>{...terms};
    for (final e in o.terms.entries) {
      t[e.key] = (t[e.key] ?? Rat.zero) + e.value;
    }
    return _make(t, pi + o.pi);
  }

  Ex? operator -(Ex o) => this + (-o)!;

  Ex? operator -() => _make(<int, Rat>{for (final e in terms.entries) e.key: -e.value}, -pi);

  Ex? operator *(Ex o) {
    if (isZero || o.isZero) return zero;
    if (!pi.isZero || !o.pi.isZero) {
      // pi times a rational only
      if (!pi.isZero && o.isRational) return Ex.piMultiple(pi * o.rational);
      if (!o.pi.isZero && isRational) return Ex.piMultiple(o.pi * rational);
      return null;
    }
    final t = <int, Rat>{};
    for (final a in terms.entries) {
      for (final b in o.terms.entries) {
        final g = _gcd(a.key, b.key);
        final k = (a.key ~/ g) * (b.key ~/ g);
        if (k > kMaxRadicand) return null;
        final c = a.value * b.value * Rat.fromInt(g);
        t[k] = (t[k] ?? Rat.zero) + c;
      }
    }
    return _make(t, Rat.zero);
  }

  /// 1 / this, or null when it has no exact form here.
  Ex? inverse() {
    if (isZero) return null;
    if (isRational) return Ex.rational(Rat.one / rational);
    if (!pi.isZero) return null;
    if (terms.length == 1) {
      final e = terms.entries.first; // c sqrt(k): 1/(c sqrt k) = sqrt(k) / (c k)
      return Ex._(<int, Rat>{e.key: Rat.one / (e.value * Rat.fromInt(e.key))}, Rat.zero);
    }
    if (terms.length == 2) {
      final es = terms.entries.toList();
      final a = es[0], b = es[1];
      // (a1 sqrt k1 + a2 sqrt k2)(a1 sqrt k1 - a2 sqrt k2) = a1^2 k1 - a2^2 k2
      final den = a.value * a.value * Rat.fromInt(a.key) - b.value * b.value * Rat.fromInt(b.key);
      if (den.isZero) return null;
      final conj = Ex._(<int, Rat>{a.key: a.value / den, b.key: -b.value / den}, Rat.zero);
      return conj;
    }
    return null;
  }

  Ex? operator /(Ex o) {
    final inv = o.inverse();
    if (inv == null) {
      // pi multiple divided by pi multiple is rational
      if (isPi && o.isPi) return Ex.rational(pi / o.pi);
      return null;
    }
    return this * inv;
  }

  /// Integer power (|e| <= 64).
  Ex? powInt(int e) {
    if (e == 0) return one;
    if (e.abs() > 64) return null;
    var base = this;
    if (e < 0) {
      final inv = inverse();
      if (inv == null) return null;
      base = inv;
    }
    if (isRational) return Ex.rational(base.rational.pow(e.abs()));
    var result = one;
    for (var i = 0; i < e.abs(); i++) {
      final r = result * base;
      if (r == null) return null;
      result = r;
    }
    return result;
  }

  /// Square root of a non-negative rational as an exact value (sqrt(8) = 2 sqrt 2).
  static Ex? sqrtRational(Rat r) {
    if (r.isNegative) return null;
    if (r.isZero) return zero;
    // sqrt(n/d) = sqrt(n d) / d
    final nd = r.n * r.d;
    if (nd > BigInt.from(kMaxRadicand) * BigInt.from(kMaxRadicand)) return null;
    final (s, k) = squareFreeSplit(nd);
    if (k > BigInt.from(kMaxRadicand)) return null;
    return Ex._(<int, Rat>{k.toInt(): Rat(s, r.d)}, Rat.zero);
  }

  /// Square root of this value when that is exact: only rationals are handled.
  Ex? sqrt() => isRational ? sqrtRational(rational) : null;

  /// Sign of the value (-1, 0, 1), decided on the double value.
  int get signum {
    final v = toDouble();
    return v > 0 ? 1 : (v < 0 ? -1 : 0);
  }

  static int _gcd(int a, int b) {
    while (b != 0) {
      final t = a % b;
      a = b;
      b = t;
    }
    return a;
  }

  @override
  String toString() => isPi ? '${pi}π' : terms.entries.map((e) => '${e.value}√${e.key}').join('+');
}
