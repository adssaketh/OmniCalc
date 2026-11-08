// The calculator controller with the Casio engine: results, S⇔D, error state, Ans continuation (Phase 7b).

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/editor/nodes.dart';
import 'package:omnicalc/engine/casio/config.dart';
import 'package:omnicalc/engine/casio/engine.dart';
import 'package:omnicalc/engine/types.dart';
import 'package:omnicalc/services/feedback_service.dart';
import 'package:omnicalc/ui/calculator/calculator_controller.dart';

void main() {
  CalculatorController make([CasioConfig? casio]) {
    final c = CalculatorController(feedback: SilentFeedbackService(), engine: CasioEngine());
    c.updateProps(
      angleMode: AngleMode.deg,
      decimalPrecision: -1,
      soundEnabled: false,
      hapticEnabled: false,
      history: const [],
      casio: casio,
    );
    return c;
  }

  void type(CalculatorController c, String s) {
    for (final ch in s.split('')) {
      c.handleInput(ch);
    }
  }

  test('a fraction result is shown as 3⌟4 and reused as an expression', () {
    final c = make();
    type(c, '3÷4');
    c.handleEvaluate();
    expect(c.lastAnswer, '3⌟4');
    // Phase 8c (C01): in MathO the answer line draws the fraction stacked; the text form is what lastAnswer keeps
    expect(c.resultDoc.root.single, isA<FracNode>());
    expect(c.expression, '(3÷4)');
    expect(c.isErrorResult, isFalse);
    expect(c.canToggleForm, isTrue);
  });

  test('S⇔D cycles fraction → recurring → decimal and back', () {
    final c = make();
    type(c, '1÷7');
    c.handleEvaluate();
    expect(c.lastAnswer, '1⌟7');
    c.toggleForm();
    expect(c.lastAnswer, '0.1̅4̅2̅8̅5̅7̅');
    c.toggleForm();
    expect(c.lastAnswer, '0.1428571429');
    c.toggleForm();
    expect(c.lastAnswer, '1⌟7');
  });

  test('SHIFT S⇔D switches improper and mixed fractions', () {
    final c = make();
    type(c, '7÷6');
    c.handleEvaluate();
    c.toggleMixedFraction();
    expect(c.lastAnswer, '1⌟1⌟6');
    expect(c.expression, '(1+1÷6)');
  });

  test('an error is the unit\'s message and is flagged', () {
    final c = make();
    type(c, '1÷0');
    c.handleEvaluate();
    expect(c.expression, 'Math ERROR');
    expect(c.isErrorResult, isTrue);
    expect(c.canToggleForm, isFalse);
    c.handleClear();
    type(c, '2+');
    c.handleEvaluate();
    expect(c.expression, 'Syntax ERROR');
    expect(c.isErrorResult, isTrue);
  });

  test('an operator after = continues from Ans at full precision', () {
    final c = make(const CasioConfig(decimalFirst: true));
    type(c, '1÷3');
    c.handleEvaluate();
    expect(c.expression, '0.3333333333');
    c.handleInput('×');
    c.handleInput('3');
    c.handleEvaluate();
    expect(c.lastAnswer, '1');
  });

  test('÷R shows quotient and remainder, only the quotient continues', () {
    final c = make();
    type(c, '17÷R5');
    c.handleEvaluate();
    expect(c.lastAnswer, '3 R 2');
    expect(c.expression, '3');
    expect(c.canToggleForm, isFalse);
    expect(c.canFactor, isFalse);
  });

  test('Pol gives a second output', () {
    final c = make();
    type(c, 'Pol(1,1)');
    c.handleEvaluate();
    expect(c.lastAnswer, '√2');
    expect(c.resultExtra, {'θ': '45'});
  });

  test('FACT factors the last result', () {
    final c = make();
    type(c, '1014');
    c.handleEvaluate();
    expect(c.canFactor, isTrue);
    c.factorResult();
    expect(c.lastAnswer, '2×3×13²');
  });

  test('live preview does not touch Ans', () {
    final c = make();
    type(c, '2+3');
    c.handleEvaluate();
    final ans = c.engine.memory.ans.v;
    c.handleInput('×');
    c.handleInput('4');
    expect(c.livePreview, '20');
    expect(c.engine.memory.ans.v, ans);
  });

  test('the legacy style evaluates with the old engine', () {
    final c = make(const CasioConfig(useCasio: false));
    type(c, '3÷4');
    c.handleEvaluate();
    expect(c.lastAnswer, '0.75');
    expect(c.canToggleForm, isFalse);
  });

  test('integral and derivative still calculate (legacy until Phase 7c)', () {
    final c = make();
    c.loadExternal('integrate(x^2,0,1)');
    c.handleEvaluate();
    expect(double.parse(c.lastAnswer), closeTo(1 / 3, 1e-6));
  });

  test('ENG moves the exponent by multiples of 3 (manual p.24-25)', () {
    final c = make();
    type(c, '1234');
    c.handleEvaluate();
    c.engShift(right: true);
    expect(c.lastAnswer, '1.234×10³');
    c.engShift(right: false);
    expect(c.lastAnswer, '1234×10⁰');
    final d = make();
    type(d, '123');
    d.handleEvaluate();
    d.engShift(right: true);
    expect(d.lastAnswer, '0.123×10³');
    d.engShift(right: true);
    expect(d.lastAnswer, '0.000123×10⁶');
  });
}
