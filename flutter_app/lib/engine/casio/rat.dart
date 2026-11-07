// Exact rational numbers for the Casio fx-991ES PLUS engine (Phase 8b). BigInt based, always reduced, denominator > 0.
// The real calculator shows fractions, square roots and pi multiples exactly (manual p.21 "Toggling Calculation Results");
// this is the layer under that.

class Rat implements Comparable<Rat> {
  const Rat._(this.n, this.d);

  final BigInt n;
  final BigInt d;

  factory Rat(BigInt n, [BigInt? d]) {
    var den = d ?? BigInt.one;
    if (den == BigInt.zero) throw ArgumentError('zero denominator');
    var num = n;
    if (den.isNegative) {
      num = -num;
      den = -den;
    }
    final g = num.gcd(den);
    if (g > BigInt.one) {
      num = num ~/ g;
      den = den ~/ g;
    }
    return Rat._(num, den);
  }

  factory Rat.fromInt(int v) => Rat._(BigInt.from(v), BigInt.one);

  static final Rat zero = Rat._(BigInt.zero, BigInt.one);
  static final Rat one = Rat._(BigInt.one, BigInt.one);

  /// Exact value of a decimal literal such as `12.5`, `0.003` or `6.02E23` (no sign).
  static Rat? parseDecimal(String s) {
    final m = RegExp(r'^(\d*)(?:\.(\d*))?(?:[eE]([+-]?\d+))?$').firstMatch(s);
    if (m == null) return null;
    final intPart = m[1] ?? '';
    final frac = m[2] ?? '';
    if (intPart.isEmpty && frac.isEmpty) return null;
    var num = BigInt.parse('${intPart.isEmpty ? '0' : intPart}$frac');
    var exp = (m[3] == null ? 0 : int.parse(m[3]!)) - frac.length;
    if (exp.abs() > 400) return null;
    var den = BigInt.one;
    if (exp >= 0) {
      num = num * BigInt.from(10).pow(exp);
    } else {
      den = BigInt.from(10).pow(-exp);
    }
    return Rat(num, den);
  }

  bool get isZero => n == BigInt.zero;
  bool get isInteger => d == BigInt.one;
  bool get isNegative => n.isNegative;
  int get sign => n.sign;

  Rat operator +(Rat o) => Rat(n * o.d + o.n * d, d * o.d);
  Rat operator -(Rat o) => Rat(n * o.d - o.n * d, d * o.d);
  Rat operator *(Rat o) => Rat(n * o.n, d * o.d);
  Rat operator /(Rat o) => Rat(n * o.d, d * o.n);
  Rat operator -() => Rat._(-n, d);
  Rat abs() => n.isNegative ? Rat._(-n, d) : this;

  Rat pow(int e) {
    if (e == 0) return one;
    if (e < 0) return Rat(d.pow(-e), n.pow(-e));
    return Rat(n.pow(e), d.pow(e));
  }

  @override
  int compareTo(Rat o) => (n * o.d).compareTo(o.n * d);

  @override
  bool operator ==(Object o) => o is Rat && n == o.n && d == o.d;

  @override
  int get hashCode => Object.hash(n, d);

  /// Number of decimal digits of numerator and denominator together (used by the "10 digits" fraction limits).
  int get digitCount => n.abs().toString().length + d.toString().length;

  double toDouble() {
    if (n.bitLength < 1000 && d.bitLength < 1000) {
      final a = n.toDouble();
      final b = d.toDouble();
      if (a.isFinite && b.isFinite) return a / b;
    }
    // scale so the quotient has about 60 bits
    final shift = d.bitLength - n.bitLength + 60;
    final q = shift >= 0 ? (n << shift) ~/ d : n ~/ (d << -shift);
    var r = q.toDouble();
    return r * _pow2(-shift);
  }

  static double _pow2(int e) {
    var r = 1.0;
    var k = e;
    while (k > 0) {
      final step = k > 1000 ? 1000 : k;
      r *= _two(step);
      k -= step;
    }
    while (k < 0) {
      final step = k < -1000 ? 1000 : -k;
      r /= _two(step);
      k += step;
    }
    return r;
  }

  static double _two(int e) {
    var r = 1.0;
    for (var i = 0; i < e; i++) {
      r *= 2;
    }
    return r;
  }

  @override
  String toString() => isInteger ? '$n' : '$n/$d';
}

/// floor(sqrt(v)) for BigInt v >= 0.
BigInt isqrt(BigInt v) {
  if (v < BigInt.two) return v;
  var x = BigInt.one << ((v.bitLength + 1) >> 1);
  while (true) {
    final y = (x + v ~/ x) >> 1;
    if (y >= x) return x;
    x = y;
  }
}

/// Integer k-th root if `v` is a perfect k-th power, else null (v >= 0, k >= 2).
BigInt? exactRoot(BigInt v, int k) {
  if (v < BigInt.two) return v;
  var lo = BigInt.one;
  var hi = BigInt.one << ((v.bitLength ~/ k) + 1);
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    final p = mid.pow(k);
    final c = p.compareTo(v);
    if (c == 0) return mid;
    if (c < 0) {
      lo = mid + BigInt.one;
    } else {
      hi = mid - BigInt.one;
    }
  }
  return null;
}

/// Writes v = s^2 * r with r square free. Returns (s, r). Only trial division, so it is used for small v (< 1e12).
(BigInt, BigInt) squareFreeSplit(BigInt v) {
  var s = BigInt.one;
  var r = v;
  var p = BigInt.two;
  while (p * p <= r) {
    final pp = p * p;
    while (r % pp == BigInt.zero) {
      r ~/= pp;
      s *= p;
    }
    p += p == BigInt.two ? BigInt.one : BigInt.two;
    if (p > BigInt.from(2000000)) break; // beyond this the remaining factor is kept as is
  }
  return (s, r);
}
