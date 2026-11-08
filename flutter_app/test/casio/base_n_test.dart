import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/base_n.dart';
import 'package:omnicalc/engine/casio/cval.dart';

void main() {
  String run(String s, BaseMode m, [BaseMode? show]) {
    final o = CasioBaseN().evaluate(s, m);
    return o.textIn(show ?? m);
  }

  test('manual p.68: 15 x 37 shown in DEC/HEX/BIN/OCT', () {
    final o = CasioBaseN().evaluate('15×37', BaseMode.dec);
    expect(o.textIn(BaseMode.dec), '555');
    expect(o.textIn(BaseMode.hex), '0000022B');
    expect(o.textIn(BaseMode.bin), '0000001000101011');
    expect(o.textIn(BaseMode.oct), '00000001053');
  });

  test('manual p.66-67: d10+h10+b10+o10 = 36', () {
    expect(run('d10+h10+b10+o10', BaseMode.dec), '36');
    expect(run('d10+h10+b10+o10', BaseMode.hex), '00000024');
  });

  test('manual p.69-70 logical examples (BIN)', () {
    expect(run('1010and1100', BaseMode.bin), '0000000000001000');
    expect(run('1011or11010', BaseMode.bin), '0000000000011011');
    expect(run('1010xor1100', BaseMode.bin), '0000000000000110');
    expect(run('1111xnor101', BaseMode.bin), '1111111111110101');
    expect(run('Not(1010)', BaseMode.bin), '1111111111110101');
    expect(run('Neg(101101)', BaseMode.bin), '1111111111010011');
  });

  test('negative numbers are two\'s complement outside DEC', () {
    expect(run('-1', BaseMode.hex), 'FFFFFFFF');
    expect(run('-1', BaseMode.dec), '-1');
    expect(run('0-1', BaseMode.bin), '1111111111111111');
    expect(run('FFFFFFFF', BaseMode.hex, BaseMode.dec), '-1');
  });

  test('ranges and errors', () {
    expect(() => run('2147483647+1', BaseMode.dec), throwsA(kMathError));
    expect(() => run('7FFFFFFF+1', BaseMode.hex), throwsA(kMathError));
    expect(() => run('1/0', BaseMode.dec), throwsA(kMathError));
    expect(() => run('12', BaseMode.bin), throwsA(isA<CasioError>()));
    expect(run('-2147483648', BaseMode.dec), '-2147483648');
  });

  test('division cuts off the fraction; Ans', () {
    expect(run('7÷2', BaseMode.dec), '3');
    final e = CasioBaseN();
    e.evaluate('6×7', BaseMode.dec);
    expect(e.evaluate('Ans+1', BaseMode.dec).text, '43');
  });

  test('independent vectors: and/or priority', () {
    // and binds tighter than or: 1 or 2 and 0 = 1 or 0 = 1
    expect(run('1or2and0', BaseMode.dec), '1');
    expect(run('5+3and6', BaseMode.dec), '0'); // (5+3) and 6 = 8 and 6 = 0
  });
}
