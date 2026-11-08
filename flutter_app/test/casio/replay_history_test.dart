// Calculation replay history (manual p.31-32): ▲ ▼ scroll through the newest calculations; ON, a mode change, a display-format
// change and CLR ▸ Setup clear them. Row R03.

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/config.dart';
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

  void calc(CalculatorController c, String s) {
    c.handleClear();
    for (final ch in s.split('')) {
      c.handleInput(ch);
    }
    c.handleEvaluate();
  }

  CalculatorController three() {
    final c = make();
    calc(c, '1+1');
    calc(c, '2+2');
    calc(c, '3+3');
    return c;
  }

  test('the manual example: after 1+1, 2+2, 3+3 the ▲ key shows 2+2 = 4, then 1+1 = 2', () {
    final c = three();
    expect(c.lastAnswer, '6');
    c.esUp();
    expect(c.lastQuestion, '2+2');
    expect(c.lastAnswer, '4');
    c.esUp();
    expect(c.lastQuestion, '1+1');
    expect(c.lastAnswer, '2');
  });

  test('▼ comes forward again and stops at the newest', () {
    final c = three();
    c.esUp();
    c.esUp();
    c.esDown();
    expect(c.lastAnswer, '4');
    c.esDown();
    expect(c.lastAnswer, '6');
    c.esDown();
    expect(c.lastAnswer, '6');
  });

  test('▲ stops at the oldest', () {
    final c = three();
    for (var i = 0; i < 6; i++) {
      c.esUp();
    }
    expect(c.lastAnswer, '2');
  });

  test('the ▼▲ annunciator shows with a result on screen and history behind it', () {
    final c = make();
    expect(c.annunciators, isNot(contains('▼▲')));
    calc(c, '1+1');
    expect(c.annunciators, contains('▼▲'));
    c.handleClear();
    expect(c.annunciators, isNot(contains('▼▲')));
  });

  test('about 200 bytes are kept: the oldest calculations go first, the newest stays', () {
    final c = make();
    for (var i = 0; i < 40; i++) {
      calc(c, '${100 + i}+${100 + i}');
    }
    expect(c.replayLength, lessThan(40));
    expect(c.replayLength, greaterThan(5));
    expect(c.lastAnswer, '278');
  });

  test('a mode change clears the history', () {
    final c = three();
    c.setMode(CasioMode.cmplx);
    expect(c.replayLength, 0);
  });

  test('ON after OFF clears the history', () {
    final c = three();
    c.powerOff();
    c.powerOn();
    expect(c.replayLength, 0);
  });

  test('a display-format change clears the history', () {
    final c = three();
    c.updateProps(
      angleMode: AngleMode.deg,
      decimalPrecision: -1,
      soundEnabled: false,
      hapticEnabled: false,
      history: const [],
      casio: const CasioConfig(displayFormat: CasioDisplayFormat.lineIO),
    );
    expect(c.replayLength, 0);
  });

  test('CLR ▸ Setup clears the history, CLR ▸ Memory keeps it', () {
    final c = three();
    c.clearMemory();
    expect(c.replayLength, 3);
    c.clearSetup();
    expect(c.replayLength, 0);
  });

  test('STAT mode does not record calculations', () {
    final c = make();
    c.setMode(CasioMode.stat);
    expect(c.replayLength, 0);
  });

  test('▲ with no result on screen moves nothing: history is for the result screen', () {
    final c = three();
    c.handleClear();
    c.handleInput('5');
    c.esUp();
    expect(c.expression, '5');
  });
}
