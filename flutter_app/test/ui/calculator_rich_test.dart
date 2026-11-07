import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/editor/expr_doc.dart';
import 'package:omnicalc/editor/rich_layout.dart';
import 'package:omnicalc/engine/evaluator.dart';
import 'package:omnicalc/engine/types.dart';
import 'package:omnicalc/services/feedback_service.dart';
import 'package:omnicalc/state/history_store.dart';
import 'package:omnicalc/ui/calculator/calculator_controller.dart';

/// Phase 4b: the rich editor behind the calculator display. Expected values follow Part 2 of the master prompt; the
/// engine results (2^3+4 = 12, 2^(3+4) = 128, 10^(3) = 1000) are ordinary arithmetic.
void main() {
  late SilentFeedbackService feedback;
  late List<({String expression, String result, String mode, List<Object>? rich})> added;

  CalculatorController make({List<HistoryItem> history = const []}) {
    final c = CalculatorController(
      feedback: feedback,
      clipboard: (text) async {},
      onAddHistoryRich: ({required expression, required result, required mode, rich}) =>
          added.add((expression: expression, result: result, mode: mode, rich: rich)),
    );
    c.updateProps(
      angleMode: AngleMode.deg,
      decimalPrecision: -1,
      soundEnabled: true,
      hapticEnabled: true,
      history: history,
    );
    return c;
  }

  void type(CalculatorController c, String s) {
    for (final ch in s.split('')) {
      c.handleInput(ch);
    }
  }

  setUp(() {
    feedback = SilentFeedbackService();
    added = [];
    MathEvaluator.setYDefinition(null);
  });
  tearDown(() => MathEvaluator.setYDefinition(null));

  group('typing a power', () {
    test('everything after ^ goes into the superscript until it is left', () {
      final c = make();
      type(c, '2^3');
      expect(c.caretInGroup, isTrue);
      type(c, '+4');
      expect(c.expression, '2^(3+4)');
      c.handleEvaluate();
      expect(c.expression, '128');
    });

    test('the exit key leaves the superscript', () {
      final c = make();
      type(c, '2^3');
      expect(c.exitGroup(), isTrue);
      expect(c.caretInGroup, isFalse);
      type(c, '+4');
      expect(c.expression, '2^3+4');
      c.handleEvaluate();
      expect(c.expression, '12');
    });

    test('exit does nothing outside a group', () {
      final c = make();
      type(c, '12');
      expect(c.exitGroup(), isFalse);
    });

    test('the x² key adds a finished power and the caret stays in the line', () {
      final c = make();
      c.handleInput('x');
      c.handleInput('^2');
      expect(c.expression, 'x^2');
      expect(c.caretInGroup, isFalse);
      c.handleInput('+');
      expect(c.expression, 'x^2+');
    });

    test('a digit after a finished power stays at the base level', () {
      final c = make();
      c.handleInput('x');
      c.handleInput('^2');
      c.handleInput('3');
      // x squared, then a 3: not x to the 23rd
      expect(c.expression, 'x^(2)3');
    });

    test('a power typed after a result continues from the result', () {
      final c = make();
      type(c, '3+4');
      c.handleEvaluate();
      expect(c.expression, '7');
      c.handleInput('^');
      expect(c.expression, '7^');
      expect(c.caretInGroup, isTrue);
    });

    test('x⁻¹ key', () {
      final c = make();
      c.handleInput('4');
      c.handleInput('^(-1)');
      expect(c.expression, '4^(-1)');
      expect(c.caretInGroup, isFalse);
      c.handleEvaluate();
      expect(c.expression, '0.25');
    });

    test('a template with a power opens it with the caret inside', () {
      final c = make();
      c.handleInsertTemplate('10^(');
      expect(c.expression, '10^(');
      expect(c.caretInGroup, isTrue);
      c.handleInput('3');
      c.handleParentheses(); // closes the parenthesis inside the superscript
      expect(c.expression, '10^(3)');
      expect(c.caretInGroup, isTrue);
      c.handleEvaluate();
      expect(c.expression, '1000');
    });

    test('a function inside a superscript', () {
      final c = make();
      type(c, '2^');
      c.handleFunction('sin');
      expect(c.expression, '2^sin(');
    });

    test('three levels at most', () {
      final c = make();
      c.handleInput('^');
      c.handleInput('^');
      c.handleInput('^');
      expect(c.doc.depth, 3);
      final before = c.expression;
      c.handleInput('^');
      expect(c.doc.depth, 3);
      expect(c.expression, before);
    });
  });

  group('subscript', () {
    test('the _ key lowers the text that follows', () {
      final c = make();
      expect(c.handleKeyDown('_'), isTrue);
      expect(c.caretInGroup, isTrue);
      c.handleInput('1');
      expect(c.expression, '0_1');
    });
  });

  group('caret keys', () {
    test('typing in the middle of the line', () {
      final c = make();
      type(c, '12');
      expect(c.moveCaretLeft(), isTrue);
      c.handleInput('9');
      expect(c.expression, '192');
      expect(c.caretVisible, isTrue);
    });

    test('arrow keys move the caret and report whether they did', () {
      final c = make();
      type(c, '12');
      expect(c.handleKeyDown('ArrowLeft'), isTrue);
      expect(c.handleKeyDown('ArrowLeft'), isTrue);
      expect(c.handleKeyDown('ArrowLeft'), isFalse); // already at the start
      expect(c.handleKeyDown('ArrowRight'), isTrue);
    });

    test('a result is not edited with the caret', () {
      final c = make();
      type(c, '1+1');
      c.handleEvaluate();
      expect(c.handleKeyDown('ArrowLeft'), isFalse);
      expect(c.caretVisible, isFalse);
    });

    test('a tap places the caret', () {
      final c = make();
      type(c, '2^3');
      c.exitGroup();
      c.placeCaret(const CaretHit([1], 0));
      expect(c.caretInGroup, isTrue);
      c.handleInput('1');
      expect(c.expression, '2^13');
    });

    test('plain arithmetic shows no caret', () {
      final c = make();
      type(c, '12+3');
      expect(c.caretVisible, isFalse);
    });

    test('the caret shows once the expression has a power', () {
      final c = make();
      type(c, '2^3');
      c.exitGroup();
      expect(c.caretVisible, isTrue);
    });
  });

  group('backspace', () {
    test('walks out of a power one step at a time', () {
      final c = make();
      type(c, 'x^2');
      c.handleBackspace();
      expect(c.expression, 'x^');
      c.handleBackspace(); // the empty superscript goes
      expect(c.expression, 'x');
      c.handleBackspace();
      expect(c.expression, '0');
    });

    test('a finished power is entered before it is deleted', () {
      final c = make();
      c.handleInput('x');
      c.handleInput('^2');
      c.handleBackspace();
      expect(c.caretInGroup, isTrue);
      expect(c.expression, 'x^2');
      c.handleBackspace();
      expect(c.expression, 'x^');
    });
  });

  group('paste', () {
    test('Unicode superscripts and subscripts', () {
      final c = make();
      expect(c.handlePaste('x²'), isTrue);
      expect(c.expression, 'x^2');
      expect(c.handlePaste('x⁻¹'), isTrue);
      expect(c.expression, 'x^(−1)');
      expect(c.handlePaste('H₂O'), isTrue);
      expect(c.expression, 'H_2O');
    });

    test('^ and _ in pasted text make groups', () {
      final c = make();
      expect(c.handlePaste('2^(3+x)'), isTrue);
      expect(c.doc.hasGroups, isTrue);
      expect(c.expression, '2^(3+x)');
    });
  });

  group('history keeps the look', () {
    test('an entry with a power stores its tree, a plain one does not', () {
      final c = make();
      type(c, '2^3+4');
      c.handleEvaluate();
      expect(added.single.expression, '2^(3+4)');
      expect(added.single.rich, isNotNull);
      expect(ExprDoc.fromJson(added.single.rich)!.linear, '2^(3+4)');

      final d = make();
      type(d, '1+1');
      d.handleEvaluate();
      expect(added.last.rich, isNull);
    });

    test('stepping to an entry brings back the tree', () {
      final c = make();
      type(c, '2^3+4');
      c.handleEvaluate();
      final entry = added.single;
      final item = HistoryItem(
        id: 'a',
        expression: entry.expression,
        result: entry.result,
        timestamp: 1,
        rich: entry.rich,
      );
      final d = make(history: [item]);
      d.handleHistoryStep(1);
      expect(d.expression, '2^(3+4)');
      expect(d.doc.root, ExprDoc.fromJson(entry.rich)!.root);
    });

    test('an entry saved before the editor loads from its text', () {
      final item = HistoryItem(id: 'a', expression: 'x^2+1', result: '2', timestamp: 1);
      final c = make(history: [item]);
      c.handleHistoryStep(1);
      expect(c.expression, 'x^2+1');
      expect(c.doc.hasGroups, isTrue);
    });

    test('a saved tree that no longer matches its text is ignored', () {
      final item = HistoryItem(
        id: 'a',
        expression: 'x^2',
        result: '2',
        timestamp: 1,
        rich: ExprDoc.fromLinear('y^3').toJson(),
      );
      final c = make(history: [item]);
      c.handleHistoryStep(1);
      expect(c.expression, 'x^2');
    });
  });

  test('copy gives the plain linear string', () async {
    String? copied;
    final c = CalculatorController(feedback: feedback, clipboard: (t) async => copied = t);
    for (final ch in '2^3'.split('')) {
      c.handleInput(ch);
    }
    await c.handleCopy();
    expect(copied, '2^3');
  });
}
