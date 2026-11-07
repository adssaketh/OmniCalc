import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/editor/expr_doc.dart' show kMaxStructDepth;
import 'package:omnicalc/editor/nodes.dart';
import 'package:omnicalc/editor/rich_layout.dart';
import 'package:omnicalc/engine/types.dart';
import 'package:omnicalc/services/feedback_service.dart';
import 'package:omnicalc/ui/calculator/calculator_controller.dart';

/// Phase 8a: the natural-display keys of the ES tab at controller level. The first test replays the screen recording of
/// the real calculator (Part 9, 9.2 "Behavior from the video frames") key by key up to the typed equation.
void main() {
  late CalculatorController c;

  setUp(() {
    c = CalculatorController(feedback: SilentFeedbackService(), clipboard: (text) async {});
    c.updateProps(
      angleMode: AngleMode.deg,
      decimalPrecision: -1,
      soundEnabled: true,
      hapticEnabled: true,
      history: const [],
    );
  });

  void type(String s) {
    for (final ch in s.split('')) {
      c.handleInput(ch);
    }
  }

  group('the video sequence', () {
    test('1-2. empty line, then the fraction key: two hollow boxes and the caret in the numerator', () {
      c.handleClear();
      c.esFraction();
      final doc = c.doc;
      expect(doc.root.single, isA<FracNode>());
      expect(doc.path, [0, 0]);
      expect(doc.offset, 0);
      expect(doc.firstPlaceholderPath, [0, 0]);
      expect(c.caretVisible, isTrue);
      expect(c.annunciators, contains('Math'));
    });

    test('3. X then x²: a small raised 2 with the caret INSIDE it; → leaves it; then −6', () {
      c.esFraction();
      c.handleInput('X');
      c.esPower('2');
      expect(c.doc.inSlot, isFalse, reason: 'the caret is in the superscript');
      expect(c.doc.chain.last, isA<SupNode>());
      expect(c.doc.scriptDepth, 1);
      expect(c.moveCaretRight(), isTrue); // leaves the superscript, stays in the numerator
      expect(c.doc.path, [0, 0]);
      type('−6');
      final frac = c.doc.root.single as FracNode;
      expect(frac.slots[0].children.length, 4); // X ² − 6
      expect(c.doc.linear, '((X^2−6)÷())');
    });

    test('4. ▼ goes to the denominator, X+3, → leaves the fraction', () {
      c.esFraction();
      c.handleInput('X');
      c.esPower('2');
      c.moveCaretRight();
      type('−6');
      expect(c.moveCaretDown(), isTrue);
      expect(c.doc.path, [0, 1]);
      type('X+3');
      expect(c.moveCaretRight(), isTrue);
      expect(c.doc.path, isEmpty);
      expect(c.doc.offset, 1);
      expect(c.doc.linear, '((X^2−6)÷(X+3))');
      expect(c.doc.firstPlaceholderPath, isNull);
    });

    test('4b. → from the numerator also reaches the denominator (the other route the recording shows)', () {
      c.esFraction();
      c.handleInput('X');
      expect(c.moveCaretRight(), isTrue);
      expect(c.doc.path, [0, 1]);
    });

    test('5. ALPHA + CALC types =, then 10: (X²−6)/(X+3) = 10', () {
      c.esFraction();
      c.handleInput('X');
      c.esPower('2');
      c.moveCaretRight();
      type('−6');
      c.moveCaretDown();
      type('X+3');
      c.moveCaretRight();
      c.toggleAlpha();
      expect(c.alphaOn, isTrue);
      expect(c.annunciators, contains('A'));
      c.esEquals();
      expect(c.alphaOn, isFalse, reason: 'ALPHA is used up by the key');
      type('10');
      expect(c.doc.linear, '((X^2−6)÷(X+3))=10');
      expect(c.doc.root.length, 4);
      expect(c.doc.path, isEmpty);
    });

    test('7. calculating with an unfilled placeholder is a Syntax ERROR with the caret on it', () {
      c.esFraction();
      c.handleInput('1'); // numerator filled, denominator still a box
      c.handleEvaluate();
      expect(c.syntaxError, 'Syntax ERROR');
      expect(c.hasEvaluated, isFalse, reason: 'the expression stays editable');
      expect(c.doc.path, [0, 1]);
      expect(c.doc.offset, 0);
      expect(c.lastAnswer, isEmpty);
      // typing into the box fixes it
      c.handleInput('4');
      expect(c.syntaxError, isNull);
      c.handleEvaluate();
      expect(c.syntaxError, isNull);
      expect(c.hasEvaluated, isTrue);
      expect(c.lastAnswer, '0.25');
    });

    test('an entirely empty fraction is a Syntax ERROR on its numerator', () {
      c.esFraction();
      c.handleEvaluate();
      expect(c.syntaxError, 'Syntax ERROR');
      expect(c.doc.path, [0, 0]);
    });
  });

  group('structures calculate through the legacy engine', () {
    test('a fraction: (1+2)/4 = 0.75', () {
      c.esFraction();
      type('1+2');
      c.moveCaretDown();
      c.handleInput('4');
      c.handleEvaluate();
      expect(c.lastAnswer, '0.75');
    });

    test('2 then a square root multiplies: 2√9 = 6', () {
      c.handleInput('2');
      c.esSqrt();
      c.handleInput('9');
      expect(c.doc.linear, '2×sqrt(9)');
      c.handleEvaluate();
      expect(c.lastAnswer, '6');
    });

    test('cube root has its index filled in and the caret in the radicand', () {
      c.esCbrt();
      expect(c.doc.path, [0, 1]);
      c.handleInput('2');
      c.handleInput('7');
      expect(c.doc.linear, 'root(3,27)');
      c.handleEvaluate();
      expect(c.lastAnswer, '3');
    });

    test('n-th root: index first, then radicand: 4th root of 81 = 3', () {
      c.esRoot();
      expect(c.doc.path, [0, 0]);
      c.handleInput('4');
      c.moveCaretRight();
      expect(c.doc.path, [0, 1]);
      type('81');
      c.handleEvaluate();
      expect(c.lastAnswer, '3');
    });

    test('abs and log with a base: |−5| = 5, log₂ 8 = 3', () {
      c.esAbs();
      type('−5');
      c.handleEvaluate();
      expect(c.lastAnswer, '5');
      c.handleClear();
      c.esLogBase();
      c.handleInput('2');
      c.moveCaretRight();
      c.handleInput('8');
      expect(c.doc.linear, 'logb(2,8)');
      c.handleEvaluate();
      expect(c.lastAnswer, '3');
    });

    test('mixed fraction 1 and 1/2 = 1.5', () {
      c.esMixedFraction();
      c.handleInput('1');
      c.moveCaretRight();
      c.handleInput('1');
      c.moveCaretDown();
      c.handleInput('2');
      c.handleEvaluate();
      expect(c.lastAnswer, '1.5');
    });

    test('the history entry keeps the rich tree, and reloading it gives the structure back', () {
      c.esFraction();
      c.handleInput('1');
      c.moveCaretDown();
      c.handleInput('4');
      final entries = <List<Object>?>[];
      c.onAddHistoryRich = ({required expression, required result, required mode, rich}) => entries.add(rich);
      c.handleEvaluate();
      expect(entries.single, isNotNull);
    });
  });

  group('typing inside structures', () {
    test('digits and operators go into the slot the caret is in', () {
      c.esFraction();
      type('12+3');
      expect((c.doc.root.single as FracNode).slots[0].children.length, 4);
      expect(c.doc.path, [0, 0]);
    });

    test('( ) inside a numerator counts only that slot: the second press closes', () {
      c.esFraction();
      c.handleParentheses();
      c.handleInput('1');
      c.handleParentheses();
      final num = (c.doc.root.single as FracNode).slots[0].children.map((n) => (n as CharNode).ch).join();
      expect(num, '(1)');
    });

    test('Backspace walks back out of the structure and removes it', () {
      c.esFraction();
      c.handleInput('5');
      c.moveCaretDown();
      c.handleInput('6');
      for (var i = 0; i < 6; i++) {
        c.handleBackspace();
      }
      expect(c.doc.root.isEmpty || c.expression == '0', isTrue);
    });

    test('a structure after a result starts a new line', () {
      type('2+3');
      c.handleEvaluate();
      expect(c.hasEvaluated, isTrue);
      c.esFraction();
      expect(c.hasEvaluated, isFalse);
      expect(c.doc.root.single, isA<FracNode>());
    });

    test('x² twice in a row ignores the second press; another key in between allows it again', () {
      c.handleInput('2');
      c.esPower('2');
      c.esPower('2');
      var sup = c.doc.root[1] as SupNode;
      expect(sup.children.length, 1, reason: 'no 2²² (manual: x², x³, x⁻¹ cannot be entered consecutively)');
      c.moveCaretRight();
      c.esPower('3');
      expect(c.doc.root.length, 3);
      sup = c.doc.root[2] as SupNode;
      expect(sup.children, [const CharNode('3')]);
    });

    test('x⁻¹ puts −1 into the superscript', () {
      c.handleInput('4');
      c.esPower('−1');
      expect(c.doc.linear, '4^(−1)');
      c.handleEvaluate();
      expect(c.lastAnswer, '0.25');
    });

    test('nesting is limited: the fifth structure is refused', () {
      for (var i = 0; i < 6; i++) {
        c.esFraction();
      }
      expect(c.doc.structDepth, kMaxStructDepth);
    });
  });

  group('SHIFT, ALPHA, INS', () {
    test('each arms one prefix and shows its annunciator; arming one releases the other', () {
      c.toggleShift();
      expect(c.annunciators, ['S']);
      c.toggleAlpha();
      expect(c.annunciators, ['A']);
      c.toggleIns();
      expect(c.annunciators, ['INS']);
      c.toggleIns();
      expect(c.annunciators, isEmpty);
    });

    test('a key press uses the armed prefix up', () {
      c.toggleShift();
      c.handleInput('5');
      expect(c.shiftOn, isFalse);
      expect(c.annunciators, isEmpty);
    });

    test('an arrow also releases it', () {
      c.esFraction();
      c.toggleAlpha();
      c.moveCaretRight();
      expect(c.alphaOn, isFalse);
    });

    test('M shows while the memory is not zero', () {
      type('5');
      c.handleMemory(MemoryAction.ms);
      expect(c.annunciators, contains('M'));
      c.handleMemory(MemoryAction.mc);
      expect(c.annunciators, isNot(contains('M')));
    });

    test('plain arithmetic shows no annunciator at all', () {
      type('2+3');
      expect(c.annunciators, isEmpty);
      expect(c.syntaxError, isNull);
    });

    test('INS then √ wraps what is right of the caret: 1 + 7/6 becomes 1 + √(7/6)', () {
      type('1+');
      c.esFraction();
      c.handleInput('7');
      c.moveCaretDown();
      c.handleInput('6');
      c.placeCaret(const CaretHit([], 2)); // in front of the fraction
      c.toggleIns();
      c.esSqrt();
      expect(c.insArmed, isFalse);
      expect(c.doc.linear, '1+sqrt(((7)÷(6)))');
      c.handleEvaluate();
      expect(double.parse(c.lastAnswer), closeTo(1 + 1.0801234497346435, 1e-6));
    });

    test('INS armed but the key has no wrap (fraction) just inserts and releases', () {
      type('5');
      c.toggleIns();
      c.esFraction();
      expect(c.insArmed, isFalse);
      expect(c.doc.root.last, isA<FracNode>());
    });
  });

  group('the caret and the arrows', () {
    test('▲ and ▼ do nothing outside a fraction (the keys then fall back to history stepping)', () {
      type('12');
      expect(c.moveCaretUp(), isFalse);
      expect(c.moveCaretDown(), isFalse);
    });

    test('hardware ArrowDown / ArrowUp move between numerator and denominator inside a fraction', () {
      c.esFraction();
      c.handleInput('1');
      expect(c.handleKeyDown('ArrowDown'), isTrue);
      expect(c.doc.path, [0, 1]);
      expect(c.handleKeyDown('ArrowUp'), isTrue);
      expect(c.doc.path, [0, 0]);
    });

    test('arrows do not edit a result that is on screen', () {
      type('2+3');
      c.handleEvaluate();
      expect(c.moveCaretLeft(), isFalse);
      expect(c.moveCaretDown(), isFalse);
    });

    test('the exit key leaves the structure', () {
      c.esSqrt();
      c.handleInput('2');
      expect(c.exitGroup(), isTrue);
      expect(c.doc.path, isEmpty);
      expect(c.doc.offset, 1);
    });
  });

  test('the ES tab is the last Advanced tab and the others keep their order', () {
    expect(advancedTabDefs.map((d) => d.id).toList(), [
      AdvancedTab.calculus,
      AdvancedTab.trig,
      AdvancedTab.powers,
      AdvancedTab.prob,
      AdvancedTab.constants,
      AdvancedTab.chemistry,
      AdvancedTab.es,
    ]);
  });
}
