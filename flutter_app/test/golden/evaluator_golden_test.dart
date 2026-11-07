import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/calc_error.dart';
import 'package:omnicalc/engine/evaluator.dart';
import 'package:omnicalc/engine/types.dart';

import 'golden_loader.dart';

// Vectors produced by running the real TypeScript engine (see tools/gen_vectors.ts).
// raw doubles: 1e-9 relative; formatted strings and error messages: exact.
void main() {
  final vectors = (loadGolden('evaluator') as List).cast<Map<String, dynamic>>();
  const precisionKeys = <String, int>{'auto': -1, 'p2': 2, 'p4': 4, 'p6': 6, 'p8': 8};

  test('golden file is present and non-trivial', () {
    expect(vectors.length, greaterThanOrEqualTo(300));
  });

  for (final v in vectors) {
    final expr = v['expr'] as String;
    final mode = AngleMode.parse(v['mode'] as String);
    final yDef = v['yDef'] as String?;
    final label = '${v.containsKey('error') ? 'error' : 'value'}: "$expr" [${mode.id}]${yDef != null ? ' y=$yDef' : ''}';

    test(label, () {
      MathEvaluator.setYDefinition(yDef);
      addTearDown(() => MathEvaluator.setYDefinition(null));

      if (v.containsKey('error')) {
        expect(
          () => MathEvaluator.evaluate(expr, mode),
          throwsA(isA<CalcError>().having((e) => e.message, 'message', v['error'] as String)),
        );
        return;
      }

      final expected = parseGoldenNumber(v['value'] as String);
      final actual = MathEvaluator.evaluate(expr, mode);
      expect(closeRel(actual, expected), isTrue, reason: 'got $actual, expected $expected');

      final fmt = (v['fmt'] as Map).cast<String, String>();
      precisionKeys.forEach((key, precision) {
        if (!fmt.containsKey(key)) return; // equation (y = ...) vectors only record the automatic format
        expect(MathEvaluator.formatResult(actual, precision), fmt[key], reason: 'formatResult precision $precision');
      });
    });
  }
}
