import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/base_n.dart';
import 'package:omnicalc/engine/types.dart';
import 'package:omnicalc/services/feedback_service.dart';
import 'package:omnicalc/ui/calculator/calculator_controller.dart';

void main() {
  CalculatorController make() {
    final c = CalculatorController(feedback: SilentFeedbackService(), clipboard: (text) async {});
    c.updateProps(angleMode: AngleMode.deg, decimalPrecision: -1, soundEnabled: true, hapticEnabled: true, history: const []);
    return c;
  }

  void type(CalculatorController c, String s) {
    for (final ch in s.split('')) {
      c.handleInput(ch);
    }
  }

  test('CMPLX mode: annunciator, (2+6i)÷2i = 3−i, polar command', () {
    final c = make();
    c.setMode(CasioMode.cmplx);
    expect(c.annunciators, contains('CMPLX'));
    type(c, '(2+6i)÷(2i)');
    c.handleEvaluate();
    expect(c.lastAnswer, '3-i');
    c.handleClear();
    type(c, '2∠45');
    c.handleEvaluate();
    expect(c.lastAnswer, '√2+√2i');
  });

  test('BASE-N mode: 15×37 and base conversion, logic', () {
    final c = make();
    c.setMode(CasioMode.baseN);
    expect(c.annunciators, containsAll(['BASE', 'DEC']));
    type(c, '15×37');
    c.handleEvaluate();
    expect(c.expression, '555');
    c.setBaseMode(BaseMode.hex);
    expect(c.expression, '0000022B');
    c.setBaseMode(BaseMode.bin);
    expect(c.expression, '0000001000101011');
    c.setBaseMode(BaseMode.oct);
    expect(c.expression, '00000001053');
    c.handleClear();
    c.setBaseMode(BaseMode.bin);
    type(c, '1010and1100');
    c.handleEvaluate();
    expect(c.expression, '0000000000001000');
  });

  test('errors in a mode show the calculator message; COMP is restored', () {
    final c = make();
    c.setMode(CasioMode.baseN);
    type(c, '1÷0');
    c.handleEvaluate();
    expect(c.expression, 'Math ERROR');
    c.setMode(CasioMode.comp);
    expect(c.annunciators, isNot(contains('BASE')));
    type(c, '2+3');
    c.handleEvaluate();
    expect(c.expression, '5');
  });
}
