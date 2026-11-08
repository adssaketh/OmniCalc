// Phase 7e on the calculator: VERIF mode on the calculation line, CLR (Setup / Memory / All), OFF / ON, and the persist hook.

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/cval.dart';
import 'package:omnicalc/engine/casio/engine.dart';
import 'package:omnicalc/engine/types.dart';
import 'package:omnicalc/services/feedback_service.dart';
import 'package:omnicalc/ui/calculator/calculator_controller.dart';

void main() {
  CalculatorController make({CasioEngine? engine, CasioMode mode = CasioMode.comp}) {
    final c = CalculatorController(feedback: SilentFeedbackService(), clipboard: (text) async {}, engine: engine, initialMode: mode);
    c.updateProps(angleMode: AngleMode.deg, decimalPrecision: -1, soundEnabled: true, hapticEnabled: true, history: const []);
    return c;
  }

  void type(CalculatorController c, String s) {
    for (final ch in s.split('')) {
      c.handleInput(ch);
    }
  }

  group('VERIF mode', () {
    test('4√9 = 12 answers TRUE and stores 1 in Ans', () {
      final c = make();
      c.enterVerif();
      expect(c.mode, CasioMode.verif);
      expect(c.modeName, 'VERIF');
      type(c, '4×√(9)=12');
      c.handleEvaluate();
      expect(c.lastAnswer, 'TRUE');
      expect(c.engine.memory.ans.v, 1);
    });

    test('a false relation answers FALSE and stores 0', () {
      final c = make();
      c.enterVerif();
      type(c, '3≥4');
      c.handleEvaluate();
      expect(c.lastAnswer, 'FALSE');
      expect(c.engine.memory.ans.v, 0);
    });

    test('chained relations and the Syntax ERROR forms', () {
      final c = make();
      c.enterVerif();
      type(c, '3<π<4');
      c.handleEvaluate();
      expect(c.lastAnswer, 'TRUE');
      c.handleClear();
      type(c, '5≤6≥4');
      c.handleEvaluate();
      expect(c.expression, 'Syntax ERROR');
      c.handleClear();
      type(c, '=5');
      c.handleEvaluate();
      expect(c.expression, 'Syntax ERROR');
    });

    test('no live preview in VERIF, and back in COMP the line calculates again', () {
      final c = make();
      c.enterVerif();
      type(c, '1+1=2');
      expect(c.livePreview, '');
      c.setMode(CasioMode.comp);
      type(c, '2+3');
      c.handleEvaluate();
      expect(c.expression, '5');
    });
  });

  group('CLR', () {
    CalculatorController filled() {
      final e = CasioEngine();
      e.memory.vars['A'] = CVal.int(7);
      e.memory.vars['M'] = CVal.int(3);
      e.memory.setAns(CVal.int(42));
      return make(engine: e);
    }

    test('Memory clears Ans, PreAns and every variable including M', () {
      final c = filled();
      c.clearMemory();
      expect(c.engine.memory.ans.v, 0);
      expect(c.engine.memory.vars['A']!.v, 0);
      expect(c.engine.memory.vars['M']!.v, 0);
    });

    test('Setup keeps the memory, goes back to COMP and asks the screen to reset SETUP', () {
      final c = filled();
      c.setMode(CasioMode.baseN);
      var reset = 0;
      c.onResetSetup = () => reset++;
      c.clearSetup();
      expect(reset, 1);
      expect(c.mode, CasioMode.comp);
      expect(c.engine.memory.vars['A']!.v, 7);
    });

    test('All does both', () {
      final c = filled();
      c.setMode(CasioMode.cmplx);
      var reset = 0;
      c.onResetSetup = () => reset++;
      c.clearAll();
      expect(reset, 1);
      expect(c.mode, CasioMode.comp);
      expect(c.engine.memory.vars['A']!.v, 0);
    });
  });

  group('OFF and ON', () {
    test('OFF darkens the unit, keeps the memory, ON wakes it', () {
      final e = CasioEngine();
      e.memory.setAns(CVal.int(9));
      final c = make(engine: e);
      expect(c.isOff, isFalse);
      c.powerOff();
      expect(c.isOff, isTrue);
      expect(c.engine.memory.ans.v, 9);
      c.powerOn();
      expect(c.isOff, isFalse);
    });
  });

  group('persist hook', () {
    test('a result, a mode change and OFF each call onPersist', () {
      final c = make();
      var calls = 0;
      c.onPersist = () => calls++;
      type(c, '2+3');
      c.handleEvaluate();
      expect(calls, 1);
      c.setMode(CasioMode.cmplx);
      expect(calls, 2);
      c.powerOff();
      expect(calls, 3);
    });

    test('the unit starts in the mode it was given', () {
      final c = make(mode: CasioMode.verif);
      expect(c.mode, CasioMode.verif);
    });
  });

  group('×10ˣ key', () {
    test('1.5 ×10ˣ 3 reads as 1.5×10³ = 1500', () {
      final c = make();
      type(c, '1.5');
      c.esTimesTen();
      c.handleInput('3');
      c.handleEvaluate();
      expect(c.lastAnswer, '1500');
    });

    test('after a result the key continues from Ans', () {
      final c = make();
      type(c, '2+3');
      c.handleEvaluate();
      c.esTimesTen();
      c.handleInput('2');
      c.handleEvaluate();
      expect(c.lastAnswer, '500');
    });
  });
}
