import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/complex.dart';
import 'package:omnicalc/engine/casio/config.dart';
import 'package:omnicalc/engine/casio/cval.dart';

void main() {
  late CasioComplexEngine e;
  setUp(() => e = CasioComplexEngine(CasioMemory()));
  const cfg = CasioConfig();
  String r(String s, [CasioConfig c = cfg]) => e.evaluate(s, c).text;

  test('manual CMPLX examples', () {
    expect(r('(2+6i)÷(2i)'), '3-i');
    expect(r('2∠45'), '√2+√2i');
    expect(r('√2+√2i▸r∠θ'), '2∠45');
    expect(r('(1-i)⁻¹'), '1⌟2+1⌟2i');
    expect(r('(1+i)²+(1-i)²'), '0');
    expect(r('Conjg(2+3i)'), '2-3i');
    expect(r('Abs(1+i)'), '√2');
    expect(r('arg(1+i)'), '45');
  });

  test('independent vectors', () {
    expect(r('i×i'), '-1');
    expect(r('(3+4i)×(3-4i)'), '25');
    expect(r('Abs(3+4i)'), '5');
    expect(r('(1+2i)+(3-5i)'), '4-3i');
    expect(r('2i▸r∠θ'), '2∠90');
    expect(r('3+4i▸r∠θ'), startsWith('5∠53.13'));
  });

  test('SETUP polar format and ▸a+bi override', () {
    const polar = CasioConfig(complexFormat: CasioComplexFormat.polar);
    expect(r('1+i', polar), '√2∠45');
    expect(r('1+i▸a+bi', polar), '1+i');
  });

  test('linear display lines and errors', () {
    expect(e.evaluate('2+3i', cfg).shown.lines, ['2', '3i']);
    expect(() => r('1÷0'), throwsA(kMathError));
    expect(() => r('1∠'), throwsA(isA<CasioError>()));
  });
}
