// VERIF (manual p.85-87): the manual's examples and every Syntax ERROR form of the list on p.86.

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/cval.dart';
import 'package:omnicalc/engine/casio/engine.dart';
import 'package:omnicalc/engine/casio/verif.dart';

void main() {
  late CasioEngine e;
  setUp(() => e = CasioEngine());
  String v(String s) => CasioVerif.verify(e, s).text;
  void syntax(String s) => expect(() => CasioVerif.verify(e, s), throwsA(predicate((x) => x is CasioError && x.kind == CasioErrorKind.syntax)), reason: s);

  group('manual examples', () {
    test('4√9 = 12 is TRUE', () => expect(v('4×√(9)=12'), 'TRUE'));
    test('log2 < log3 < log4 is TRUE', () => expect(v('log(2)<log(3)<log(4)'), 'TRUE'));
    test('0 < (8/9)² − 8/9 is FALSE', () => expect(v('0<(8÷9)^2−8÷9'), 'FALSE'));
    test('5² = 25 = √625 is TRUE', () => expect(v('5^2=25=√(625)'), 'TRUE'));
    test('the single relations of the list', () {
      expect(v('4=√(16)'), 'TRUE');
      expect(v('4≠3'), 'TRUE');
      expect(v('π>3'), 'TRUE');
      expect(v('1+2≤5'), 'TRUE');
      expect(v('(3×6)<(2+6)×2'), 'FALSE');
    });
    test('the chained relations of the list', () {
      expect(v('1≤1<1+1'), 'TRUE');
      expect(v('3<π<4'), 'TRUE');
      expect(v('2^2=2+2=4<6'), 'TRUE');
      // the manual lists 2+3=5≠2+5=8 as a form that can be entered; its last link is 7=8, so the answer is FALSE
      expect(v('2+3=5≠2+5=8'), 'FALSE');
      expect(v('2+3=5≠2+6=8'), 'TRUE');
      expect(v('2+3=5=2+5'), 'FALSE');
    });
  });

  group('Ans and variables', () {
    test('TRUE stores 1 in Ans and FALSE stores 0', () {
      v('1=1');
      expect(e.memory.ans.v, 1);
      v('1=2');
      expect(e.memory.ans.v, 0);
    });
    test('a variable is read as its value', () {
      e.memory.vars['A'] = CVal.int(5);
      expect(v('A=5'), 'TRUE');
      expect(v('A>5'), 'FALSE');
    });
    test('exact values compare exactly', () {
      expect(v('√(2)×√(3)=√(6)'), 'TRUE');
      expect(v('1÷3+1÷2=5÷6'), 'TRUE');
    });
  });

  group('Syntax ERROR forms (p.86)', () {
    test('nothing on the left or the right', () {
      syntax('=5√(7)');
      syntax('5=');
    });
    test('a relation inside a fraction, a function or parentheses', () {
      syntax('((1=1)÷(2))');
      syntax('cos(8≤9)');
      syntax('8<(9<10)');
    });
    test('operators pointing different ways', () => syntax('5≤6≥4'));
    test('≠ combined with an ordering relation', () => syntax('4<6≠8'));
    test('consecutive relational operators', () => syntax('5≥>9'));
    test('no relational operator at all', () => syntax('1+1'));
    test('÷R, Pol and Rec are not allowed', () {
      syntax('7÷R2=3');
      syntax('Pol(1,1)=1');
      syntax('Rec(1,1)=1');
    });
  });
}
