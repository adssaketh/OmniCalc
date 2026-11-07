import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/evaluator.dart';
import 'package:omnicalc/engine/js_number.dart';

import 'golden_loader.dart';

/// Math.round result as the generator printed it: "-0" for negative zero.
String signedString(double x) => (x == 0 && x.isNegative) ? '-0' : jsToString(x);

void main() {
  final vectors = (loadGolden('format') as List).cast<Map<String, dynamic>>();

  for (final v in vectors) {
    final raw = v['v'] as String;
    final x = parseGoldenNumber(raw);
    test('format $raw', () {
      expect(jsToString(x), v['tostr']);
      // toPrecision / toFixed / toExponential vectors are null for NaN and +-Infinity.
      if (v['prec12'] != null) {
        expect(jsToPrecision(x, 12), v['prec12'], reason: 'toPrecision(12)');
        expect(jsToPrecision(x, 6), v['prec6'], reason: 'toPrecision(6)');
        expect(jsToFixed(x, 2), v['fixed2'], reason: 'toFixed(2)');
        expect(jsToFixed(x, 4), v['fixed4'], reason: 'toFixed(4)');
        expect(jsToFixed(x, 8), v['fixed8'], reason: 'toFixed(8)');
        expect(jsToExponential(x, 4), v['exp4'], reason: 'toExponential(4)');
        expect(jsToExponential(x, 6), v['exp6'], reason: 'toExponential(6)');
      }
      expect(signedString(jsRound(x)), v['round'], reason: 'Math.round');
      (v['fmt'] as Map).forEach((key, expected) {
        expect(MathEvaluator.formatResult(x, int.parse(key as String)), expected, reason: 'formatResult($key)');
      });
    });
  }
}
