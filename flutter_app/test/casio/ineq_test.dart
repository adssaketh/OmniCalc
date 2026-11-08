// INEQ (manual p.82-84): the manual's four examples and the two special results, then the independent reference vectors of
// tools/gen_ineq_dist.py.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/complex.dart';
import 'package:omnicalc/engine/casio/config.dart';
import 'package:omnicalc/engine/casio/cval.dart';
import 'package:omnicalc/engine/casio/ineq.dart';

void main() {
  final eng = CasioComplexEngine(CasioMemory());
  const cfg = CasioConfig();
  List<CVal> c(List<num> xs) => [for (final x in xs) x is int ? CVal.int(x) : CVal.dec(x.toDouble())];
  String fmt(CVal v) => eng.show(CasioComplexHelper.real(v), cfg).text;
  List<String> solve(IneqType t, IneqRel r, List<num> coef) => CasioIneq.solve(t, r, c(coef)).lines(fmt);

  group('manual examples (p.83-84)', () {
    test('example 1: x²+2x−3 < 0 gives −3<X<1', () {
      expect(solve(IneqType.quadratic, IneqRel.lt, [1, 2, -3]), ['-3<X<1']);
    });

    test('example 2: x²+2x−3 ≥ 0 gives X≤−3 and 1≤X', () {
      expect(solve(IneqType.quadratic, IneqRel.ge, [1, 2, -3]), ['X≤-3', '1≤X']);
    });

    test('example 3: 2x³−3x² ≥ 0 gives X=0 and 3/2≤X', () {
      expect(solve(IneqType.cubic, IneqRel.ge, [2, -3, 0, 0]), ['X=0', '3⌟2≤X']);
    });

    test('example 4: 3x³+3x²−x > 0 has two intervals around the roots (−3±√21)/6 and 0', () {
      final r = CasioIneq.solve(IneqType.cubic, IneqRel.gt, c([3, 3, -1, 0]));
      expect(r.parts.length, 2);
      expect(r.parts[0].lo!.v, closeTo((-3 - 4.58257569495584) / 6, 1e-12));
      expect(r.parts[0].hi!.v, closeTo(0, 1e-12));
      expect(r.parts[1].lo!.v, closeTo((-3 + 4.58257569495584) / 6, 1e-12));
      expect(r.parts[1].hi, isNull);
    });

    test('x² ≥ 0 shows All Real Numbers, x² < 0 shows No-Solution', () {
      expect(solve(IneqType.quadratic, IneqRel.ge, [1, 0, 0]), ['All Real Numbers']);
      expect(solve(IneqType.quadratic, IneqRel.lt, [1, 0, 0]), ['No-Solution']);
    });
  });

  group('rules', () {
    test('a = 0 is a Math ERROR, a wrong cell count an Argument ERROR', () {
      expect(() => CasioIneq.solve(IneqType.quadratic, IneqRel.gt, c([0, 1, 1])), throwsA(kMathError));
      expect(() => CasioIneq.solve(IneqType.quadratic, IneqRel.gt, c([1, 1])), throwsA(kArgumentError));
    });

    test('a double root: x²−2x+1 > 0 leaves the root out, ≤ 0 keeps only it', () {
      expect(solve(IneqType.quadratic, IneqRel.gt, [1, -2, 1]), ['X<1', '1<X']);
      expect(solve(IneqType.quadratic, IneqRel.le, [1, -2, 1]), ['X=1']);
      expect(solve(IneqType.quadratic, IneqRel.ge, [1, -2, 1]), ['All Real Numbers']);
    });

    test('negative leading coefficient flips the sides', () {
      expect(solve(IneqType.quadratic, IneqRel.gt, [-1, 0, 4]), ['-2<X<2']);
      expect(solve(IneqType.quadratic, IneqRel.lt, [-1, 0, 4]), ['X<-2', '2<X']);
    });

    test('a cubic with one real root has one half line', () {
      expect(solve(IneqType.cubic, IneqRel.gt, [1, 0, 0, 0]), ['0<X']);
      expect(solve(IneqType.cubic, IneqRel.ge, [1, 0, 1, 0]), ['0≤X']);
    });

    test('exact roots stay exact: 2x²−3x−6 < 0', () {
      expect(solve(IneqType.quadratic, IneqRel.lt, [2, -3, -6]), ['(3-√57)÷4<X<(3+√57)÷4']);
    });
  });

  // The header line and named endpoints of the solution screen (manual p.82-84, read from the user's page screenshots).
  // Examples 2 and 4 are read from the pages; Examples 1 and 3 and the double-root case follow the same rule and are
  // unverified on a real device.
  group('header and endpoints (O04)', () {
    IneqLayout layoutOf(IneqType t, IneqRel r, List<num> coef) => CasioIneq.solve(t, r, c(coef)).layout()!;

    test('example 1: −3<X<1 has the header A<X<B with A=−3, B=1', () {
      final l = layoutOf(IneqType.quadratic, IneqRel.lt, [1, 2, -3]);
      expect(l.header, 'A<X<B');
      expect([for (final e in l.endpoints) e.name], ['A', 'B']);
      expect([for (final e in l.endpoints) e.value.v], [-3, 1]);
    });

    test('example 2 (page 82): X≤−3 and 1≤X has the header X≤A,B≤X with A=−3, B=1', () {
      final l = layoutOf(IneqType.quadratic, IneqRel.ge, [1, 2, -3]);
      expect(l.header, 'X≤A,B≤X');
      expect([for (final e in l.endpoints) e.name], ['A', 'B']);
      expect([for (final e in l.endpoints) e.value.v], [-3, 1]);
    });

    test('example 3: X=0 and 3/2≤X has the header X=A,B≤X with A=0, B=1.5', () {
      final l = layoutOf(IneqType.cubic, IneqRel.ge, [2, -3, 0, 0]);
      expect(l.header, 'X=A,B≤X');
      expect([for (final e in l.endpoints) e.value.v], [0, 1.5]);
    });

    test('example 4 (page 82): the cubic has the header A<X<B,C<X and three endpoints', () {
      final l = layoutOf(IneqType.cubic, IneqRel.gt, [3, 3, -1, 0]);
      expect(l.header, 'A<X<B,C<X');
      expect([for (final e in l.endpoints) e.name], ['A', 'B', 'C']);
      // the manual shows A=−1.263762616, B=0, C=0.2637626158
      expect(l.endpoints[0].value.v, closeTo(-1.263762616, 1e-9));
      expect(l.endpoints[1].value.v, 0);
      expect(l.endpoints[2].value.v, closeTo(0.2637626158, 1e-9));
    });

    test('a root left out of both neighbouring parts keeps one name: X<A,A<X', () {
      final l = layoutOf(IneqType.quadratic, IneqRel.gt, [1, -2, 1]);
      expect(l.header, 'X<A,A<X');
      expect(l.endpoints.length, 1);
      expect(l.endpoints.single.value.v, 1);
      expect(layoutOf(IneqType.quadratic, IneqRel.le, [1, -2, 1]).header, 'X=A');
    });

    test('a negative leading coefficient: X<A,B<X and A<X<B', () {
      expect(layoutOf(IneqType.quadratic, IneqRel.lt, [-1, 0, 4]).header, 'X<A,B<X');
      expect(layoutOf(IneqType.quadratic, IneqRel.gt, [-1, 0, 4]).header, 'A<X<B');
    });

    test('half lines of a cubic with one real root: A<X and A≤X', () {
      expect(layoutOf(IneqType.cubic, IneqRel.gt, [1, 0, 0, 0]).header, 'A<X');
      expect(layoutOf(IneqType.cubic, IneqRel.ge, [1, 0, 1, 0]).header, 'A≤X');
    });

    test('All Real Numbers and No-Solution have no header (same in both displays)', () {
      expect(CasioIneq.solve(IneqType.quadratic, IneqRel.ge, c([1, 0, 0])).layout(), isNull);
      expect(CasioIneq.solve(IneqType.quadratic, IneqRel.lt, c([1, 0, 0])).layout(), isNull);
    });

    test('the header never carries a number, and the number of names is the number of distinct endpoints', () {
      for (final coef in const <List<num>>[
        [1, 2, -3],
        [2, -3, -6],
        [3, 3, -1, 0],
        [1, -6, 11, -6],
      ]) {
        final type = coef.length == 3 ? IneqType.quadratic : IneqType.cubic;
        for (final rel in IneqRel.values) {
          final res = CasioIneq.solve(type, rel, c(coef));
          final l = res.layout();
          if (l == null) continue;
          expect(RegExp(r'[0-9]').hasMatch(l.header), isFalse, reason: '${coef.join(',')} ${rel.symbol}');
          final letters = RegExp(r'[A-C]').allMatches(l.header).map((m) => m.group(0)).toSet();
          expect(letters.length, l.endpoints.length, reason: '${coef.join(',')} ${rel.symbol}');
        }
      }
    });
  });

  group('independent reference vectors (mpmath)', () {
    final data = jsonDecode(File('test/casio/ineq_dist.json').readAsStringSync()) as Map<String, dynamic>;
    final cases = (data['ineq'] as List).cast<Map<String, dynamic>>();
    const rels = <String, IneqRel>{'<': IneqRel.lt, '>': IneqRel.gt, '≤': IneqRel.le, '≥': IneqRel.ge};

    for (final k in cases) {
      final coef = (k['coef'] as List).cast<num>();
      final rel = k['rel'] as String;
      test('${coef.join(',')} $rel 0', () {
        final type = coef.length == 3 ? IneqType.quadratic : IneqType.cubic;
        final res = CasioIneq.solve(type, rels[rel]!, c(coef));
        final want = k['solution'] as List;
        if (want.length == 1 && want[0] is String) {
          expect(res.lines(fmt), [want[0]]);
          return;
        }
        expect(res.parts.length, want.length);
        for (var i = 0; i < want.length; i++) {
          final w = want[i] as Map<String, dynamic>;
          final p = res.parts[i];
          void bound(CVal? got, bool closed, Map<String, dynamic>? exp) {
            if (exp == null) {
              expect(got, isNull);
              return;
            }
            expect(got, isNotNull);
            final e = double.parse(exp['v'] as String);
            expect(got!.v, closeTo(e, e.abs() * 1e-9 + 1e-12));
            expect(closed, exp['closed']);
          }

          bound(p.lo, p.loClosed, w['lo'] as Map<String, dynamic>?);
          bound(p.hi, p.hiClosed, w['hi'] as Map<String, dynamic>?);
        }
      });
    }
  });
}

/// A real value as a complex number for the formatter.
class CasioComplexHelper {
  static CComplex real(CVal v) => CComplex(v);
}
