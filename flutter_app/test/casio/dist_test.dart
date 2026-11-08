// DIST (manual p.87-91): the manual's examples and the independent reference vectors of tools/gen_ineq_dist.py.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/cval.dart';
import 'package:omnicalc/engine/casio/dist.dart';

Matcher near(double expected, [double rel = 1e-9]) => closeTo(expected, (expected.abs() < 1e-300 ? 1 : expected.abs()) * rel);

void main() {
  group('manual examples', () {
    test('example 1: Normal PD x=36, σ=2, μ=35 gives 0.1760326634', () {
      expect(CasioDist.compute(DistType.normalPd, [36, 2, 35]), near(0.1760326634, 1e-9));
    });

    test('example 2: Binomial PD of {10..14}, N=15, p=0.6 to the five digits of the manual', () {
      const want = <int, double>{10: 0.18594, 11: 0.12678, 12: 0.063388, 13: 0.021942, 14: 0.0047018};
      want.forEach((x, w) {
        expect(CasioDist.compute(DistType.binomPd, [x.toDouble(), 15, 0.6]), near(w, 1e-4), reason: 'x=$x');
      });
    });
  });

  group('rules', () {
    test('the variables and the list limit', () {
      expect(DistType.normalPd.variables, ['x', 'σ', 'μ']);
      expect(DistType.normalCd.variables, ['Lower', 'Upper', 'σ', 'μ']);
      expect(DistType.invNorm.variables, ['Area', 'σ', 'μ']);
      expect(DistType.binomCd.variables, ['x', 'N', 'p']);
      expect(DistType.poissonPd.variables, ['x', 'μ']);
      expect(DistType.values.where((t) => t.hasList).length, 4);
      expect(kDistListMax, 25);
    });

    test('values outside the allowed range are an Argument ERROR', () {
      void bad(DistType t, List<double> a) => expect(() => CasioDist.compute(t, a), throwsA(kArgumentError), reason: '$t $a');
      bad(DistType.normalPd, [0, 0, 0]);
      bad(DistType.normalPd, [0, -1, 0]);
      bad(DistType.invNorm, [1.5, 1, 0]);
      bad(DistType.invNorm, [-0.1, 1, 0]);
      bad(DistType.binomPd, [2.5, 10, 0.5]);
      bad(DistType.binomPd, [3, 10, 1.5]);
      bad(DistType.binomPd, [11, 10, 0.5]);
      bad(DistType.binomPd, [-1, 10, 0.5]);
      bad(DistType.poissonPd, [1, 0]);
      bad(DistType.poissonCd, [1.5, 2]);
    });

    test('Area 0 or 1 is a Math ERROR (the tail never ends)', () {
      expect(() => CasioDist.compute(DistType.invNorm, [0, 1, 0]), throwsA(kMathError));
      expect(() => CasioDist.compute(DistType.invNorm, [1, 1, 0]), throwsA(kMathError));
    });

    test('Binomial CD adds up to 1 at x = N, Poisson CD approaches 1', () {
      expect(CasioDist.compute(DistType.binomCd, [10, 10, 0.3]), near(1, 1e-12));
      expect(CasioDist.compute(DistType.poissonCd, [60, 5]), near(1, 1e-12));
    });

    test('Normal CD is symmetric and Inverse Normal inverts it', () {
      expect(CasioDist.compute(DistType.normalCd, [-1.96, 1.96, 1, 0]), near(0.950004209703559, 1e-9));
      final z = CasioDist.compute(DistType.invNorm, [0.975, 1, 0]);
      expect(z, near(1.959963984540054, 1e-9));
    });
  });

  group('independent reference vectors (mpmath)', () {
    final data = jsonDecode(File('test/casio/ineq_dist.json').readAsStringSync()) as Map<String, dynamic>;
    final cases = (data['dist'] as List).cast<Map<String, dynamic>>();
    for (final k in cases) {
      final type = DistType.values.firstWhere((t) => t.name == k['type']);
      final args = [for (final a in k['args'] as List) (a as num).toDouble()];
      test('${type.title} ${args.join(', ')}', () {
        final want = double.parse(k['value'] as String);
        expect(CasioDist.compute(type, args), near(want, 1e-9));
      });
    }
  });
}
