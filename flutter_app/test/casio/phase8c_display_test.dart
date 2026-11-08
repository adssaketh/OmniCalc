// Phase 8c: recurring-decimal input (A41), stacked fraction results (C01), Linear Display lines for CMPLX and Pol/Rec
// (H10), and SETUP Disp / CONT (A18).

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/editor/nodes.dart';
import 'package:omnicalc/editor/result_doc.dart';
import 'package:omnicalc/engine/casio/config.dart';
import 'package:omnicalc/engine/casio/engine.dart';
import 'package:omnicalc/engine/casio/recurring_input.dart';
import 'package:omnicalc/engine/types.dart';
import 'package:omnicalc/services/feedback_service.dart';
import 'package:omnicalc/state/casio_settings.dart';
import 'package:omnicalc/ui/calculator/calculator_controller.dart';

const String m = CasioRecurringInput.mark;

void main() {
  CalculatorController make([CasioConfig? casio]) {
    final c = CalculatorController(feedback: SilentFeedbackService(), engine: CasioEngine());
    c.updateProps(
      angleMode: AngleMode.deg,
      decimalPrecision: -1,
      soundEnabled: false,
      hapticEnabled: false,
      history: const [],
      casio: casio,
    );
    return c;
  }

  void type(CalculatorController c, String s) {
    for (final ch in s.split('')) {
      c.handleInput(ch);
    }
  }

  group('A41 recurring-decimal input', () {
    String period(String digits) => digits.split('').map((d) => '$d$m').join();

    test('manual p.26: 0.3̅ = 1/3, 1.428571̅ = 10/7, 12.312̅ (period 312) = 4100/333', () {
      expect(CasioRecurringInput.expand('0.${period('3')}'), '(3÷9)');
      expect(CasioRecurringInput.expand('1.${period('428571')}'), '(1428570÷999999)');
      expect(CasioRecurringInput.expand('12.${period('312')}'), '(12300÷999)');
    });

    test('digits before the period stay non-repeating: 0.12 3̅ is 37/300', () {
      // 0.12333... = (123 - 12) / (100 * 9)
      expect(CasioRecurringInput.expand('0.12${period('3')}'), '(111÷900)');
    });

    test('a period longer than 14 digits is a terminating decimal, text without a mark is untouched', () {
      final long = '1' * 15;
      expect(CasioRecurringInput.expand('0.${period(long)}'), '0.$long');
      expect(CasioRecurringInput.expand('2+3×4'), '2+3×4');
    });

    test('the engine reads it: 0.3̅ shows 1⌟3 and 0.3̅+0.45̅ is 26⌟33 (0.78̅)', () {
      final e = CasioEngine();
      expect(e.evaluate('0.${period('3')}').shown.display, '1⌟3');
      expect(e.evaluate('0.${period('3')}+0.${period('45')}').shown.display, '26⌟33');
    });

    test('the key: SHIFT ×10ˣ then digits marks each digit; DEL removes a digit with its mark', () {
      final c = make();
      type(c, '1');
      c.esRecurring();
      type(c, '428571');
      expect(c.expression, '1.${period('428571')}');
      c.handleBackspace();
      expect(c.expression, '1.${period('42857')}');
      c.handleEvaluate();
      expect(c.lastAnswer, CasioEngine().evaluate('1.${period('42857')}').shown.display);
    });

    test('the key on an empty line types 0.; a plain digit after another key is not part of the period', () {
      final c = make();
      c.handleInput('AC'.isEmpty ? '' : '0');
      c.handleBackspace();
      c.esRecurring();
      type(c, '3');
      expect(c.expression, '0.3$m');
      type(c, '+4');
      expect(c.expression, '0.3$m+4');
    });

    test('Linear Display (LineIO) refuses the key (manual p.26)', () {
      final c = make(const CasioConfig(displayFormat: CasioDisplayFormat.lineIO));
      type(c, '1');
      c.esRecurring();
      type(c, '3');
      expect(c.expression, '13');
    });
  });

  group('C01 stacked fraction result', () {
    test('MathO draws 7⌟6 as a fraction node and 1⌟1⌟6 as a mixed fraction', () {
      final doc = resultDocFor('7⌟6', stacked: true);
      expect(doc.root.single, isA<FracNode>());
      final mixed = resultDocFor('-1⌟1⌟6', stacked: true);
      expect(mixed.root.first, isA<CharNode>());
      expect(mixed.root.last, isA<MixedFracNode>());
      final ins = (mixed.root.last as MixedFracNode).slots;
      expect(ins.map((s) => s.children.map((n) => (n as CharNode).ch).join()), ['1', '1', '6']);
    });

    test('text around a fraction stays text, and a result without the mark or with stacked off is plain', () {
      final doc = resultDocFor('1⌟2+1⌟2i', stacked: true);
      expect(doc.root.whereType<FracNode>().length, 2);
      expect(doc.root.whereType<CharNode>().map((n) => n.ch).join(), '+i');
      expect(resultDocFor('7⌟6', stacked: false).root.every((n) => n is CharNode), isTrue);
      expect(resultDocFor('3.5', stacked: true).root.every((n) => n is CharNode), isTrue);
    });

    test('the controller stacks in MathO and keeps 7⌟6 as text in LineO', () {
      final math = make();
      type(math, '7÷6');
      math.handleEvaluate();
      expect(math.resultDoc.root.single, isA<FracNode>());
      final lineO = make(const CasioConfig(displayFormat: CasioDisplayFormat.lineO));
      type(lineO, '7÷6');
      lineO.handleEvaluate();
      lineO.toggleForm(); // LineO starts a division as a decimal; S⇔D gives the fraction
      expect(lineO.resultDoc.root.every((n) => n is CharNode), isTrue);
      expect(lineO.resultDoc.linear, '7⌟6');
    });
  });

  group('A18 Disp, multiple results', () {
    test('Pol shows r = …, θ = … with a comma, and with a semicolon when Disp is Comma', () {
      final dot = make();
      type(dot, 'Pol(1,1)');
      dot.handleEvaluate();
      expect(dot.resultDoc.linear, 'r = √2, θ = 45');
      expect(dot.lastAnswer, '√2'); // only r continues as Ans
      final comma = make(const CasioConfig(commaDecimal: true));
      type(comma, 'Rec(2,60)');
      comma.handleEvaluate();
      expect(comma.resultDoc.linear, 'X = 1; Y = √3');
    });

    test('a comma result uses a comma as its decimal point and the input still uses a dot', () {
      final c = make(const CasioConfig(commaDecimal: true));
      type(c, '1.5×1');
      expect(c.expression, '1.5×1');
      c.handleEvaluate();
      expect(c.resultDoc.linear, '1,5');
    });

    test('S⇔D keeps the second output', () {
      final c = make();
      type(c, 'Pol(1,1)');
      c.handleEvaluate();
      c.toggleForm();
      expect(c.resultDoc.linear, startsWith('r = 1.414213562'));
      expect(c.resultDoc.linear, endsWith('θ = 45'));
    });
  });

  group('H10 Linear Display lines', () {
    test('LineIO writes Pol on two lines, other display formats keep one', () {
      final c = make(const CasioConfig(displayFormat: CasioDisplayFormat.lineIO));
      type(c, 'Pol(1,1)');
      c.handleEvaluate();
      expect(c.resultLines, ['r = 1.414213562', 'θ = 45']);
      final math = make();
      type(math, 'Pol(1,1)');
      math.handleEvaluate();
      expect(math.resultLines, isEmpty);
    });

    test('LineIO writes a complex result as a and bi on separate lines; a real result stays on one line', () {
      final c = make(const CasioConfig(displayFormat: CasioDisplayFormat.lineIO));
      c.setMode(CasioMode.cmplx);
      type(c, '2+3i');
      c.handleEvaluate();
      expect(c.resultLines.length, 2);
      expect(c.resultLines.first, '2');
      expect(c.resultLines.last, '3i');
      c.handleClear();
      type(c, '2+3');
      c.handleEvaluate();
      expect(c.resultLines, isEmpty);
    });
  });

  group('A18 CONT and Disp settings', () {
    test('contrast and the decimal point are saved and restored, and bad values fall back', () {
      const s = CasioSettings(contrast: 2, commaDecimal: true);
      final back = CasioSettings.fromJson(s.toJson());
      expect(back.contrast, 2);
      expect(back.commaDecimal, isTrue);
      expect(CasioSettings.fromJson(<String, Object?>{'contrast': 99}).contrast, 5);
      expect(CasioSettings.fromJson(<String, Object?>{'contrast': 'x'}).contrast, 5);
      expect(const CasioSettings().contrast, 5);
      expect(const CasioSettings(commaDecimal: true).toConfig(AngleMode.deg, -1).commaDecimal, isTrue);
    });
  });
}
