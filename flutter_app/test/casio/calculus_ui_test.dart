// ∫ d/dx Σ ∏ nodes, SOLVE and CALC sessions and the background `=` of the calculator controller (Phase 7c).

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/editor/linear.dart';
import 'package:omnicalc/editor/nodes.dart';
import 'package:omnicalc/engine/casio/config.dart';
import 'package:omnicalc/engine/casio/engine.dart';
import 'package:omnicalc/engine/types.dart';
import 'package:omnicalc/services/feedback_service.dart';
import 'package:omnicalc/ui/calculator/calculator_controller.dart';

CalculatorController make({CasioConfig? casio}) {
  final c = CalculatorController(feedback: SilentFeedbackService(), engine: CasioEngine());
  c.updateProps(
    angleMode: AngleMode.rad,
    decimalPrecision: -1,
    soundEnabled: false,
    hapticEnabled: false,
    history: const [],
    casio: casio ?? const CasioConfig(angle: CasioAngle.rad),
  );
  return c;
}

void type(CalculatorController c, String s) {
  for (final ch in s.split('')) {
    c.handleInput(ch);
  }
}

void main() {
  group('nodes', () {
    test('serialize to the linear syntax of the manual', () {
      final i = IntegralNode([
        SlotNode([const CharNode('X')]),
        SlotNode([const CharNode('0')]),
        SlotNode([const CharNode('2')]),
      ]);
      expect(serializeNodes([i]), '∫(X,0,2)');
      expect(serializeNodes([DerivNode([SlotNode([const CharNode('X')]), SlotNode([const CharNode('1')])])]), 'd/dx(X,1)');
      expect(serializeNodes([SigmaNode([SlotNode([const CharNode('X')]), SlotNode([const CharNode('1')]), SlotNode([const CharNode('5')])])]),
          'Σ(X,1,5)');
      expect(serializeNodes([ProdNode([SlotNode([const CharNode('X')]), SlotNode([const CharNode('1')]), SlotNode([const CharNode('5')])])]),
          '∏(X,1,5)');
    });
    test('JSON round trip keeps the structures', () {
      final nodes = <Node>[IntegralNode(), DerivNode(), SigmaNode(), ProdNode()];
      final back = nodesFromJson(nodesToJson(nodes))!;
      expect(back.map((n) => n.runtimeType), [IntegralNode, DerivNode, SigmaNode, ProdNode]);
    });
    test('keys: the caret starts in the first slot and visits the others', () {
      final c = make();
      c.esIntegral();
      expect(c.doc.root.single, isA<IntegralNode>());
      expect(c.doc.path, [0, 0]);
      type(c, 'X');
      c.moveCaretRight();
      type(c, '0');
      c.moveCaretRight();
      type(c, '2');
      expect(c.expression, '∫(X,0,2)');
    });
    test('an empty slot is a Syntax ERROR on =', () {
      final c = make();
      c.esSigma();
      c.handleEvaluate();
      expect(c.syntaxError, 'Syntax ERROR');
    });
  });

  group('background =', () {
    test('∫ typed in its structure is calculated in the background', () async {
      final c = make();
      c.esIntegral();
      type(c, 'X²');
      c.moveCaretRight();
      type(c, '0');
      c.moveCaretRight();
      type(c, '2');
      c.handleEvaluate();
      await c.pending;
      expect(c.lastAnswer, '2.666666667');
      expect(c.busy, isFalse);
      expect(c.engine.memory.ans.v, closeTo(8 / 3, 1e-9));
    });
    test('Σ and an error from the isolate', () async {
      final c = make();
      type(c, 'Σ(X,1,100)');
      c.handleEvaluate();
      await c.pending;
      expect(c.lastAnswer, '5050');
      c.handleClear();
      type(c, '∫(ln(X),-1,1)');
      c.handleEvaluate();
      await c.pending;
      expect(c.lastAnswer, 'Math ERROR');
      expect(c.isErrorResult, isTrue);
    });
    test('AC interrupts a running calculation', () async {
      final c = make();
      type(c, 'Σ(X,1,9999999999)'); // limit: 1e10 is excluded, this runs long
      c.handleEvaluate();
      expect(c.busy, isTrue);
      c.handleClear();
      expect(c.busy, isFalse);
      await c.pending;
      expect(c.hasEvaluated, isFalse);
    });
    test('no live preview for a calculus line', () {
      final c = make();
      type(c, '∫(X,0,1)');
      expect(c.livePreview, '');
    });
  });

  group('SOLVE', () {
    test('the video: (X²−6)/(X+3)=10 from 0: X=12.81024968, L−R=0', () {
      final c = make();
      type(c, '(X²−6)/(X+3)=10');
      c.esSolve();
      expect(c.sessionActive, isTrue);
      expect(c.questionLine, 'X?'); // the initial value of X
      c.handleEvaluate(); // keeps 0
      expect(c.questionLine, '(X²−6)/(X+3)=10');
      expect(c.lastAnswer, '');
      expect(c.resultDoc.linear, 'X=12.81024968');
      expect(c.sessionExtra, 'L−R=0');
      c.handleClear();
      expect(c.sessionActive, isFalse);
      expect(c.expression, '(X²−6)/(X+3)=10', reason: 'AC returns to the line');
    });
    test('prompts follow the order of appearance and the value typed replaces the one shown', () {
      final c = make();
      type(c, 'Y=A×X+B');
      c.esSolve();
      expect(c.questionLine, 'Y?');
      type(c, '10');
      c.handleEvaluate();
      expect(c.questionLine, 'A?');
      type(c, '2');
      c.handleEvaluate();
      expect(c.questionLine, 'B?');
      type(c, '4');
      c.handleEvaluate();
      expect(c.questionLine, 'X?');
      type(c, '1');
      c.handleEvaluate();
      expect(c.resultDoc.linear, 'X=3');
    });
    test('Variable ERROR when the equation has no X', () {
      final c = make();
      type(c, 'A+B=3');
      c.esSolve();
      expect(c.resultDoc.linear, 'Variable ERROR');
      c.handleClear();
      expect(c.expression, 'A+B=3');
    });
    test("Can't Solve", () {
      final c = make();
      type(c, 'X²+1=0');
      c.esSolve();
      type(c, '1');
      c.handleEvaluate();
      var guard = 0;
      while (c.resultDoc.linear == 'Continue: [=]' && guard++ < 20) {
        c.handleEvaluate();
      }
      expect(c.resultDoc.linear, "Can't Solve");
    });
    test('Continue: [=] goes on with =', () {
      final c = make();
      type(c, 'X^9');
      c.exitGroup();
      type(c, '=1E-60');
      c.esSolve();
      type(c, '100');
      c.handleEvaluate();
      expect(c.resultDoc.linear, 'Continue: [=]');
      c.handleEvaluate();
      expect(c.sessionActive, isTrue);
    });
  });

  group('CALC', () {
    test('p.48: 3A+B for (5,10) then (7,20)', () {
      final c = make();
      type(c, '3A+B');
      c.esCalc();
      expect(c.questionLine, 'A?');
      type(c, '5');
      c.handleEvaluate();
      expect(c.questionLine, 'B?');
      type(c, '10');
      c.handleEvaluate();
      expect(c.resultDoc.linear, '25');
      c.handleEvaluate(); // = goes through the prompts again
      expect(c.questionLine, 'A?');
      type(c, '7');
      c.handleEvaluate();
      type(c, '20');
      c.handleEvaluate();
      expect(c.resultDoc.linear, '41');
      c.handleClear();
      expect(c.expression, '3A+B');
    });
    test('the prompt shows the current value of the variable', () {
      final c = make();
      type(c, '3→A');
      c.handleEvaluate();
      c.handleClear();
      type(c, '3A+B');
      c.esCalc();
      expect(c.resultDoc.linear, '3');
    });
    test('ALPHA + CALC types the equals sign: Y=X²+X+3 is a CALC line', () {
      final c = make();
      type(c, 'Y');
      c.toggleAlpha();
      c.esEquals();
      type(c, 'X²+X+3');
      expect(c.expression, 'Y=X²+X+3');
      c.esCalc();
      type(c, '2');
      c.handleEvaluate();
      expect(c.resultDoc.linear, '9');
    });
    test('an empty line or a result on screen does not start a session', () {
      final c = make();
      c.esCalc();
      expect(c.sessionActive, isFalse);
      type(c, '2+3');
      c.handleEvaluate();
      c.esSolve();
      expect(c.sessionActive, isFalse);
    });
  });
}
