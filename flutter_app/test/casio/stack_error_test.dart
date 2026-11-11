// The phone build has no numeric or command stack limit (the calculator's Stack ERROR, manual p.93, is gone); row X02.

import 'package:flutter_test/flutter_test.dart';
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
  test('a long flat sum is fine', () {
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

  test('deep right-hand nesting no longer gives a Stack ERROR', () {
    final e = CasioEngine();
    expect(e.evaluate(nested(14)).text, '105');
    expect(e.evaluate(nested(40)).text, '820');
  });
}
