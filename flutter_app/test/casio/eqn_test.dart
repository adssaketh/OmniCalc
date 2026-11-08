import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/complex.dart';
import 'package:omnicalc/engine/casio/config.dart';
import 'package:omnicalc/engine/casio/cval.dart';
import 'package:omnicalc/engine/casio/eqn.dart';

void main() {
  final eng = CasioComplexEngine(CasioMemory());
  const cfg = CasioConfig();
  List<CVal> c(List<num> xs) => [for (final x in xs) x is int ? CVal.int(x) : CVal.dec(x.toDouble())];
  String t(EqnLine l) => eng.show(l.value, cfg).text;

  test('manual Example 1: simultaneous 2 unknowns', () {
    final r = CasioEqn.solve(EqnType.simul2, c([1, 2, 3, 2, 3, 4]));
    expect(r.map((l) => '${l.label}${t(l)}'), ['X=-1', 'Y=2']);
  });

  test('manual Example 2: simultaneous 3 unknowns', () {
    final r = CasioEqn.solve(EqnType.simul3, c([1, -1, 1, 2, 1, 1, -1, 0, -1, 1, 1, 4]));
    expect(r.map((l) => '${l.label}${t(l)}'), ['X=1', 'Y=2', 'Z=3']);
  });

  test('simultaneous: fractions, no solution, infinite', () {
    final r = CasioEqn.solve(EqnType.simul2, c([2, 0, 1, 0, 3, 1]));
    expect(t(r[0]), '1⌟2');
    expect(() => CasioEqn.solve(EqnType.simul2, c([1, 1, 1, 1, 1, 2])), throwsA(isA<EqnMessage>()));
    expect(() => CasioEqn.solve(EqnType.simul2, c([1, 1, 1, 2, 2, 2])), throwsA(isA<EqnMessage>()));
  });

  test('manual Example 3: 2x²-3x-6=0 with vertex', () {
    final r = CasioEqn.solve(EqnType.quadratic, c([2, -3, -6]));
    expect(r.map((l) => '${l.label}${t(l)}'), [
      'X1=(3+√57)÷4',
      'X2=(3-√57)÷4',
      'X-Value Minimum=3⌟4',
      'Y-Value Minimum=-57⌟8',
    ].map((s) => s).toList());
  }, skip: false);

  test('quadratic: maximum, complex roots, a=0', () {
    final r = CasioEqn.solve(EqnType.quadratic, c([-1, 0, 4]));
    expect(r[0].label, 'X1=');
    expect(t(r[0]), '-2');
    expect(t(r[1]), '2');
    expect(r[2].label, 'X-Value Maximum=');
    final z = CasioEqn.solve(EqnType.quadratic, c([1, 0, 1]));
    expect(t(z[0]), 'i');
    expect(t(z[1]), '-i');
    expect(() => CasioEqn.solve(EqnType.quadratic, c([0, 1, 1])), throwsA(kMathError));
  });

  test('manual Example 5: cubic x³-2x²-x+2=0 -> -1, 2, 1', () {
    final r = CasioEqn.solve(EqnType.cubic, c([1, -2, -1, 2]));
    expect(r.map((l) => t(l)), ['-1', '2', '1']);
  });

  test('cubic with one real root and a complex pair; irrational real root', () {
    final r = CasioEqn.solve(EqnType.cubic, c([1, 0, 0, -1]));
    expect(t(r[0]), '1');
    expect(r[1].value.im.v, closeTo(0.8660254038, 1e-9));
    final q = CasioEqn.solve(EqnType.cubic, c([1, 0, -2, 0]));
    expect(q.length, 3);
  });

  test('manual Example 4: x²-2√2x+2=0 gives X=√2', () {
    final b = eng.evaluateReal('-2√2', cfg);
    final r = CasioEqn.solve(EqnType.quadratic, [CVal.int(1), b, CVal.int(2)]);
    expect('${r[0].label}${t(r[0])}', 'X=√2');
  });
}
