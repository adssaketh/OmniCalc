import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/calc_error.dart';
import 'package:omnicalc/engine/chemistry/calc_functions.dart';
import 'package:omnicalc/engine/evaluator.dart';

double ev(String s) => MathEvaluator.evaluate(s);

void main() {
  test('molar, amass, atomic give numbers', () {
    expect(ev('molar("H2O")'), closeTo(18.015, 1e-9));
    expect(ev('amass("Fe")'), 55.84);
    expect(ev('atomic("Fe")'), 26);
    expect(ev("molar('NaCl')"), closeTo(22.9897693 + 35.45, 1e-9));
    expect(ev('molar(“H₂O”)'), closeTo(18.015, 1e-9));
  });

  test('they combine with arithmetic', () {
    expect(ev('molar("H2O")*2'), closeTo(36.03, 1e-9));
    expect(ev('10/molar("NaCl")'), closeTo(10 / (22.9897693 + 35.45), 1e-9));
    expect(ev('atomic("Fe")+atomic("C")'), 32);
    expect(ev('2*amass("H")+amass("O")'), closeTo(18.015, 1e-9));
  });

  test('formulas that look like nCr / mod / constants are not rewritten', () {
    expect(ev('molar("MnCr")'), closeTo(54.93804 + 51.996, 1e-9));
    expect(ev('molar("Cm")'), closeTo(247.07035, 1e-9));
    expect(ev('molar("Ca")'), closeTo(40.08, 1e-9));
    expect(ev('amass("He")'), closeTo(4.0026, 1e-9));
  });

  test('names, lowercase symbols and numbers work for amass / atomic', () {
    expect(ev('atomic("iron")'), 26);
    expect(ev('amass("fe")'), 55.84);
    expect(ev('amass(26)'), 55.84);
    expect(ev('atomic(26)'), 26);
  });

  test('atomicsym is text: only as the whole expression', () {
    expect(ChemCalcFunctions.textResult('atomicsym(26)'), 'Fe');
    expect(ChemCalcFunctions.textResult(' atomicsym( 1 ) '), 'H');
    expect(ChemCalcFunctions.textResult('atomicsym(26)+1'), isNull);
    expect(ChemCalcFunctions.textResult('2+3'), isNull);
    expect(() => ChemCalcFunctions.textResult('atomicsym(0)'), throwsA(isA<CalcError>()));
    expect(() => ev('atomicsym(26)+1'), throwsA(isA<CalcError>()));
  });

  test('errors are CalcErrors with a usable message', () {
    expect(() => ev('molar("Xx")'), throwsA(isA<CalcError>()));
    expect(() => ev('atomic("Unobtainium")'), throwsA(isA<CalcError>().having((e) => e.message, 'm', contains('Unknown element'))));
    expect(() => ev('molar(5)'), throwsA(isA<CalcError>().having((e) => e.message, 'm', contains('in quotes'))));
  });

  test('ordinary expressions are untouched', () {
    expect(ChemCalcFunctions.resolve('2+3*4'), '2+3*4');
    expect(ev('2+3*4'), 14);
    expect(ev('10 nCr 3'), 120);
    expect(ev('17 mod 5'), 2);
  });
}
