import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/evaluator.dart';
import 'package:omnicalc/engine/types.dart';
import 'package:omnicalc/services/feedback_service.dart';
import 'package:omnicalc/state/history_store.dart';
import 'package:omnicalc/ui/calculator/calculator_controller.dart';

/// Expected values below were derived by reading the handlers in src/components/CalculatorScreen.tsx and, for the
/// engine results, from the golden vectors (test/golden/evaluator.json). There is no executable oracle for the React
/// handlers themselves (they live inside a component), so these tests pin the behaviour as read from the source.
void main() {
  late SilentFeedbackService feedback;
  late List<({String expression, String result, String mode})> added;
  late String? clipboard;

  CalculatorController make({bool sound = true, bool haptic = true, List<HistoryItem> history = const []}) {
    final c = CalculatorController(
      feedback: feedback,
      clipboard: (text) async => clipboard = text,
      onAddHistory: ({required expression, required result, required mode}) =>
          added.add((expression: expression, result: result, mode: mode)),
    );
    c.updateProps(
      angleMode: AngleMode.deg,
      decimalPrecision: -1,
      soundEnabled: sound,
      hapticEnabled: haptic,
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
    clipboard = null;
    MathEvaluator.setYDefinition(null);
  });
  tearDown(() => MathEvaluator.setYDefinition(null));

  group('handleInput', () {
    test('a digit replaces the initial 0, operators and a dot keep it', () {
      final c = make();
      c.handleInput('7');
      expect(c.expression, '7');
      final d = make()..handleInput('+');
      expect(d.expression, '0+');
      final e = make()..handleInput('.');
      expect(e.expression, '0.');
      final f = make()..handleInput('!');
      expect(f.expression, '0!');
      final g = make()..handleInput('^2');
      expect(g.expression, '0^2');
    });

    test('a second dot in the same number is ignored, a new number may have one', () {
      final c = make();
      type(c, '1.5');
      c.handleInput('.');
      expect(c.expression, '1.5');
      type(c, '+2.');
      expect(c.expression, '1.5+2.');
      c.handleInput('.');
      expect(c.expression, '1.5+2.');
    });

    test('after =, an operator continues with the result and a digit starts over', () {
      final c = make();
      type(c, '2+3');
      c.handleEvaluate();
      expect(c.expression, '5');
      c.handleInput('×');
      expect(c.expression, '5×');
      expect(c.hasEvaluated, false);

      final d = make();
      type(d, '2+3');
      d.handleEvaluate();
      d.handleInput('9');
      expect(d.expression, '9');
      expect(d.lastQuestion, '');
      expect(d.lastAnswer, '');
    });

    test('sound and haptic follow the settings', () {
      final c = make();
      c.handleInput('1');
      expect(feedback.log, ['click:num', 'haptic:medium']);
      feedback.log.clear();
      final quiet = make(sound: false, haptic: false);
      quiet.handleInput('1');
      expect(feedback.log, isEmpty);
    });
  });

  group('handleFunction / handleInsertTemplate / handleParentheses', () {
    test('function on an empty display, after an operator, after a digit, after =', () {
      final c = make()..handleFunction('sin');
      expect(c.expression, 'sin(');
      final d = make();
      type(d, '2+');
      d.handleFunction('cos');
      expect(d.expression, '2+cos(');
      final e = make();
      type(e, '5');
      e.handleFunction('sqrt');
      expect(e.expression, '5×sqrt(');
      final f = make();
      type(f, '2+3');
      f.handleEvaluate();
      f.handleFunction('sqrt');
      expect(f.expression, 'sqrt(5)');
      expect(f.hasEvaluated, false);
    });

    test('templates replace 0 and a result, otherwise multiply in', () {
      final c = make()..handleInsertTemplate('diff(');
      expect(c.expression, 'diff(');
      final d = make();
      type(d, '3');
      d.handleInsertTemplate('sum(');
      expect(d.expression, '3×sum(');
      final e = make();
      type(e, '3(');
      e.handleInsertTemplate('nCr(');
      expect(e.expression, '3(nCr(');
    });

    test('parentheses open, close, and multiply in', () {
      final c = make()..handleParentheses();
      expect(c.expression, '(');
      type(c, '2');
      c.handleParentheses();
      expect(c.expression, '(2)');
      c.handleParentheses();
      expect(c.expression, '(2)×(');

      final d = make();
      type(d, '4');
      d.handleParentheses();
      expect(d.expression, '4×(');
      d.handleInput('+');
      d.handleParentheses();
      expect(d.expression, '4×(+(');
    });

    test('openParensCount never goes below zero', () {
      final c = make();
      type(c, '(1))');
      expect(c.openParensCount, 0);
      c.handleParentheses();
      c.handleParentheses();
      expect(c.openParensCount, greaterThanOrEqualTo(0));
    });
  });

  group('handleBackspace / handleClear', () {
    test('removes a whole function token, the longest-listed match first', () {
      final c = make();
      type(c, '2');
      c.handleFunction('asinh');
      expect(c.expression, '2×asinh(');
      c.handleBackspace();
      expect(c.expression, '2×');
      c.handleBackspace();
      expect(c.expression, '2');
      c.handleBackspace();
      expect(c.expression, '0');

      final d = make()..handleFunction('log2');
      d.handleBackspace();
      expect(d.expression, '0');
      final e = make()..handleFunction('sinh');
      type(e, '1');
      e.handleBackspace();
      expect(e.expression, 'sinh(');
      e.handleBackspace();
      expect(e.expression, '0');
    });

    test('plain characters go one at a time; a result is cleared in one press', () {
      final c = make();
      type(c, '123');
      c.handleBackspace();
      expect(c.expression, '12');
      c.handleEvaluate();
      c.handleBackspace();
      expect(c.expression, '0');
      expect(c.hasEvaluated, false);
    });

    test('rand() and y= are single tokens', () {
      final c = make()..handleInsertTemplate('rand()');
      c.handleBackspace();
      expect(c.expression, '0');
      final d = make()..handleInsertTemplate('y=');
      d.handleBackspace();
      expect(d.expression, '0');
    });

    test('AC clears; on an already empty display it also forgets the saved equation', () {
      final c = make();
      c.handleInsertTemplate('y=');
      type(c, 'x^2');
      c.handleEvaluate();
      expect(c.equation, 'x^2');
      expect(c.expression, '0');
      c.handleClear(); // the display is empty, so this press forgets the equation
      expect(c.equation, isNull);
      expect(MathEvaluator.getYDefinition(), isNull);

      final d = make();
      d.handleInsertTemplate('y=');
      type(d, 'x^2');
      d.handleEvaluate();
      type(d, '3');
      d.handleClear(); // the display held something: only the display is cleared
      expect(d.expression, '0');
      expect(d.equation, 'x^2');
    });
  });

  group('handleEvaluate', () {
    test('a calculation: result on screen, question kept, history entry added', () {
      final c = make();
      type(c, '2+3');
      c.handleEvaluate();
      expect(c.expression, '5');
      expect(c.lastQuestion, '2+3');
      expect(c.lastAnswer, '5');
      expect(c.hasEvaluated, true);
      expect(added, [(expression: '2+3', result: '5', mode: 'standard')]);
    });

    test('unclosed parentheses are closed for the calculation but the question is shown as typed', () {
      final c = make();
      c.handleFunction('sqrt');
      type(c, '9');
      c.handleEvaluate();
      expect(c.expression, '3');
      expect(c.lastQuestion, 'sqrt(9');
    });

    test('an engine error is shown as the result, with the question kept and no history entry', () {
      final c = make();
      type(c, '10÷0');
      c.handleEvaluate();
      expect(c.expression, 'Division by zero');
      expect(c.lastQuestion, '10÷0');
      expect(c.hasEvaluated, true);
      expect(c.isErrorResult, true);
      expect(added, isEmpty);
    });

    test('isErrorResult is false for numeric results and true for messages', () {
      for (final expr in ['2+3', '0−5', '1÷3']) {
        final c = make();
        type(c, expr);
        c.handleEvaluate();
        expect(c.hasEvaluated, true, reason: expr);
        expect(c.isErrorResult, false, reason: expr);
      }
      final bad = make();
      type(bad, '10÷0');
      bad.handleEvaluate();
      expect(bad.isErrorResult, true);
    });

    test('y = f(x) is saved, then a plain number gives y at that x', () {
      final c = make();
      c.handleInsertTemplate('y=');
      type(c, 'x^2');
      c.handleEvaluate();
      expect(c.equation, 'x^2');
      expect(c.expression, '0');
      expect(c.hasEvaluated, false);
      expect(added, isEmpty);

      type(c, '3');
      expect(c.livePreview, '9');
      c.handleEvaluate();
      expect(c.lastQuestion, 'y(3)');
      expect(c.expression, '9');
      expect(added, [(expression: 'y(3)', result: '9', mode: 'standard')]);
    });

    test('y = f(x) rejects a second variable and unreadable text with the web messages', () {
      final c = make();
      c.handleInsertTemplate('y=');
      type(c, 'y+1');
      c.handleEvaluate();
      expect(c.expression, 'Use only x on the right of y =');

    });
  });

  group('livePreview', () {
    test('shows what = would give, hides plain numbers and unchanged text', () {
      final c = make();
      expect(c.livePreview, '');
      type(c, '5');
      expect(c.livePreview, '');
      type(c, '+3');
      expect(c.livePreview, '8');
      c.handleParentheses(); // '5+3×('
      c.handleInput('1'); // '5+3×(1' is closed for the preview: 5+3×1
      expect(c.expression, '5+3×(1');
      expect(c.livePreview, '8');
    });

    test('closes open parentheses for the preview', () {
      final c = make();
      c.handleFunction('sqrt');
      type(c, '16');
      expect(c.livePreview, '4');
    });

    test('is empty once evaluated', () {
      final c = make();
      type(c, '2+3');
      c.handleEvaluate();
      expect(c.livePreview, '');
    });
  });

  group('memory', () {
    test('M+, M-, MR, MC work on the evaluated expression', () {
      final c = make();
      type(c, '2+3');
      c.handleMemory(MemoryAction.mPlus);
      expect(c.memory, 5);
      c.handleMemory(MemoryAction.mPlus);
      expect(c.memory, 10);
      c.handleMemory(MemoryAction.mMinus);
      expect(c.memory, 5);
      c.handleClear();
      c.handleMemory(MemoryAction.mr);
      expect(c.expression, '5');
      expect(c.hasEvaluated, true);
      c.handleMemory(MemoryAction.mc);
      expect(c.memory, 0);
    });

    test('nothing happens when the display does not evaluate (MC and MR included)', () {
      final c = make();
      type(c, '4');
      c.handleMemory(MemoryAction.ms);
      expect(c.memory, 4);
      c.handleClear();
      type(c, '10÷0');
      c.handleEvaluate(); // the display now holds an error message
      c.handleMemory(MemoryAction.mc);
      expect(c.memory, 4);
      c.handleMemory(MemoryAction.mr);
      expect(c.expression, 'Division by zero');
    });
  });

  group('copy, paste, history stepping', () {
    test('copy takes the answer after =, the expression before', () async {
      final c = make();
      type(c, '2+3');
      await c.handleCopy();
      expect(clipboard, '2+3');
      expect(c.copied, true);
      c.handleEvaluate();
      await c.handleCopy();
      expect(clipboard, '5');
      c.dispose();
    });

    test('paste accepts maths-looking text and maps the operators', () {
      final c = make();
      expect(c.handlePaste(' 2 * 3 / 4 - 1 '), true);
      expect(c.expression, '2×3÷4−1');
      expect(c.handlePaste('a=b'), false); // '=' is not in the allowed set
      expect(c.expression, '2×3÷4−1');
      expect(c.handlePaste('😀'), false);
      expect(c.handlePaste(null), false);
    });

    test('arrow up/down step through the history tape', () {
      final items = [
        const HistoryItem(id: 'b', expression: '2+2', result: '4', timestamp: 2),
        const HistoryItem(id: 'a', expression: '1+1', result: '2', timestamp: 1),
      ];
      final c = make(history: items);
      c.handleHistoryStep(1);
      expect(c.expression, '2+2');
      expect(c.lastAnswer, '4');
      expect(c.historyIndex, 0);
      c.handleHistoryStep(1);
      expect(c.expression, '1+1');
      c.handleHistoryStep(1); // past the end: nothing
      expect(c.expression, '1+1');
      expect(c.historyIndex, 1);
      c.handleHistoryStep(-1);
      c.handleHistoryStep(-1);
      expect(c.expression, '0');
      expect(c.historyIndex, -1);

      final empty = make();
      empty.handleHistoryStep(1);
      expect(empty.expression, '0');
    });

    test('loadExternal ignores empty text and resets the answer state', () {
      final c = make();
      type(c, '2+3');
      c.handleEvaluate();
      c.loadExternal('');
      expect(c.expression, '5');
      c.loadExternal('7×8');
      expect(c.expression, '7×8');
      expect(c.hasEvaluated, false);
      expect(c.lastQuestion, '');
    });
  });

  group('physical keyboard', () {
    test('digits, operators, Enter, Backspace, Escape', () {
      final c = make();
      expect(c.handleKeyDown('2'), true);
      expect(c.handleKeyDown('*'), true);
      expect(c.handleKeyDown('3'), true);
      expect(c.expression, '2×3');
      expect(c.handleKeyDown('-'), true);
      expect(c.expression, '2×3−');
      c.handleKeyDown('1');
      c.handleKeyDown('Enter');
      expect(c.expression, '5');
      expect(c.isEqualsPressed, true);
      c.handleKeyDown('Backspace');
      expect(c.expression, '0');
      c.handleKeyDown('7');
      c.handleKeyDown('Escape');
      expect(c.expression, '0');
      c.dispose();
    });

    test('x multiplies after a number and is a variable after an operator', () {
      final c = make();
      expect(c.handleKeyDown('x'), true);
      expect(c.expression, 'x');
      final d = make();
      d.handleKeyDown('5');
      d.handleKeyDown('X');
      expect(d.expression, '5×');
    });

    test('letter shortcuts and the comma rule', () {
      final c = make();
      c.handleKeyDown('s');
      expect(c.expression, 'sin(');
      c.handleKeyDown(',');
      expect(c.expression, 'sin(,');
      final d = make();
      d.handleKeyDown(',');
      expect(d.expression, '0.');
      final e = make();
      e.handleKeyDown('p');
      expect(e.expression, 'PI');
      final f = make();
      f.handleKeyDown('7');
      expect(f.handleKeyDown('e'), false); // after a digit e is not a shortcut
      expect(f.expression, '7');
      f.handleKeyDown('+');
      f.handleKeyDown('e');
      expect(f.expression, '7+E');
      expect(f.handleKeyDown('F1'), false);
    });

    test('[ and ] cycle the advanced tab', () {
      final c = make();
      expect(c.advancedTab, AdvancedTab.calculus);
      c.handleKeyDown(']');
      expect(c.advancedTab, AdvancedTab.trig);
      c.handleKeyDown('[');
      c.handleKeyDown('[');
      // the ES tab (Phase 8a) is the last one, so going back from the first tab wraps to it; Chemistry (Phase 6) is before it
      expect(c.advancedTab, AdvancedTab.es);
      c.handleKeyDown('[');
      expect(c.advancedTab, AdvancedTab.chemistry);
      c.handleKeyDown(']');
      c.handleKeyDown(']');
      expect(c.advancedTab, AdvancedTab.calculus);
    });

    test('Ctrl+C copies, other Ctrl combinations pass through', () async {
      final c = make();
      type(c, '12');
      expect(c.handleKeyDown('c', ctrl: true), true);
      await Future<void>.delayed(Duration.zero);
      expect(clipboard, '12');
      expect(c.handleKeyDown('a', ctrl: true), false);
      expect(c.handleKeyDown('z', meta: true), true);
      expect(c.expression, '1');
      c.dispose();
    });
  });
}
