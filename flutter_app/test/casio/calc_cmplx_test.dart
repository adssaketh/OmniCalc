// CALC in CMPLX mode (manual p.47-48, example 2): store A+Bi, substitute values, see the result in polar form. Row H11.

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/complex.dart';
import 'package:omnicalc/engine/casio/config.dart';
import 'package:omnicalc/engine/casio/cval.dart';
import 'package:omnicalc/engine/casio/engine.dart';
import 'package:omnicalc/engine/casio/solve_calc.dart';
import 'package:omnicalc/engine/types.dart';
import 'package:omnicalc/services/feedback_service.dart';
import 'package:omnicalc/ui/calculator/calculator_controller.dart';

void main() {
  CasioEngine engine0() => CasioEngine(config: const CasioConfig());

  test('the variables of A+Bi are A and B (i is the imaginary unit)', () {
    final e = engine0();
    final calc = CasioCalc(e, 'A+Bi', complex: CasioComplexEngine(e.memory));
    expect(calc.variables, <String>['A', 'B']);
  });

  test('A+Bi with A=1, B=1 and the ▸r∠θ command gives √2∠45 (Deg)', () {
    final e = engine0();
    final cx = CasioComplexEngine(e.memory);
    final calc = CasioCalc(e, 'A+Bi▸r∠θ', complex: cx);
    final out = calc.run(<String, CVal>{'A': CVal.int(1), 'B': CVal.int(1)});
    expect(out.text, '√2∠45');
  });

  test('A=3, B=4 gives 3+4i in rectangular form and 5∠θ with the polar command', () {
    final e = engine0();
    final cx = CasioComplexEngine(e.memory);
    final calc = CasioCalc(e, 'A+Bi', complex: cx);
    final first = calc.run(<String, CVal>{'A': CVal.int(3), 'B': CVal.int(4)});
    expect(first.text, '3+4i');
    final polar = CasioCalc(e, 'A+Bi▸r∠θ', complex: cx).run(<String, CVal>{'A': CVal.int(3), 'B': CVal.int(4)});
    expect(polar.text.startsWith('5∠'), isTrue);
  });

  test('without the complex engine the same line is a Syntax ERROR (CALC in COMP knows no i)', () {
    final e = engine0();
    expect(() => CasioCalc(e, 'A+Bi'), throwsA(isA<CasioError>()));
  });

  test('a real expression still works through CALC in CMPLX: 3A+B', () {
    final e = engine0();
    final calc = CasioCalc(e, '3A+B', complex: CasioComplexEngine(e.memory));
    final out = calc.run(<String, CVal>{'A': CVal.int(5), 'B': CVal.int(10)});
    expect(out.text, '25');
  });

  test('Var=expression stores the complex result in the variable', () {
    final e = engine0();
    final cx = CasioComplexEngine(e.memory);
    final calc = CasioCalc(e, 'C=A+Bi', complex: cx);
    calc.run(<String, CVal>{'A': CVal.int(2), 'B': CVal.int(5)});
    expect(cx.vars['C'], isNotNull);
    expect(cx.vars['C']!.re.v, 2);
    expect(cx.vars['C']!.im.v, 5);
  });

  group('through the calculator (CMPLX mode, manual p.48 example 2)', () {
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

    test('A+Bi stored with CALC: (A, B) = (3, 4) then (1, 1) in the same session', () {
      final c = make();
      c.setMode(CasioMode.cmplx);
      type(c, 'A+Bi');
      c.esCalc();
      expect(c.questionLine, 'A?');
      type(c, '3');
      c.handleEvaluate();
      expect(c.questionLine, 'B?');
      type(c, '4');
      c.handleEvaluate();
      expect(c.resultDoc.linear, '3+4i');
      c.handleEvaluate(); // = goes through the prompts again
      type(c, '1');
      c.handleEvaluate();
      type(c, '1');
      c.handleEvaluate();
      expect(c.resultDoc.linear, '1+i');
    });

    test('with the ▸r∠θ command the result is polar: A=1, B=1 gives √2∠45', () {
      final c = make();
      c.setMode(CasioMode.cmplx);
      type(c, 'A+Bi▸r∠θ');
      c.esCalc();
      type(c, '1');
      c.handleEvaluate();
      type(c, '1');
      c.handleEvaluate();
      expect(c.resultDoc.linear, '√2∠45');
    });

    test('in COMP the same line is a Syntax ERROR (no imaginary unit there)', () {
      final c = make();
      type(c, 'A+Bi');
      c.esCalc();
      expect(c.resultDoc.linear, 'Syntax ERROR');
    });
  });
}
