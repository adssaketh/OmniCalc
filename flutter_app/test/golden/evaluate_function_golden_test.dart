import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/evaluator.dart';
import 'package:omnicalc/engine/types.dart';

import 'golden_loader.dart';

void main() {
  final vectors = (loadGolden('evaluate_function') as List).cast<Map<String, dynamic>>();

  for (final v in vectors) {
    final expr = v['expr'] as String;
    final x = parseGoldenNumber(v['x'] as String);
    final mode = AngleMode.parse(v['mode'] as String);
    test('f(x) = "$expr" at x = ${v['x']} [${mode.id}]', () {
      final expected = parseGoldenNumber(v['value'] as String);
      final actual = MathEvaluator.evaluateFunction(expr, x, mode);
      expect(closeRel(actual, expected), isTrue, reason: 'got $actual, expected $expected');
    });
  }
}
