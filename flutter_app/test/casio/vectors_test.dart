// Reference values from tools/gen_casio_vectors.py (mpmath, 60 digits): the engine must agree to 1e-9 relative, the unit's
// "±1 at the 10th digit" (manual p.97).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/config.dart';
import 'package:omnicalc/engine/casio/engine.dart';

void main() {
  final vectors = (jsonDecode(File('test/casio/vectors.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();
  test('the vector file is present and non-trivial', () => expect(vectors.length, greaterThan(200)));
  for (final v in vectors) {
    final expr = v['expr'] as String;
    final angle = v['angle'] as String;
    test('$expr [$angle]', () {
      final e = CasioEngine(
          config: CasioConfig(angle: {'deg': CasioAngle.deg, 'rad': CasioAngle.rad, 'gra': CasioAngle.gra}[angle]!));
      final got = e.evaluate(expr).value!.v;
      final want = double.parse(v['value'] as String);
      final tol = want.abs() * 1e-9 + 1e-14;
      expect((got - want).abs() <= tol, isTrue, reason: 'got $got, expected $want');
    });
  }
}
