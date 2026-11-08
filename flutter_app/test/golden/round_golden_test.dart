import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/js_number.dart';

import 'golden_loader.dart';

void main() {
  final vectors = (loadGolden('round') as List).cast<Map<String, dynamic>>();

  for (final v in vectors) {
    test('Math.round(${v['v']}) = ${v['r']}', () {
      final actual = jsRound(parseGoldenNumber(v['v'] as String));
      final expected = parseGoldenNumber(v['r'] as String);
      expect(actual, expected);
      expect(actual.isNegative, expected.isNegative, reason: 'sign of zero');
    });
  }
}
