// Stack ERROR (manual p.93). The stack sizes are not in the guide (see lib/engine/casio/stack_check.dart); row X02.

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/cval.dart';
import 'package:omnicalc/engine/casio/engine.dart';

String nested(int depth) {
  // 1+(2+(3+(...))) : every level keeps one value waiting
  final b = StringBuffer();
  for (var i = 1; i <= depth; i++) {
    b.write('$i+(');
  }
  b.write('0');
  b.write(')' * depth);
  return b.toString();
}

void main() {
  test('a long flat sum is fine: the left operand never waits on the stack', () {
    final e = CasioEngine();
    final line = List<String>.generate(60, (i) => '${i + 1}').join('+');
    expect(e.evaluate(line).text, '1830');
  });

  test('a long product is fine as well', () {
    final e = CasioEngine();
    expect(e.evaluate(List<String>.filled(30, '1').join('×')).text, '1');
  });

  test('moderate nesting is fine (6 levels)', () {
    final e = CasioEngine();
    expect(e.evaluate(nested(6)).text, '21');
  });

  test('very deep right-hand nesting is a Stack ERROR', () {
    final e = CasioEngine();
    expect(
      () => e.evaluate(nested(14)),
      throwsA(isA<CasioError>().having((x) => x.message, 'message', 'Stack ERROR')),
    );
  });

  test('the message is the unit\'s own words', () {
    expect(CasioErrorKind.stack.message, 'Stack ERROR');
  });
}
