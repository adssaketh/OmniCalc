// JavaScript-compatible number helpers.
//
// The TypeScript engine (src/engine/evaluator.ts) is the oracle, and it runs on V8. Dart's number
// formatting and a few `dart:math` behaviours differ from JavaScript, so everything the engine relies
// on is re-implemented here to give the same strings and the same edge-case results:
//
//   Number.prototype.toString / toFixed / toPrecision / toExponential, parseFloat, Math.round,
//   the `%` operator, Math.pow, Math.sign, Math.cbrt, Math.log10, Math.log2 and the hyperbolic family.
//
// All formatting is exact (BigInt arithmetic on the binary value), never locale dependent.

import 'dart:math' as math;
import 'dart:typed_data';

const double _nan = double.nan;
const double _inf = double.infinity;

// ---------------------------------------------------------------------------------------------
// Exact decimal helpers
// ---------------------------------------------------------------------------------------------

final Map<int, BigInt> _pow10Cache = <int, BigInt>{};

BigInt _pow10(int n) => _pow10Cache.putIfAbsent(n, () => BigInt.from(10).pow(n));

/// x (finite, > 0) as an exact fraction num / den.
(BigInt, BigInt) _fraction(double x) {
  final bd = ByteData(8)..setFloat64(0, x, Endian.big);
  final hi = bd.getUint32(0, Endian.big);
  final lo = bd.getUint32(4, Endian.big);
  final expBits = (hi >> 20) & 0x7ff;
  var mant = (BigInt.from(hi & 0xfffff) << 32) | BigInt.from(lo);
  int e;
  if (expBits == 0) {
    e = -1074;
  } else {
    mant |= BigInt.one << 52;
    e = expBits - 1075;
  }
  if (e >= 0) return (mant << e, BigInt.one);
  return (mant, BigInt.one << -e);
}

/// round(a / b), ties go up (the choice JavaScript makes when two candidates are equally close).
BigInt _divRoundHalfUp(BigInt a, BigInt b) {
  final q = a ~/ b;
  final r = a - q * b;
  return (r * BigInt.two >= b) ? q + BigInt.one : q;
}

/// For x > 0 returns (n, e) with 10^(p-1) <= n < 10^p and n * 10^(e-p+1) closest to x.
(BigInt, int) _roundedDigits(double x, int p) {
  final (nu, de) = _fraction(x);
  // Estimate floor(log10(x)) from the shortest representation, then correct it exactly.
  final s = x.toStringAsExponential();
  var e = int.parse(s.substring(s.indexOf('e') + 1));
  bool atLeast(int k) => k >= 0 ? nu >= de * _pow10(k) : nu * _pow10(-k) >= de;
  while (!atLeast(e)) {
    e--;
  }
  while (atLeast(e + 1)) {
    e++;
  }
  final shift = e - p + 1;
  var n = shift >= 0
      ? _divRoundHalfUp(nu, de * _pow10(shift))
      : _divRoundHalfUp(nu * _pow10(-shift), de);
  if (n == _pow10(p)) {
    n = _pow10(p - 1);
    e++;
  }
  return (n, e);
}

// ---------------------------------------------------------------------------------------------
// Number -> string
// ---------------------------------------------------------------------------------------------

/// `String(x)` / `x.toString()` in JavaScript (shortest round-trip digits, exponent switch at 1e21 / 1e-7).
String jsToString(double x) {
  if (x.isNaN) return 'NaN';
  if (x == 0) return '0'; // also -0
  if (x.isInfinite) return x > 0 ? 'Infinity' : '-Infinity';
  final sign = x < 0 ? '-' : '';
  final s = x.abs().toStringAsExponential();
  final eIdx = s.indexOf('e');
  var digits = s.substring(0, eIdx).replaceAll('.', '');
  if (digits.length > 1) {
    digits = digits.replaceFirst(RegExp(r'0+$'), '');
    if (digits.isEmpty) digits = '0';
  }
  final exp10 = int.parse(s.substring(eIdx + 1));
  final k = digits.length;
  final n = exp10 + 1;
  if (k <= n && n <= 21) return '$sign$digits${'0' * (n - k)}';
  if (0 < n && n <= 21) return '$sign${digits.substring(0, n)}.${digits.substring(n)}';
  if (-6 < n && n <= 0) return '${sign}0.${'0' * (-n)}$digits';
  final e = n - 1;
  final es = '${e < 0 ? '-' : '+'}${e.abs()}';
  if (k == 1) return '$sign${digits}e$es';
  return '$sign${digits[0]}.${digits.substring(1)}e$es';
}

/// `x.toFixed(d)`.
String jsToFixed(double x, int d) {
  if (x.isNaN) return 'NaN';
  if (x.abs() >= 1e21) return jsToString(x);
  final neg = x < 0;
  final ax = x.abs();
  BigInt n;
  if (ax == 0) {
    n = BigInt.zero;
  } else {
    final (nu, de) = _fraction(ax);
    n = _divRoundHalfUp(nu * _pow10(d), de);
  }
  var s = n.toString();
  if (d > 0) {
    if (s.length <= d) s = '0' * (d - s.length + 1) + s;
    s = '${s.substring(0, s.length - d)}.${s.substring(s.length - d)}';
  }
  return neg ? '-$s' : s;
}

/// `x.toPrecision(p)` for 1 <= p <= 100.
String jsToPrecision(double x, int p) {
  if (x.isNaN) return 'NaN';
  if (x.isInfinite) return x > 0 ? 'Infinity' : '-Infinity';
  var sign = '';
  if (x < 0) {
    sign = '-';
    x = -x;
  }
  String m;
  int e;
  if (x == 0) {
    m = '0' * p;
    e = 0;
  } else {
    final (n, ee) = _roundedDigits(x, p);
    m = n.toString();
    e = ee;
  }
  if (e < -6 || e >= p) {
    final a = p > 1 ? '${m[0]}.${m.substring(1)}' : m;
    return '$sign${a}e${e >= 0 ? '+' : '-'}${e.abs()}';
  }
  if (e == p - 1) return '$sign$m';
  if (e >= 0) return '$sign${m.substring(0, e + 1)}.${m.substring(e + 1)}';
  return '${sign}0.${'0' * (-(e + 1))}$m';
}

/// `x.toExponential(f)` with an explicit number of fraction digits.
String jsToExponential(double x, int f) {
  if (x.isNaN) return 'NaN';
  if (x.isInfinite) return x > 0 ? 'Infinity' : '-Infinity';
  var sign = '';
  if (x < 0) {
    sign = '-';
    x = -x;
  }
  String m;
  int e;
  if (x == 0) {
    m = '0' * (f + 1);
    e = 0;
  } else {
    final (n, ee) = _roundedDigits(x, f + 1);
    m = n.toString();
    e = ee;
  }
  final a = f > 0 ? '${m[0]}.${m.substring(1)}' : m;
  return '$sign${a}e${e >= 0 ? '+' : '-'}${e.abs()}';
}

// ---------------------------------------------------------------------------------------------
// String -> number
// ---------------------------------------------------------------------------------------------

final RegExp _floatPrefix = RegExp(r'^[+-]?(?:Infinity|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)');

/// `parseFloat(s)`: parses the longest numeric prefix, NaN when there is none.
double jsParseFloat(String s) {
  final t = s.trimLeft();
  final m = _floatPrefix.firstMatch(t);
  if (m == null) return _nan;
  var str = m[0]!;
  if (str.endsWith('Infinity')) return str.startsWith('-') ? -_inf : _inf;
  str = str.replaceFirstMapped(RegExp(r'^([+-]?)\.'), (mm) => '${mm[1]}0.');
  str = str.replaceFirstMapped(RegExp(r'\.(?=$|[eE])'), (mm) => '');
  return double.parse(str);
}

// ---------------------------------------------------------------------------------------------
// Math.* and operators
// ---------------------------------------------------------------------------------------------

/// `Number.isInteger`.
bool jsIsInteger(double x) => x.isFinite && x == x.truncateToDouble();

/// `Math.round`: halves go toward +Infinity and -0 is kept (Dart's round() goes away from zero).
double jsRound(double x) {
  if (x.isNaN || x.isInfinite) return x;
  if (x.abs() >= 4503599627370496.0) return x; // already an integer
  if (x == 0) return x; // keeps -0
  final f = x.floorToDouble();
  final r = (x - f) >= 0.5 ? f + 1 : f;
  if (r == 0 && x < 0) return -0.0;
  return r;
}

/// JavaScript `%`: the result takes the sign of the dividend (Dart's `%` is always non-negative).
double jsMod(double a, double b) => a.remainder(b);

/// `Math.pow` (differs from Dart's pow for NaN exponents and |base| == 1 with infinite exponents).
double jsPow(double a, double b) {
  if (b.isNaN) return _nan;
  if (b == 0) return 1;
  if ((a == 1 || a == -1) && b.isInfinite) return _nan;
  return math.pow(a, b).toDouble();
}

/// `Math.sign`.
double jsSign(double x) {
  if (x.isNaN || x == 0) return x;
  return x > 0 ? 1.0 : -1.0;
}

double jsMin(Iterable<double> values) {
  var r = _inf;
  for (final v in values) {
    if (v.isNaN) return _nan;
    r = math.min(r, v);
  }
  return r;
}

double jsMax(Iterable<double> values) {
  var r = -_inf;
  for (final v in values) {
    if (v.isNaN) return _nan;
    r = math.max(r, v);
  }
  return r;
}

/// `Math.cbrt`: exact for perfect cubes, within an ulp otherwise.
double jsCbrt(double x) {
  if (x == 0 || x.isNaN || x.isInfinite) return x;
  final ax = x.abs();
  var r = math.pow(ax, 1.0 / 3.0).toDouble();
  r = r - (r * r * r - ax) / (3 * r * r);
  r = r - (r * r * r - ax) / (3 * r * r);
  final rr = r.roundToDouble();
  if (rr * rr * rr == ax) r = rr;
  return x < 0 ? -r : r;
}

const double _ivLn10 = 4.34294481903251816668e-01;
const double _log10Of2Hi = 3.01029995663611771306e-01;
const double _log10Of2Lo = 3.69423907715893078616e-13;

/// `Math.log10`, the fdlibm algorithm V8 uses, so exact powers of ten give exact integers.
double jsLog10(double x) {
  if (x.isNaN || x < 0) return _nan;
  if (x == 0) return -_inf;
  if (x.isInfinite) return x;
  final bd = ByteData(8);
  var v = x;
  bd.setFloat64(0, v, Endian.big);
  var hx = bd.getInt32(0, Endian.big);
  var k = 0;
  if (hx < 0x00100000) {
    k -= 54;
    v *= 18014398509481984.0; // 2^54
    bd.setFloat64(0, v, Endian.big);
    hx = bd.getInt32(0, Endian.big);
  }
  k += (hx >> 20) - 1023;
  final i = k < 0 ? 1 : 0;
  hx = (hx & 0x000fffff) | ((0x3ff - i) << 20);
  final y = (k + i).toDouble();
  bd.setInt32(0, hx, Endian.big);
  v = bd.getFloat64(0, Endian.big);
  final z = y * _log10Of2Lo + _ivLn10 * math.log(v);
  final r = z + y * _log10Of2Hi;
  // fdlibm guarantees log10(10^n) == n for n = 0..22; keep that even if the platform log() differs by an ulp.
  final rr = r.roundToDouble();
  if ((r - rr).abs() < 1e-9 && rr >= -22 && rr <= 22 && math.pow(10, rr).toDouble() == x) return rr;
  return r;
}

/// `Math.log2`: exact for powers of two.
double jsLog2(double x) {
  if (x.isNaN || x < 0) return _nan;
  if (x == 0) return -_inf;
  if (x.isInfinite) return x;
  final bd = ByteData(8)..setFloat64(0, x, Endian.big);
  final hi = bd.getUint32(0, Endian.big);
  final lo = bd.getUint32(4, Endian.big);
  final expBits = (hi >> 20) & 0x7ff;
  if (expBits != 0 && (hi & 0xfffff) == 0 && lo == 0) return (expBits - 1023).toDouble();
  return math.log(x) / math.ln2;
}

/// expm1 / log1p via Kahan's trick (accurate for small arguments).
double jsExpm1(double x) {
  if (x.isNaN) return x;
  if (x == 0) return x;
  if (x.isInfinite) return x > 0 ? x : -1.0;
  final u = math.exp(x);
  if (u == 1.0) return x;
  final um1 = u - 1.0;
  if (um1 == -1.0) return -1.0;
  if (u.isInfinite) return u;
  return um1 * x / math.log(u);
}

double jsLog1p(double x) {
  if (x.isNaN) return x;
  if (x == -1) return -_inf;
  if (x < -1) return _nan;
  if (x.isInfinite) return x;
  final u = 1.0 + x;
  if (u == 1.0) return x;
  return math.log(u) * x / (u - 1.0);
}

const double _overflowThreshold = 710.4758600739439;

/// fdlibm sinh.
double jsSinh(double x) {
  if (x.isNaN || x.isInfinite || x == 0) return x;
  final h = x < 0 ? -0.5 : 0.5;
  final ax = x.abs();
  if (ax < 22) {
    if (ax < 3.725290298461914e-9) return x; // 2^-28
    final t = jsExpm1(ax);
    if (ax < 1) return h * (2.0 * t - t * t / (t + 1.0));
    return h * (t + t / (t + 1.0));
  }
  if (ax < 709.782712893384) return h * math.exp(ax);
  if (ax <= _overflowThreshold) {
    final w = math.exp(0.5 * ax);
    final t = h * w;
    return t * w;
  }
  return x > 0 ? _inf : -_inf;
}

/// fdlibm cosh.
double jsCosh(double x) {
  if (x.isNaN) return x;
  final ax = x.abs();
  if (ax.isInfinite) return _inf;
  if (ax < 0.34657359027997264) {
    final t = jsExpm1(ax);
    final w = 1.0 + t;
    if (ax < 2.7755575615628914e-17) return w; // 2^-55
    return 1.0 + (t * t) / (w + w);
  }
  if (ax < 22) {
    final t = math.exp(ax);
    return 0.5 * t + 0.5 / t;
  }
  if (ax < 709.782712893384) return 0.5 * math.exp(ax);
  if (ax <= _overflowThreshold) {
    final w = math.exp(0.5 * ax);
    final t = 0.5 * w;
    return t * w;
  }
  return _inf;
}

/// fdlibm tanh.
double jsTanh(double x) {
  if (x.isNaN) return x;
  if (x.isInfinite) return x > 0 ? 1.0 : -1.0;
  final ax = x.abs();
  double z;
  if (ax < 22) {
    if (ax < 2.7755575615628914e-17) return x * (1.0 + x);
    if (ax >= 1) {
      final t = jsExpm1(2.0 * ax);
      z = 1.0 - 2.0 / (t + 2.0);
    } else {
      final t = jsExpm1(-2.0 * ax);
      z = -t / (t + 2.0);
    }
  } else {
    z = 1.0;
  }
  return x >= 0 ? z : -z;
}

/// fdlibm asinh.
double jsAsinh(double x) {
  if (x.isNaN || x.isInfinite || x == 0) return x;
  final ax = x.abs();
  if (ax < 3.725290298461914e-9) return x;
  double w;
  if (ax > 268435456.0) {
    w = math.log(ax) + math.ln2;
  } else if (ax > 2.0) {
    w = math.log(2.0 * ax + 1.0 / (math.sqrt(x * x + 1.0) + ax));
  } else {
    final t = x * x;
    w = jsLog1p(ax + t / (1.0 + math.sqrt(1.0 + t)));
  }
  return x > 0 ? w : -w;
}

/// fdlibm acosh (callers check x >= 1 first).
double jsAcosh(double x) {
  if (x.isNaN) return x;
  if (x < 1) return _nan;
  if (x >= 268435456.0) {
    if (x.isInfinite) return x;
    return math.log(x) + math.ln2;
  }
  if (x == 1) return 0.0;
  if (x > 2.0) {
    final t = x * x;
    return math.log(2.0 * x - 1.0 / (x + math.sqrt(t - 1.0)));
  }
  final t = x - 1.0;
  return jsLog1p(t + math.sqrt(2.0 * t + t * t));
}

/// fdlibm atanh (callers check |x| < 1 first).
double jsAtanh(double x) {
  if (x.isNaN) return x;
  final ax = x.abs();
  if (ax > 1) return _nan;
  if (ax == 1) return x > 0 ? _inf : -_inf;
  if (ax < 3.725290298461914e-9) return x;
  double t;
  if (ax < 0.5) {
    t = ax + ax;
    t = 0.5 * jsLog1p(t + t * ax / (1.0 - ax));
  } else {
    t = 0.5 * jsLog1p((ax + ax) / (1.0 - ax));
  }
  return x >= 0 ? t : -t;
}
