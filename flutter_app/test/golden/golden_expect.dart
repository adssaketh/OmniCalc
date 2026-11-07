import 'package:flutter_test/flutter_test.dart';

import 'golden_loader.dart';

/// A JSON input number: either a number or a JavaScript number string ("NaN", "Infinity", "-0", ...).
double toD(dynamic x) => x is String ? parseGoldenNumber(x) : (x as num).toDouble();

/// The expected double of an encoded golden number `{"n": "<JS String(v)>"}`.
double goldenN(dynamic node) => parseGoldenNumber((node as Map)['n'] as String);

/// Raw doubles: 1e-9 relative (NaN equals NaN, infinities must match). Zeros must also agree in sign, like the TS output.
void expectNum(double actual, dynamic node, String what) {
  final expected = goldenN(node);
  expect(closeRel(actual, expected), isTrue, reason: '$what: got $actual, expected $expected');
  if (expected == 0) {
    expect(actual.isNegative, expected.isNegative, reason: '$what: sign of zero (got $actual, expected $expected)');
  }
}
