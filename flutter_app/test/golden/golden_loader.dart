import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// Reads test/golden/<name>.json (flutter test runs with the package root as the working directory).
dynamic loadGolden(String name) => jsonDecode(File('test/golden/$name.json').readAsStringSync());

/// Golden numbers are stored as JavaScript strings ("NaN", "Infinity", "-0", "1e+21", ...).
double parseGoldenNumber(String s) {
  switch (s) {
    case 'NaN':
      return double.nan;
    case 'Infinity':
      return double.infinity;
    case '-Infinity':
      return double.negativeInfinity;
    default:
      return double.parse(s);
  }
}

/// true when [actual] equals [expected] within [rel] relative tolerance (NaN equals NaN, infinities must match).
bool closeRel(double actual, double expected, {double rel = 1e-9}) {
  if (expected.isNaN) return actual.isNaN;
  if (actual.isNaN) return false;
  if (expected.isInfinite || actual.isInfinite) return actual == expected;
  if (actual == expected) return true;
  final scale = math.max(actual.abs(), expected.abs());
  return (actual - expected).abs() <= rel * scale;
}
