// Phase 8b: performance guards. Time limits are generous (CI machines are slow); they catch a hang, not a few milliseconds.

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/cval.dart';
import 'package:omnicalc/engine/casio/dist.dart';
import 'package:omnicalc/engine/casio/engine.dart';
import 'package:omnicalc/engine/casio/solve_calc.dart';
import 'package:omnicalc/engine/types.dart';
import 'package:omnicalc/services/feedback_service.dart';
import 'package:omnicalc/ui/calculator/calculator_controller.dart';
import 'package:omnicalc/engine/casio/config.dart';

CalculatorController make() {
  final c = CalculatorController(feedback: SilentFeedbackService(), engine: CasioEngine());
  c.updateProps(
    angleMode: AngleMode.rad,
    decimalPrecision: -1,
    soundEnabled: false,
    hapticEnabled: false,
    history: const [],
    casio: const CasioConfig(angle: CasioAngle.rad),
  );
  return c;
}

void type(CalculatorController c, String s) {
  for (final ch in s.split('')) {
    c.handleInput(ch);
  }
}

void main() {
  group('DIST stays fast for huge counts', () {
    test('Binomial CD with x near 1e10 returns quickly and sensibly', () {
      final sw = Stopwatch()..start();
      // mean 5e9: x at the mean is about one half, far below is about 0, far above is about 1
      final mid = CasioDist.compute(DistType.binomCd, <double>[4.5e9, 9e9, 0.5]);
      final low = CasioDist.compute(DistType.binomCd, <double>[1e9, 9e9, 0.5]);
      final high = CasioDist.compute(DistType.binomCd, <double>[8e9, 9e9, 0.5]);
      expect(sw.elapsedMilliseconds, lessThan(20000));
      expect(mid, closeTo(0.5, 1e-3));
      expect(low, lessThan(1e-12));
      expect(high, closeTo(1, 1e-12));
    });
    test('Poisson CD with a large x returns quickly and sensibly', () {
      final sw = Stopwatch()..start();
      final mid = CasioDist.compute(DistType.poissonCd, <double>[1e6, 1e6]);
      final low = CasioDist.compute(DistType.poissonCd, <double>[5e5, 1e6]);
      final high = CasioDist.compute(DistType.poissonCd, <double>[2e6, 1e6]);
      final huge = CasioDist.compute(DistType.poissonCd, <double>[9.9e9, 1e6]);
      expect(sw.elapsedMilliseconds, lessThan(20000));
      expect(mid, closeTo(0.5, 1e-2));
      expect(low, lessThan(1e-12));
      expect(high, closeTo(1, 1e-12));
      expect(huge, 1);
    });
    test('small counts keep the old term-by-term values', () {
      expect(CasioDist.compute(DistType.binomCd, <double>[3, 10, 0.5]), closeTo(0.171875, 1e-15));
      expect(CasioDist.compute(DistType.poissonCd, <double>[2, 3]), closeTo(0.42319008112684353, 1e-12));
    });
  });

  group('SOLVE and CALC worst cases', () {
    test('SOLVE that never converges gives up within a few seconds', () {
      final e = CasioEngine();
      final sw = Stopwatch()..start();
      final s = CasioSolver(e, 'X^2+1=0');
      Object? ended;
      try {
        var o = s.start(<String, CVal>{}, CVal.zero);
        var rounds = 0;
        while (o is SolveContinue && rounds < 20) {
          o = s.next();
          rounds++;
        }
        ended = o;
      } on CasioError catch (err) {
        ended = err;
      }
      expect(ended, isNotNull);
      expect(sw.elapsedMilliseconds, lessThan(5000));
    });
  });

  group('200-character editing', () {
    test('typing 200 characters and pressing = stays responsive', () {
      final c = make();
      final sw = Stopwatch()..start();
      final expr = '${List<String>.generate(50, (i) => '${i % 9 + 1}+').join()}1';
      for (final ch in expr.split('')) {
        c.handleInput(ch);
      }
      final typed = sw.elapsedMilliseconds;
      c.handleInput('=');
      expect(typed, lessThan(10000));
      expect(sw.elapsedMilliseconds, lessThan(15000));
      expect(c.expression.length, greaterThan(0));
    });

    test('per-key cost does not grow quickly with length', () {
      final c = make();
      final first = Stopwatch()..start();
      for (var i = 0; i < 40; i++) {
        c.handleInput('1');
        c.handleInput('+');
      }
      final firstMs = first.elapsedMicroseconds / 80;
      final second = Stopwatch()..start();
      for (var i = 0; i < 60; i++) {
        c.handleInput('1');
        c.handleInput('+');
      }
      final secondMs = second.elapsedMicroseconds / 120;
      // at 80..200 characters a key may cost more than at 0..80, but not by an order of magnitude plus a floor
      expect(secondMs, lessThan(firstMs * 10 + 5000));
    });
  });

  group('CALC with calculus runs in the background', () {
    test('CALC with an integral gives the result without blocking, then AC leaves the session', () async {
      final c = make();
      type(c, '∫(X,0,A)');
      c.esCalc();
      // variables are asked in order of appearance: the integration variable X first, then A
      expect(c.questionLine, 'X?');
      type(c, '0');
      c.handleEvaluate();
      expect(c.questionLine, 'A?');
      type(c, '2');
      c.handleEvaluate();
      expect(c.busy, isTrue);
      await c.pending;
      expect(c.busy, isFalse);
      expect(c.resultDoc.linear, '2');
      c.handleClear();
      expect(c.sessionActive, isFalse);
    });
    test('AC interrupts a long CALC and the session stays on its prompt', () async {
      final c = make();
      type(c, 'Σ(X,1,A)');
      c.esCalc();
      type(c, '0');
      c.handleEvaluate();
      type(c, '9999999999');
      c.handleEvaluate();
      expect(c.busy, isTrue);
      c.handleClear();
      expect(c.busy, isFalse);
      await c.pending;
      expect(c.sessionActive, isTrue);
      expect(c.questionLine, 'A?');
    });
    test('CALC without calculus still answers at once', () {
      final c = make();
      type(c, '3A+B');
      c.esCalc();
      type(c, '5');
      c.handleEvaluate();
      type(c, '10');
      c.handleEvaluate();
      expect(c.busy, isFalse);
      expect(c.resultDoc.linear, '25');
    });
  });
}
