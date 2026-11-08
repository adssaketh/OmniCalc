// The 99-byte input limit (manual p.18, p.85) in VERIF mode and the DRG▸ marks (manual p.37). Rows P05 and A35.

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/cval.dart';
import 'package:omnicalc/engine/casio/engine.dart';
import 'package:omnicalc/engine/casio/verif.dart';
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

  test('numerals and symbols are one byte, a function name is counted as three', () {
    expect(CasioInputBytes.count('12+3'), 4);
    expect(CasioInputBytes.count('sin(30)'), 3 + 3);
    expect(CasioInputBytes.count('log(100)'), 3 + 4);
  });

  test('99 bytes fit, 100 do not', () {
    expect(CasioInputBytes.fits('1' * 99), isTrue);
    expect(CasioInputBytes.fits('1' * 100), isFalse);
  });

  test('VERIF refuses a calculation of more than 99 bytes typed at the keys', () {
    final c = make();
    c.setMode(CasioMode.verif);
    for (var i = 0; i < 120; i++) {
      c.handleInput('1');
    }
    expect(c.expression.length, 99);
  });

  test('COMP is not limited by the VERIF rule (legacy expressions stay as long as they were)', () {
    final c = make();
    for (var i = 0; i < 120; i++) {
      c.handleInput('1');
    }
    expect(c.expression.length, 120);
  });

  test('a pasted line over the limit is a Syntax ERROR in the engine', () {
    final e = CasioEngine();
    expect(() => CasioVerif.verify(e, '${'1+' * 60}1=2'), throwsA(isA<CasioError>()));
  });

  test('a line at the limit still verifies', () {
    final e = CasioEngine();
    expect(CasioVerif.verify(e, '${'1+' * 40}1=41').isTrue, isTrue);
  });

  test('DRG▸ gradian mark: 50ᵍ is 45 in Deg (manual p.37)', () {
    final c = make();
    for (final ch in '50ᵍ'.split('')) {
      c.handleInput(ch);
    }
    c.handleEvaluate();
    expect(c.lastAnswer, '45');
  });

  test('DRG▸ radian mark: (π÷2)ʳ is 90 in Deg (manual p.37)', () {
    final c = make();
    for (final ch in '(π÷2)ʳ'.split('')) {
      c.handleInput(ch);
    }
    c.handleEvaluate();
    expect(c.lastAnswer, '90');
  });
}
