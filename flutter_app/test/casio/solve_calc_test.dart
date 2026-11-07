// SOLVE (manual p.49-51) and CALC (manual p.47-49) of the Casio engine, Phase 7c.

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/calculus.dart';
import 'package:omnicalc/engine/casio/config.dart';
import 'package:omnicalc/engine/casio/cval.dart';
import 'package:omnicalc/engine/casio/engine.dart';
import 'package:omnicalc/engine/casio/format.dart';
import 'package:omnicalc/engine/casio/solve_calc.dart';

CasioEngine make([CasioConfig cfg = const CasioConfig()]) => CasioEngine(config: cfg);

String fmt(CasioEngine e, CVal v) => CasioFormatter(e.config).first(v).display;

SolveDone solved(SolveOutcome o) {
  expect(o, isA<SolveDone>());
  return o as SolveDone;
}

void main() {
  group('SOLVE', () {
    test('the video: (X²−6)/(X+3)=10 from 0 gives X=12.81024968, L−R=0 (= 5+√61)', () {
      final e = make();
      final s = CasioSolver(e, '(X²−6)/(X+3)=10');
      expect(s.variable, 'X');
      expect(s.prompts, isEmpty);
      final r = solved(s.start(const {}, CVal.zero));
      expect(fmt(e, CVal.dec(r.value.v)), '12.81024968');
      expect(fmt(e, r.lMinusR), '0');
      expect(r.value.v, closeTo(5 + 7.810249675906654, 1e-10));
      expect(e.memory.vars['X']!.v, closeTo(12.81024967590665, 1e-10));
    });
    test('p.49: y = ax² + b for x with y=0, a=1, b=-2, X starting at 1 gives √2', () {
      final e = make();
      final s = CasioSolver(e, 'Y=A×X²+B');
      // the prompts follow the equation: Y, A, B, then the initial value of X
      expect(s.prompts, ['Y', 'A', 'B']);
      final r = solved(s.start({'Y': CVal.int(0), 'A': CVal.int(1), 'B': CVal.int(-2)}, CVal.int(1)));
      expect(r.value.v, closeTo(1.4142135623731, 1e-9));
      expect(fmt(e, CVal.dec(r.value.v)), '1.414213562');
    });
    test('p.51: y = x² − x + 1 for x when y = 3, 7, 13 (X starting at 1)', () {
      for (final (y, x) in [(3, 2.0), (7, 3.0), (13, 4.0)]) {
        final e = make();
        final s = CasioSolver(e, 'Y=X²−X+1');
        final r = solved(s.start({'Y': CVal.int(y)}, CVal.int(1)));
        expect(r.value.v, closeTo(x, 1e-9), reason: 'y=$y');
      }
    });
    test('an expression alone is taken as expr = 0 (X²+2X−2 = 0)', () {
      final e = make();
      final s = CasioSolver(e, 'X²+2X−2');
      expect(s.equation, 'X²+2X−2=0');
      final r = solved(s.start(const {}, CVal.int(1)));
      expect(r.value.v, closeTo(0.7320508075688772, 1e-9));
    });
    test('{equation},{variable}: Y=X+5,Y solves for Y', () {
      final e = make();
      final s = CasioSolver(e, 'Y=X+5,Y');
      expect(s.variable, 'Y');
      expect(s.prompts, ['X']);
      final r = solved(s.start({'X': CVal.int(3)}, CVal.zero));
      expect(r.value.v, closeTo(8, 1e-12));
    });
    test('the prompts start with the current value of each variable', () {
      final e = make()..evaluate('5→B');
      final s = CasioSolver(e, 'X=sin(M)+B');
      expect(s.current('B').v, 5);
      expect(s.prompts, ['M', 'B']);
    });
    test('X=sin(M) style: X on the left and a function of another variable', () {
      final e = make(const CasioConfig(angle: CasioAngle.rad));
      final s = CasioSolver(e, 'X=sin(M)');
      final r = solved(s.start({'M': CVal.int(0)}, CVal.int(1)));
      expect(r.value.v.abs(), lessThan(1e-9));
    });
    test('the entered values stay in the variables afterwards', () {
      final e = make();
      final s = CasioSolver(e, 'Y=A×X+B');
      solved(s.start({'Y': CVal.int(10), 'A': CVal.int(2), 'B': CVal.int(4)}, CVal.zero));
      expect(e.memory.vars['A']!.v, 2);
      expect(e.memory.vars['X']!.v, closeTo(3, 1e-9));
    });
    test('Variable ERROR: no X and no variable given, or the variable is not in the equation', () {
      final e = make();
      expect(() => CasioSolver(e, 'A+B=3'), throwsA(isA<CasioError>().having((x) => x.message, 'message', 'Variable ERROR')));
      expect(() => CasioSolver(e, 'X+1=3,Y'),
          throwsA(isA<CasioError>().having((x) => x.message, 'message', 'Variable ERROR')));
    });
    test('Syntax ERROR: ∫ d/dx Σ ∏ Pol Rec ÷R are not allowed in an equation', () {
      final e = make();
      for (final bad in ['∫(X,0,1)=X', 'Σ(X,1,2)=X', 'd/dx(X,1)=X', 'Pol(X,1)=X', '5÷R2=X']) {
        expect(() => CasioSolver(e, bad), throwsA(isA<CasioError>().having((x) => x.message, 'message', 'Syntax ERROR')),
            reason: bad);
      }
    });
    test("Can't Solve: X²+1=0 has no real solution", () {
      final e = make();
      final s = CasioSolver(e, 'X²+1=0');
      expect(() {
        var o = s.start(const {}, CVal.int(1));
        while (o is SolveContinue) {
          o = s.next();
        }
      }, throwsA(isA<CasioError>().having((x) => x.message, 'message', "Can't Solve")));
    });
    test('Continue: a slow convergence stops after the preset iterations and goes on with `=`', () {
      final e = make();
      // Newton on X^9 = 0 from 1 halves the distance each step by 8/9: far more than one round is needed
      final s = CasioSolver(e, 'X^9=1E-60');
      var o = s.start(const {}, CVal.int(100));
      var rounds = 1;
      while (o is SolveContinue) {
        o = s.next();
        rounds++;
        expect(rounds, lessThan(CasioSolver.kMaxRounds + 2));
      }
      expect(rounds, greaterThan(1));
    });
    test('AC interrupts a running SOLVE', () {
      final e = make();
      final c = CasioCancel()..cancelled = true;
      e.cancel = c;
      final s = CasioSolver(e, 'X²−2=0');
      expect(() => s.start(const {}, CVal.int(1)), throwsA(isA<CasioCancelled>()));
    });
  });

  group('CALC', () {
    test('p.48 example 1: 3A+B for (A,B) = (5,10) and (7,20)', () {
      final e = make();
      final c = CasioCalc(e, '3A+B');
      expect(c.variables, ['A', 'B']);
      expect(c.run({'A': CVal.int(5), 'B': CVal.int(10)}).text, '25');
      expect(c.run({'A': CVal.int(7), 'B': CVal.int(20)}).text, '41');
    });
    test('`=` between prompts keeps the current value: run with no new values', () {
      final e = make();
      final c = CasioCalc(e, '3A+B');
      c.run({'A': CVal.int(5), 'B': CVal.int(10)});
      expect(c.run(const {}).text, '25');
    });
    test('multi-statement X+Y : X(X+Y)', () {
      final e = make();
      final c = CasioCalc(e, 'X+Y:X(X+Y)');
      expect(c.variables, ['X', 'Y']);
      final out = c.run({'X': CVal.int(2), 'Y': CVal.int(3)});
      expect(out.text, '10');
      expect(out.disp, ['5']);
    });
    test('Var = expression: Y = X²+X+3 asks for X and stores Y', () {
      final e = make();
      final c = CasioCalc(e, 'Y=X²+X+3');
      expect(c.target, 'Y');
      expect(c.variables, ['X']);
      expect(c.run({'X': CVal.int(2)}).text, '9');
      expect(e.memory.vars['Y']!.v, 9);
    });
    test('the value is exact when the inputs are: A÷B', () {
      final e = make();
      final c = CasioCalc(e, 'A÷B');
      expect(c.run({'A': CVal.int(1), 'B': CVal.int(3)}).text, '1⌟3');
    });
    test('an expression with no variables still runs', () {
      final e = make();
      final c = CasioCalc(e, '2+3');
      expect(c.variables, isEmpty);
      expect(c.run(const {}).text, '5');
    });
    test('Syntax ERROR: empty, two equals signs, left side that is not a variable', () {
      final e = make();
      for (final bad in ['', 'A=B=3', '3=A']) {
        expect(() => CasioCalc(e, bad), throwsA(isA<CasioError>()), reason: bad);
      }
    });
  });
}
