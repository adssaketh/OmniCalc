import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/config.dart';
import 'package:omnicalc/engine/casio/cval.dart';
import 'package:omnicalc/engine/casio/matrix.dart';

const CasioConfig cfg = CasioConfig();

CMatrix mat(List<List<num>> rows) => CMatrix(rows.length, rows.first.length, [
      for (final r in rows)
        for (final v in r) v == v.roundToDouble() ? CVal.int(v.toInt()) : CVal.dec(v.toDouble()),
    ]);

CVector vec(List<num> v) => CVector([for (final x in v) x == x.roundToDouble() ? CVal.int(x.toInt()) : CVal.dec(x.toDouble())]);

CasioMatVec newCalc(MatVecStore s) => CasioMatVec(s, CasioMemory());

/// Cell texts of an exact result as `n` or `n/d` (null for a cell that is not an exact rational).
List<String?> exactCells(MatVal v) {
  final cells = switch (v) {
    CMatrix() => v.cells,
    CVector() => v.cells,
    MatScalar() => <CVal>[v.value],
  };
  return [for (final c in cells) ratText(c)];
}

MatVal run(CasioMatVec c, String expr, {bool vector = false}) {
  final o = c.evaluate(expr, cfg, vectorMode: vector);
  return o.matrix ?? o.vector ?? MatScalar(o.scalar!);
}

void main() {
  late MatVecStore store;
  late CasioMatVec calc;
  setUp(() {
    store = MatVecStore()
      ..mats['MatA'] = mat([[2, 1], [1, 1]])
      ..mats['MatB'] = mat([[2, 1], [1, 2]])
      ..mats['MatC'] = mat([[1, 0, 1], [0, 1, 1]])
      ..vecs['VctA'] = vec([1, 2])
      ..vecs['VctB'] = vec([3, 4])
      ..vecs['VctC'] = vec([2, -1, 2]);
    calc = newCalc(store);
  });

  group('MATRIX manual examples (p.73-76)', () {
    test('example 1: MatA×MatB and MatA+MatB', () {
      expect(exactCells(run(calc, 'MatA×MatB')), ['5', '4', '3', '3']);
      expect(exactCells(run(calc, 'MatA+MatB')), ['4', '2', '2', '3']);
    });
    test('MatAns is the last matrix and works in the next calculation', () {
      run(calc, 'MatA×MatB');
      expect(exactCells(run(calc, 'MatAns+MatA')), ['7', '5', '4', '4']);
    });
    test('example 3: 3×MatA', () => expect(exactCells(run(calc, '3MatA')), ['6', '3', '3', '3']));
    test('example 4: det(MatA) = 1', () => expect(exactCells(run(calc, 'det(MatA)')), ['1']));
    test('example 5: Trn(MatC)', () {
      final t = run(calc, 'Trn(MatC)') as CMatrix;
      expect((t.rows, t.cols), (3, 2));
      expect(exactCells(t), ['1', '0', '0', '1', '1', '1']);
    });
    test('example 6: MatA⁻¹', () => expect(exactCells(run(calc, 'MatA⁻¹')), ['1', '-1', '-1', '2']));
    test('example 7: Abs(MatB)', () => expect(exactCells(run(calc, 'Abs(MatB)')), ['2', '1', '1', '2']));
    test('example 8: MatA² and MatA³', () {
      expect(exactCells(run(calc, 'MatA²')), ['5', '3', '3', '2']);
      expect(exactCells(run(calc, 'MatA³')), ['13', '8', '8', '5']);
    });
    test('example 9 and 10: Ref and Rref of MatA', () {
      expect(exactCells(run(calc, 'Ref(MatA)')), ['1', '1/2', '0', '1']);
      expect(exactCells(run(calc, 'Rref(MatA)')), ['1', '0', '0', '1']);
    });
    test('inverse of a matrix with fractions stays exact', () {
      store.mats['MatC'] = mat([[2, 0, 1], [1, 1, 0], [0, 1, 3]]);
      final inv = run(calc, 'MatC⁻¹');
      expect(exactCells(inv), ['3/7', '1/7', '-1/7', '-3/7', '6/7', '1/7', '1/7', '-2/7', '2/7']);
    });
  });

  group('MATRIX errors', () {
    CasioErrorKind kindOf(void Function() f) {
      try {
        f();
      } on CasioError catch (e) {
        return e.kind;
      }
      fail('no error');
    }

    test('incompatible product is a Dimension ERROR', () {
      expect(kindOf(() => run(calc, 'MatA×MatC×MatA')), CasioErrorKind.dimension);
    });
    test('sum of different sizes is a Dimension ERROR', () {
      expect(kindOf(() => run(calc, 'MatA+MatC')), CasioErrorKind.dimension);
    });
    test('det of a non-square matrix is a Dimension ERROR', () {
      expect(kindOf(() => run(calc, 'det(MatC)')), CasioErrorKind.dimension);
    });
    test('a matrix without dimension is a Dimension ERROR', () {
      store.mats['MatB'] = null;
      expect(kindOf(() => run(calc, 'MatB+MatA')), CasioErrorKind.dimension);
      expect(kindOf(() => run(calc, 'MatAns+MatA')), CasioErrorKind.dimension);
    });
    test('singular inverse is a Math ERROR', () {
      store.mats['MatA'] = mat([[1, 2], [2, 4]]);
      expect(kindOf(() => run(calc, 'MatA⁻¹')), CasioErrorKind.math);
    });
    test('vectors are not available in MATRIX mode and the reverse', () {
      expect(kindOf(() => run(calc, 'VctA')), CasioErrorKind.syntax);
      expect(kindOf(() => run(calc, 'MatA', vector: true)), CasioErrorKind.syntax);
    });
    test('a matrix power other than 2, 3, -1 is a Syntax ERROR', () {
      expect(kindOf(() => run(calc, 'MatA^4')), CasioErrorKind.syntax);
    });
    test('Dim makes a zero matrix; sizes beyond 3×3 are refused', () {
      store.dimMatrix('MatB', 3, 2);
      final b = store.mats['MatB']!;
      expect((b.rows, b.cols), (3, 2));
      expect(b.cells.every((c) => c.v == 0), isTrue);
      expect(() => store.dimMatrix('MatB', 4, 2), throwsA(isA<CasioError>()));
      expect(() => store.dimVector('VctA', 4), throwsA(isA<CasioError>()));
    });
    test('STO copies MatAns to MatC', () {
      run(calc, 'MatA×MatB');
      store.copyMatrix(store.matAns!, 'MatC');
      expect(exactCells(store.mats['MatC']!), ['5', '4', '3', '3']);
    });
  });

  group('VECTOR manual examples (p.79-82)', () {
    test('example 1: VctA+VctB', () => expect(exactCells(run(calc, 'VctA+VctB', vector: true)), ['4', '6']));
    test('example 3: 3×VctA, then 3×VctA−VctB via VctAns', () {
      expect(exactCells(run(calc, '3VctA', vector: true)), ['3', '6']);
      expect(exactCells(run(calc, 'VctAns−VctB', vector: true)), ['0', '2']);
    });
    test('example 4: VctA Dot VctB = 11', () => expect(exactCells(run(calc, 'VctA Dot VctB', vector: true)), ['11']));
    test('example 5: VctA×VctB (2-dimensional vectors give (0, 0, z))', () {
      expect(exactCells(run(calc, 'VctA×VctB', vector: true)), ['0', '0', '-2']);
    });
    test('example 6: Abs(VctC) = 3', () => expect(exactCells(run(calc, 'Abs(VctC)', vector: true)), ['3']));
    test('Abs(VctA) is the surd √5', () {
      final v = run(calc, 'Abs(VctA)', vector: true) as MatScalar;
      expect(v.value.v, closeTo(2.2360679775, 1e-9));
      expect(matrixCellText(v.value, cfg), contains('√'));
    });
    test('example 7: the angle between VctA and VctB is 10.305° (Fix 3)', () {
      final fix3 = const CasioConfig(numberFormat: CasioNumberFormat.fix, digits: 3);
      final o = calc.evaluate('acos(VctA Dot VctB÷(Abs(VctA)Abs(VctB)))', fix3, vectorMode: true);
      expect(CasioMatVec.cellTexts(MatScalar(o.scalar!), fix3).first, '10.305');
    });
    test('3-dimensional cross product', () {
      store.vecs['VctA'] = vec([1, 0, -1]);
      expect(exactCells(run(calc, 'VctA×VctC', vector: true)), ['-1', '-4', '-1']);
    });
    test('vectors of different dimension: Dimension ERROR', () {
      expect(() => run(calc, 'VctA+VctC', vector: true), throwsA(isA<CasioError>()));
      expect(() => run(calc, 'VctA Dot VctC', vector: true), throwsA(isA<CasioError>()));
    });
    test('Dim for a vector', () {
      store.dimVector('VctB', 3);
      expect(store.vecs['VctB']!.dim, 3);
    });
  });

  group('independent references (exact fractions)', () {
    final json = jsonDecode(File('test/casio/stat_matrix_vectors.json').readAsStringSync()) as Map<String, dynamic>;
    CMatrix m(dynamic rows) => mat([
          for (final r in rows as List<dynamic>) [for (final v in r as List<dynamic>) v as num],
        ]);
    List<String> cellsOf(dynamic result) => [
          for (final r in result as List<dynamic>)
            for (final v in r as List<dynamic>) v as String,
        ];
    var i = 0;
    for (final e in json['matrix'] as List<dynamic>) {
      final c = e as Map<String, dynamic>;
      final id = i++;
      test('matrix #$id ${c['op']}', () {
        final s = MatVecStore()..mats['MatA'] = m(c['a']);
        if (c['b'] != null) s.mats['MatB'] = m(c['b']);
        final k = newCalc(s);
        final expr = switch (c['op'] as String) {
          'trn' => 'Trn(MatA)',
          'ref' => 'Ref(MatA)',
          'rref' => 'Rref(MatA)',
          'det' => 'det(MatA)',
          'inv' => 'MatA⁻¹',
          'sq' => 'MatA²',
          'cube' => 'MatA³',
          'mul' => 'MatA×MatB',
          'add' => 'MatA+MatB',
          _ => 'MatA−MatB',
        };
        final got = exactCells(run(k, expr));
        final want = c['op'] == 'det' ? <String>[c['result'] as String] : cellsOf(c['result']);
        expect(got, want);
      });
    }
    var j = 0;
    for (final e in json['vector'] as List<dynamic>) {
      final c = e as Map<String, dynamic>;
      final id = j++;
      test('vector #$id ${c['op']}', () {
        List<num> v(dynamic x) => [for (final n in x as List<dynamic>) n as num];
        final s = MatVecStore()..vecs['VctA'] = vec(v(c['a']));
        if (c['b'] != null) s.vecs['VctB'] = vec(v(c['b']));
        final k = newCalc(s);
        final op = c['op'] as String;
        final expr = switch (op) {
          'abs2' => 'Abs(VctA)²',
          'dot' => 'VctA Dot VctB',
          'cross' => 'VctA×VctB',
          'add' => 'VctA+VctB',
          _ => 'VctA−VctB',
        };
        final got = exactCells(run(k, expr, vector: true));
        final want = c['result'] is List ? [for (final x in c['result'] as List<dynamic>) x as String] : <String>[c['result'] as String];
        expect(got, want);
      });
    }
  });
}
