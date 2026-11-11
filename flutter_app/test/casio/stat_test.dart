import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/config.dart';
import 'package:omnicalc/engine/casio/cval.dart';
import 'package:omnicalc/engine/casio/engine.dart';
import 'package:omnicalc/engine/casio/stat.dart';

Matcher near(double expected, [double rel = 1e-9]) =>
    closeTo(expected, (expected.abs() < 1e-300 ? 1 : expected.abs()) * rel);

StatData dataOf(StatType t, List<num> x, {List<num>? y, List<num>? f}) {
  final d = StatData(t, f != null);
  CVal cv(num v) => v == v.roundToDouble() ? CVal.int(v.toInt()) : CVal.dec(v.toDouble());
  for (var i = 0; i < x.length; i++) {
    d.xs[i] = cv(x[i]);
    if (y != null) d.ys[i] = cv(y[i]);
    if (f != null) d.fs[i] = cv(f[i]);
  }
  return d;
}

String shown(CasioEngine e, CasioStat s, String expr) => StatCalc.evaluate(expr, s, e).shown.display;

void main() {
  group('manual examples (p.58-66)', () {
    test('the phone editor has 200 rows in every layout', () {
      expect(statEditorRows(StatType.oneVar, false), 200);
      expect(statEditorRows(StatType.linear, false), 200);
      expect(statEditorRows(StatType.oneVar, true), 200);
      expect(statEditorRows(StatType.linear, true), 200);
      expect(StatData(StatType.linear, true).rows, 200);
    });

    test('example 2: mean 3 and population standard deviation 1.154700538 (FREQ column)', () {
      final d = dataOf(StatType.oneVar, [1, 2, 3, 4, 5], f: [1, 2, 3, 2, 1]);
      final s = CasioStat.fromData(d);
      final e = CasioEngine();
      expect(shown(e, s, 'x̄'), '3');
      expect(shown(e, s, 'σx'), '1.154700538');
      expect(s.value('n').v, 9);
    });

    test('example 3: r = 0.923 (linear), 0.998 (ln X), A = -3857.984, B = 2357.532 (Fix 3)', () {
      final x = [20.0, 110, 200, 290];
      final y = [3150.0, 7310, 8800, 9310];
      final e = CasioEngine(config: const CasioConfig(numberFormat: CasioNumberFormat.fix, digits: 3));
      final lin = CasioStat.fromData(dataOf(StatType.linear, x, y: y));
      expect(shown(e, lin, 'r'), '0.923');
      final ln = CasioStat.fromData(dataOf(StatType.ln, x, y: y));
      expect(shown(e, ln, 'r'), '0.998');
      expect(shown(e, ln, 'RegA'), '-3857.984');
      expect(shown(e, ln, 'RegB'), '2357.532');
      // example 4: x̂ for y = -130 is 4.861
      expect(shown(e, ln, '−130x̂'), '4.861');
    });

    test('example 5: normalized variate -0.762 and P(t) = 0.223 (Fix 3, FREQ column)', () {
      final d = dataOf(StatType.oneVar, [0, 1, 2, 3, 4, 5, 6, 7, 9, 10], f: [1, 2, 1, 2, 2, 2, 3, 4, 2, 1]);
      final s = CasioStat.fromData(d);
      final e = CasioEngine(config: const CasioConfig(numberFormat: CasioNumberFormat.fix, digits: 3));
      expect(shown(e, s, '3▸t'), '-0.762');
      expect(shown(e, s, 'P(3▸t)'), '0.223');
    });

    test('example 1 data keeps the editor input (170,66) (173,68) (179,75)', () {
      final s = CasioStat.fromData(dataOf(StatType.linear, [170, 173, 179], y: [66, 68, 75]));
      expect(s.value('n').v, 3);
      expect(s.value('Σx').v, 522);
      expect(s.value('Σxy').v, 170 * 66 + 173 * 68 + 179 * 75);
    });
  });

  group('results are exact where they can be', () {
    test('mean of 1, 2, 4 is the fraction 7⌟3 (unverified on a real device)', () {
      final s = CasioStat.fromData(dataOf(StatType.oneVar, [1, 2, 4]));
      expect(shown(CasioEngine(), s, 'x̄'), '7⌟3');
      expect(shown(CasioEngine(), s, 'Σx²'), '21');
    });

    test('quartiles leave the median out (n odd)', () {
      final s = CasioStat.fromData(dataOf(StatType.oneVar, [1, 2, 3, 4, 5, 6, 7]));
      expect(s.value('Q1').v, 2);
      expect(s.value('med').v, 4);
      expect(s.value('Q3').v, 6);
    });

    test('quartiles with an even count and a FREQ column', () {
      final s = CasioStat.fromData(dataOf(StatType.oneVar, [1, 2, 3, 4], f: [1, 1, 1, 1]));
      expect(s.value('Q1').v, 1.5);
      expect(s.value('med').v, 2.5);
      expect(s.value('Q3').v, 3.5);
    });

    test('min and max, sums of powers', () {
      final s = CasioStat.fromData(dataOf(StatType.linear, [3, 1, 2], y: [9, 1, 4]));
      expect(s.value('minX').v, 1);
      expect(s.value('maxY').v, 9);
      expect(s.value('Σx³').v, 36);
      expect(s.value('Σx⁴').v, 98);
      expect(s.value('Σx²y').v, 3 * 3 * 9 + 1 + 4 * 4);
    });
  });

  group('errors', () {
    test('no data is a Math ERROR', () {
      final s = CasioStat.fromData(StatData(StatType.oneVar, false));
      expect(() => s.value('x̄'), throwsA(isA<CasioError>()));
    });
    test('sx with one sample is a Math ERROR; σx is 0', () {
      final s = CasioStat.fromData(dataOf(StatType.oneVar, [5]));
      expect(() => s.value('sx'), throwsA(isA<CasioError>()));
      expect(s.value('σx').v, 0);
    });
    test('a paired row without Y is an Argument ERROR', () {
      final d = StatData(StatType.linear, false)..xs[0] = CVal.int(1);
      expect(() => CasioStat.fromData(d), throwsA(isA<CasioError>()));
    });
    test('a FREQ that is not a whole number is an Argument ERROR', () {
      final d = dataOf(StatType.oneVar, [1, 2], f: [1, 1.5]);
      expect(() => CasioStat.fromData(d), throwsA(isA<CasioError>()));
    });
    test('r is not offered for quadratic regression, RegC only there', () {
      final s = CasioStat.fromData(dataOf(StatType.quadratic, [1, 2, 3, 4], y: [1, 4, 9, 16]));
      expect(() => s.value('r'), throwsA(isA<CasioError>()));
      expect(s.value('RegC').v, near(1));
      final l = CasioStat.fromData(dataOf(StatType.linear, [1, 2, 3], y: [1, 2, 3]));
      expect(() => l.value('RegC'), throwsA(isA<CasioError>()));
    });
    test('1-VAR has no Y commands', () {
      final s = CasioStat.fromData(dataOf(StatType.oneVar, [1, 2, 3]));
      expect(() => s.value('Σy'), throwsA(isA<CasioError>()));
    });
    test('ln regression with x <= 0 is a Math ERROR', () {
      final s = CasioStat.fromData(dataOf(StatType.ln, [0, 1, 2], y: [1, 2, 3]));
      expect(() => s.value('RegA'), throwsA(isA<CasioError>()));
    });
  });

  group('Data editing', () {
    test('Ins and Del move rows', () {
      final d = dataOf(StatType.oneVar, [1, 2, 3]);
      d.insertRow(1);
      expect(d.xs[0]!.v, 1);
      expect(d.xs[1], isNull);
      expect(d.xs[2]!.v, 2);
      d.deleteRow(1);
      expect(d.xs[1]!.v, 2);
      expect(d.xs[2]!.v, 3);
      d.clear();
      expect(d.xs.every((v) => v == null), isTrue);
    });
  });

  group('independent references (mpmath, 60 digits)', () {
    final json = jsonDecode(File('test/casio/stat_matrix_vectors.json').readAsStringSync()) as Map<String, dynamic>;
    final types = <String, StatType>{
      'linear': StatType.linear,
      'quadratic': StatType.quadratic,
      'ln': StatType.ln,
      'exp': StatType.exp,
      'abExp': StatType.abExp,
      'power': StatType.power,
      'inverse': StatType.inverse,
    };
    final sets = json['stat'] as List<dynamic>;
    for (var si = 0; si < sets.length; si++) {
      final entry = sets[si] as Map<String, dynamic>;
      final ds = entry['data'] as Map<String, dynamic>;
      List<double> col(String k) => [for (final v in ds[k] as List<dynamic>) (v as num).toDouble()];
      final x = col('x');
      final y = col('y');
      final f = col('f');
      test('set $si: 1-VAR n, mean, σx, sx', () {
        final s = CasioStat.fromData(dataOf(StatType.oneVar, x, f: f));
        expect(s.value('n').v, (entry['n'] as num).toDouble());
        expect(s.value('x̄').v, near(double.parse(entry['mean'] as String)));
        expect(s.value('σx').v, near(double.parse(entry['sigx'] as String)));
        expect(s.value('sx').v, near(double.parse(entry['sx'] as String)));
      });
      final regs = entry['reg'] as Map<String, dynamic>;
      for (final k in regs.keys) {
        test('set $si: $k regression', () {
          final g = regs[k] as Map<String, dynamic>;
          final s = CasioStat.fromData(dataOf(types[k]!, x, y: y, f: f));
          expect(s.value('RegA').v, near(double.parse(g['A'] as String)), reason: 'A');
          expect(s.value('RegB').v, near(double.parse(g['B'] as String)), reason: 'B');
          if (k == 'quadratic') {
            expect(s.value('RegC').v, near(double.parse(g['C'] as String)), reason: 'C');
            expect(s.estimateX(6, which: 1).v, near(double.parse(g['xhat1'] as String)));
            expect(s.estimateX(6, which: 2).v, near(double.parse(g['xhat2'] as String)));
          } else {
            expect(s.value('r').v, near(double.parse(g['r'] as String)), reason: 'r');
            expect(s.estimateX(6).v, near(double.parse(g['xhat'] as String)), reason: 'x̂');
          }
          expect(s.estimateY(3.3).v, near(double.parse(g['yhat'] as String)), reason: 'ŷ');
        });
      }
    }
    for (final n in json['normal'] as List<dynamic>) {
      final m = n as Map<String, dynamic>;
      test('normal curve at t = ${m['t']}', () {
        final t = double.parse(m['t'] as String);
        expect(NormalDist.p(t), near(double.parse(m['P'] as String), 1e-12));
        expect(NormalDist.q(t), closeTo(double.parse(m['Q'] as String), 1e-14));
        expect(NormalDist.r(t), near(double.parse(m['R'] as String), 1e-11));
      });
    }
  });
}
