// Variables A–F, X, Y, the independent memory M, STO and RCL (Phase 8a; manual p.35-36). Rows A21, A22, A23 of the coverage matrix.

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/engine.dart';
import 'package:omnicalc/engine/types.dart';
import 'package:omnicalc/services/feedback_service.dart';
import 'package:omnicalc/ui/calculator/calculator_controller.dart';

void main() {
  CalculatorController make() {
    final c = CalculatorController(feedback: SilentFeedbackService(), engine: CasioEngine());
    c.updateProps(
      angleMode: AngleMode.deg,
      decimalPrecision: -1,
      soundEnabled: false,
      hapticEnabled: false,
      history: const [],
    );
    return c;
  }

  void type(CalculatorController c, String s) {
    for (final ch in s.split('')) {
      c.handleInput(ch);
    }
  }

  test('STO then a variable key stores the value on the line: 3×4 STO A', () {
    final c = make();
    type(c, '3×4');
    c.toggleSto();
    expect(c.annunciators, contains('STO'));
    c.variableKey('A');
    expect(c.annunciators, isNot(contains('STO')));
    expect(c.engine.memory.vars['A']!.v, 12);
    expect(c.lastAnswer, '12');
  });

  test('STO with a result on screen stores Ans at full precision, exact form kept', () {
    final c = make();
    type(c, '1÷3');
    c.handleEvaluate();
    c.toggleSto();
    c.variableKey('B');
    expect(c.engine.memory.vars['B']!.v, closeTo(1 / 3, 1e-15));
    expect(c.engine.memory.vars['B']!.ex, isNotNull);
    expect(c.lastAnswer, '1⌟3'); // the display is left alone
  });

  test('STO on an empty line stores Ans', () {
    final c = make();
    type(c, '7');
    c.handleEvaluate();
    c.handleClear();
    c.toggleSto();
    c.variableKey('C');
    expect(c.engine.memory.vars['C']!.v, 7);
  });

  test('a stored variable is used in the next calculation: 5 STO A, then A×2+1', () {
    final c = make();
    type(c, '5');
    c.toggleSto();
    c.variableKey('A');
    c.handleClear();
    c.variableKey('A');
    type(c, '×2+1');
    c.handleEvaluate();
    expect(c.lastAnswer, '11');
  });

  test('RCL puts the variable value into the expression', () {
    final c = make();
    type(c, '9');
    c.toggleSto();
    c.variableKey('D');
    c.handleClear();
    type(c, '2+');
    c.toggleRcl();
    expect(c.annunciators, contains('RCL'));
    c.variableKey('D');
    expect(c.annunciators, isNot(contains('RCL')));
    c.handleEvaluate();
    expect(c.lastAnswer, '11');
  });

  test('RCL of an exact value keeps it exact: 1/3 recalled and tripled is 1', () {
    final c = make();
    type(c, '1÷3');
    c.handleEvaluate();
    c.toggleSto();
    c.variableKey('E');
    c.handleClear();
    c.toggleRcl();
    c.variableKey('E');
    type(c, '×3');
    c.handleEvaluate();
    expect(c.lastAnswer, '1');
  });

  test('STO and RCL let go when another prefix is pressed', () {
    final c = make();
    c.toggleSto();
    c.toggleRcl();
    expect(c.annunciators, containsAll(['RCL']));
    expect(c.annunciators, isNot(contains('STO')));
    c.toggleShift();
    expect(c.annunciators, isNot(contains('RCL')));
  });

  test('STO into something that is not a variable does nothing', () {
    final c = make();
    type(c, '4');
    c.toggleSto();
    c.variableKey('Q');
    expect(c.engine.memory.vars.containsKey('Q'), isFalse);
    expect(c.annunciators, isNot(contains('STO')));
  });

  test('M+ and M− change the Casio M; the M annunciator follows it', () {
    final c = make();
    type(c, '2+3');
    c.handleMemory(MemoryAction.mPlus);
    expect(c.engine.memory.vars['M']!.v, 5);
    expect(c.annunciators, contains('M'));
    c.handleMemory(MemoryAction.mMinus);
    expect(c.engine.memory.vars['M']!.v, 0);
    expect(c.annunciators, isNot(contains('M')));
  });

  test('the M key and the memory ribbon share one store: MS then M in an expression', () {
    final c = make();
    type(c, '8');
    c.handleMemory(MemoryAction.ms);
    c.handleClear();
    c.variableKey('M');
    type(c, '+1');
    c.handleEvaluate();
    expect(c.lastAnswer, '9');
  });

  test('CLR ▸ Memory clears the variables and M', () {
    final c = make();
    type(c, '6');
    c.toggleSto();
    c.variableKey('F');
    c.clearMemory();
    expect(c.engine.memory.vars['F']!.v, 0);
    expect(c.memory, 0);
  });

  test('the persist hook fires after STO and after M+', () {
    final c = make();
    var n = 0;
    c.onPersist = () => n++;
    type(c, '4');
    c.handleEvaluate();
    c.toggleSto();
    c.variableKey('A');
    c.handleMemory(MemoryAction.mPlus);
    expect(n, greaterThanOrEqualTo(2));
  });
}
