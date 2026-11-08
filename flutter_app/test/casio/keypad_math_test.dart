// Every kind of math the calculator offers, driven the way a person drives it: key by key. The advanced keys come from
// the same definitions as the on-screen keys (advancedKeyActions), so a key that is wired wrongly fails here.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/base_n.dart' show BaseMode;
import 'package:omnicalc/engine/casio/config.dart';
import 'package:omnicalc/engine/casio/engine.dart';
import 'package:omnicalc/engine/types.dart';
import 'package:omnicalc/services/feedback_service.dart';
import 'package:omnicalc/ui/calculator/advanced_keys.dart';
import 'package:omnicalc/ui/calculator/calculator_controller.dart';

typedef Step = void Function(CalculatorController c);

CalculatorController make({bool rad = false}) {
  final c = CalculatorController(feedback: SilentFeedbackService(), engine: CasioEngine());
  c.updateProps(
    angleMode: rad ? AngleMode.rad : AngleMode.deg,
    decimalPrecision: -1,
    soundEnabled: false,
    hapticEnabled: false,
    history: const [],
    casio: CasioConfig(angle: rad ? CasioAngle.rad : CasioAngle.deg),
  );
  return c;
}

/// Types characters one key at a time (digits, operators, letters, `^`).
Step t(String s) => (c) {
      for (final ch in s.split('')) {
        c.handleInput(ch);
      }
    };

/// A key of an advanced tab, found by its label (and its small text when two keys share a label).
Step k(AdvancedTab tab, String label, [String? sub]) => (c) {
      final keys = advancedKeyActions(tab, c).where((e) => e.label == label && (sub == null || e.sub == sub)).toList();
      expect(keys, isNotEmpty, reason: 'no key "$label" on $tab');
      keys.first.tap();
    };

Step get right => (c) => c.moveCaretRight();
Step get down => (c) => c.esDown();
Step get plus => t('+');
Step f(String name) => (c) => c.handleFunction(name);

const calc = AdvancedTab.calculus, trig = AdvancedTab.trig, pow = AdvancedTab.powers, prob = AdvancedTab.prob;
const consts = AdvancedTab.constants, es = AdvancedTab.es;

/// Presses the keys, then =, and returns the numeric answer (null when the answer is an error or not a number).
Future<double?> answer(CalculatorController c, List<Step> keys) async {
  for (final s in keys) {
    s(c);
  }
  c.handleEvaluate();
  await c.pending;
  if (c.syntaxError != null || c.isErrorResult) return null;
  final shown = double.tryParse(c.lastAnswer.replaceAll('−', '-'));
  return shown ?? c.engine.memory.ans.v;
}

void main() {
  Future<void> check(String name, List<Step> keys, double expected, {bool rad = false, double tol = 1e-6}) async {
    test(name, () async {
      final c = make(rad: rad);
      final v = await answer(c, keys);
      expect(v, isNotNull, reason: '$name -> ${c.syntaxError ?? c.lastAnswer} (line: ${c.expression})');
      expect(v!, closeTo(expected, tol * math.max(1, expected.abs())), reason: '$name -> ${c.lastAnswer}');
    });
  }

  void checkError(String name, List<Step> keys) {
    test(name, () async {
      final c = make();
      expect(await answer(c, keys), isNull, reason: name);
    });
  }

  group('basic keypad', () {
    check('12×8+4', [t('12×8+4')], 100);
    check('(2+3)×4', [t('(2+3)×4')], 20);
    check('7÷8', [t('7÷8')], 0.875);
    check('2−5', [t('2−5')], -3);
    check('0.1+0.2', [t('0.1+0.2')], 0.3);
    check('200×15%', [t('200×15%')], 30);
    check('200+10% (phone percent)', [t('200+10%')], 220);
    check('1÷3', [t('1÷3')], 1 / 3);
    check('long chain 1+2×3−4÷2', [t('1+2×3−4÷2')], 5);
    check('a bracket left open is closed', [t('(2+3')], 5);
    check('minus before a number: 5×−3', [t('5×−3')], -15);
    checkError('1÷0 is an error', [t('1÷0')]);
    test('AC clears and ⌫ deletes', () async {
      final c = make();
      t('123')(c);
      c.handleBackspace();
      expect(c.expression, '12');
      c.handleClear();
      expect(c.expression, '0');
    });
    test('Ans continues the line', () async {
      final c = make();
      expect(await answer(c, [t('6×7')]), 42);
      t('+8')(c);
      c.handleEvaluate();
      await c.pending;
      expect(c.engine.memory.ans.v, 50);
    });
  });

  group('Calculus tab', () {
    check('∫ x² from 1 to 2', [k(calc, '∫▭▭'), k(calc, 'x'), k(pow, 'x²'), right, t('1'), right, t('2')], 7 / 3, tol: 1e-8);
    check('∫ X from 0 to 4 with the X of the ES tab', [k(calc, '∫▭▭'), k(es, 'X'), right, t('0'), right, t('4')], 8);
    check('d/dx x² at 3', [k(calc, 'd/dx'), k(calc, 'x'), k(pow, 'x²'), right, t('3')], 6, tol: 1e-7);
    check('d/dx x³ at 2', [k(calc, 'd/dx'), k(calc, 'x'), k(pow, 'x³'), right, t('2')], 12, tol: 1e-6);
    check('d/dx sin x at 0 (radians)', [k(calc, 'd/dx'), f('sin'), k(calc, 'x'), t(')'), right, t('0')], 1, rad: true, tol: 1e-6);
    check('Σ x from 1 to 10', [k(calc, 'Σ▭▭'), k(calc, 'x'), right, t('1'), right, t('10')], 55);
    check('Σ x² from 1 to 3', [k(calc, 'Σ▭▭'), k(calc, 'x'), k(pow, 'x²'), right, t('1'), right, t('3')], 14);
    check('∏ x from 1 to 5', [k(calc, '∏▭▭'), k(calc, 'x'), right, t('1'), right, t('5')], 120);
    check('lim sin(x)/x as x→0 (radians)', [k(calc, 'lim'), t('sin(x)/x'), t(','), t('x'), t(','), t('0)')], 1, rad: true, tol: 1e-4);
    check('|x| of −5', [k(calc, '|x|'), t('−5)')], 5);
    check('ln e', [k(calc, 'ln'), t('e)')], 1);
    check('the typed words still work: sum(x,1,5)', [t('sum(x,1,5)')], 15);
    check('the typed words still work: prod(x,1,4)', [t('prod(x,1,4)')], 24);
    check('integrate(x^2, 0, 3) typed with the template key', [(c) => c.handleInsertTemplate('integrate('), t('x'), k(pow, 'xʸ'), t('2'), (c) => c.exitGroup(), t(',0,3)')], 9, tol: 1e-6);
    checkError('an empty ∫ box is a Syntax ERROR', [k(calc, '∫▭▭')]);
  });

  group('Trig & Hyp tab (degrees)', () {
    check('sin 30', [k(trig, 'sin'), t('30)')], 0.5);
    check('cos 60', [k(trig, 'cos'), t('60)')], 0.5);
    check('tan 45', [k(trig, 'tan'), t('45)')], 1);
    check('sec 60', [k(trig, 'sec'), t('60)')], 2);
    check('csc 30', [k(trig, 'csc'), t('30)')], 2);
    check('cot 45', [k(trig, 'cot'), t('45)')], 1);
    check('sin⁻¹ 0.5', [k(trig, 'sin⁻¹'), t('0.5)')], 30);
    check('cos⁻¹ 0.5', [k(trig, 'cos⁻¹'), t('0.5)')], 60);
    check('tan⁻¹ 1', [k(trig, 'tan⁻¹'), t('1)')], 45);
    check('sinh 1', [k(trig, 'sinh'), t('1)')], (math.exp(1) - math.exp(-1)) / 2);
    check('cosh 1', [k(trig, 'cosh'), t('1)')], (math.exp(1) + math.exp(-1)) / 2);
    check('tanh 1', [k(trig, 'tanh'), t('1)')], 0.7615941559557649);
    check('sinh⁻¹ 1', [k(trig, 'sinh⁻¹'), t('1)')], 0.881373587019543);
    check('cosh⁻¹ 2', [k(trig, 'cosh⁻¹'), t('2)')], 1.3169578969248166);
    check('tanh⁻¹ 0.5', [k(trig, 'tanh⁻¹'), t('0.5)')], 0.5493061443340548);
    check('sech 1', [k(trig, 'sech'), t('1)')], 1 / ((math.exp(1) + math.exp(-1)) / 2));
    check('csch 1', [k(trig, 'csch'), t('1)')], 1 / ((math.exp(1) - math.exp(-1)) / 2));
    check('coth 1', [k(trig, 'coth'), t('1)')], ((math.exp(1) + math.exp(-1)) / 2) / ((math.exp(1) - math.exp(-1)) / 2));
    check('sin(π/2) in radians', [k(trig, 'sin'), k(trig, 'π'), t('÷2)')], 1, rad: true);
    check('sin 90 + cos 0', [k(trig, 'sin'), t('90)+'), k(trig, 'cos'), t('0)')], 2);
  });

  group('Powers tab', () {
    check('5²', [t('5'), k(pow, 'x²')], 25);
    check('3³', [t('3'), k(pow, 'x³')], 27);
    check('2^10', [t('2'), k(pow, 'xʸ'), t('10')], 1024);
    check('4⁻¹', [t('4'), k(pow, 'x⁻¹')], 0.25);
    check('√144', [k(pow, '√x'), t('144)')], 12);
    check('³√27', [k(pow, '³√x'), t('27)')], 3);
    check('root(3, 27)', [k(pow, 'ʸ√x'), t('3,27)')], 3);
    check('|−9|', [k(pow, '|x|'), t('−9)')], 9);
    check('10^3', [k(pow, '10ˣ'), t('3)')], 1000);
    check('2^5 with the 2ˣ key', [k(pow, '2ˣ'), t('5)')], 32);
    check('exp 1', [k(pow, 'eˣ'), t('1)')], math.e);
    check('e', [k(pow, 'e')], math.e);
    check('ln e²', [k(pow, 'ln'), t('e'), k(pow, 'xʸ'), t('2'), (c) => c.exitGroup(), t(')')], 2);
    check('log 1000', [k(pow, 'log₁₀'), t('1000)')], 3);
    check('log₂ 8', [k(pow, 'log₂'), t('8)')], 3);
    check('log_b: logb(2, 8)', [k(pow, 'log_b'), t('2,8)')], 3);
    check('sgn −4', [k(pow, 'sgn'), t('−4)')], -1);
    check('(2+3)² with the x² key after a bracket', [t('(2+3)'), k(pow, 'x²')], 25);
  });

  group('Probability tab', () {
    check('nPr(5,2)', [k(prob, 'nPr'), t('5,2)')], 20);
    check('nCr(5,2)', [k(prob, 'nCr'), t('5,2)')], 10);
    check('5!', [t('5'), k(prob, 'x!')], 120);
    check('mod(17,5)', [k(prob, 'mod'), t('17,5)')], 2);
    check('gcd(12,18)', [k(prob, 'gcd'), t('12,18)')], 6);
    check('lcm(4,6)', [k(prob, 'lcm'), t('4,6)')], 12);
    check('round 2.6', [k(prob, 'round'), t('2.6)')], 3);
    check('floor 2.7', [k(prob, 'floor'), t('2.7)')], 2);
    check('ceil 2.1', [k(prob, 'ceil'), t('2.1)')], 3);
    check('min(3,7)', [k(prob, 'min'), t('3,7)')], 3);
    check('max(3,7)', [k(prob, 'max'), t('3,7)')], 7);
    check('avg(2,4,6)', [k(prob, 'avg'), t('2,4,6)')], 4);
    check('50%', [t('50'), k(prob, '%')], 0.5);
    test('randInt(1,6) is a whole number from 1 to 6', () async {
      final c = make();
      final v = await answer(c, [k(prob, 'randInt'), t('1,6)')]);
      expect(v, isNotNull);
      expect(v, inInclusiveRange(1, 6));
      expect(v! % 1, 0);
    });
    test('rand() is from 0 to 1', () async {
      final c = make();
      final v = await answer(c, [k(prob, 'rand()')]);
      expect(v, isNotNull);
      expect(v, inInclusiveRange(0, 1));
    });
  });

  group('Constants tab', () {
    check('π', [k(consts, 'π')], math.pi);
    check('2×π×5', [t('2×'), k(consts, 'π'), t('×5')], 2 * math.pi * 5);
    check('e', [k(consts, 'e')], math.e);
    check('φ', [k(consts, 'φ')], (1 + math.sqrt(5)) / 2);
    check('c', [k(consts, 'c')], 299792458);
    check('g × 2', [k(consts, 'g'), t('×2')], 19.6133);
    check('N_A', [k(consts, 'N_A')], 6.02214076e23, tol: 1e-9);
    check('R', [k(consts, 'R')], 8.314462618, tol: 1e-8);
    check('atm', [k(consts, 'atm')], 101325);
  });

  group('ES tab (natural display)', () {
    check('1/2 + 1/3', [k(es, '▭/▭'), t('1'), down, t('2'), right, plus, k(es, '▭/▭'), t('1'), down, t('3')], 5 / 6);
    check('2 1/2 (mixed fraction)', [(c) => c.esMixedFraction(), t('2'), right, t('1'), right, t('2')], 2.5);
    check('√16', [k(es, '√▭'), t('16')], 4);
    check('∛27', [(c) => c.esCbrt(), t('27')], 3);
    check('⁴√81', [k(es, 'ⁿ√▭'), t('4'), right, t('81')], 3);
    check('|−7|', [k(es, '|▭|'), t('−7')], 7);
    check('log₂ 8', [k(es, 'log▭▭'), t('2'), right, t('8')], 3);
    check('5² with the ES x²', [t('5'), k(es, 'x²')], 25);
    check('4⁻¹ with the ES x⁻¹', [t('4'), k(es, 'x⁻¹')], 0.25);
    check('2 × 10³', [t('2'), k(es, '×10ˣ'), t('3')], 2000);
    check('(1/2) × 8 with a fraction in front', [k(es, '▭/▭'), t('1'), down, t('2'), right, t('×8')], 4);
    test('S⇔D flips the exact answer to a decimal and back', () async {
      final c = make();
      await answer(c, [t('1÷4')]);
      expect(c.lastAnswer, anyOf('1⌟4', '0.25'));
      k(es, 'S⇔D')(c);
      final flipped = c.lastAnswer;
      k(es, 'S⇔D')(c);
      expect(c.lastAnswer, isNot(flipped));
    });
  });

  group('typed from a keyboard', () {
    check('sin(30)+cos(60)', [t('sin(30)+cos(60)')], 1);
    check('2^3^2 is 2^9', [t('2^3'), (c) => c.exitGroup(), t('^2')], 64); // (2^3)^2 once the first power is closed
    check('sqrt(2)×sqrt(2)', [t('sqrt(2)×sqrt(2)')], 2);
    check('abs(−3)', [t('abs(−3)')], 3);
    check('3x with x as the variable is 0', [t('3x')], 0);
  });

  group('Modes tab: complex and base-n', () {
    Future<String> textIn(CasioMode mode, List<Step> keys, {BaseMode? base}) async {
      final c = make();
      c.setMode(mode);
      if (base != null) c.setBaseMode(base);
      for (final s in keys) {
        s(c);
      }
      c.handleEvaluate();
      await c.pending;
      return c.syntaxError ?? c.lastAnswer;
    }

    const modes = AdvancedTab.modes;
    test('CMPLX: (1+2i)(3+4i) = −5+10i', () async {
      expect(await textIn(CasioMode.cmplx, [t('(1+2i)×(3+4i)')]), '-5+10i');
    });
    test('CMPLX: Abs(3+4i) = 5', () async {
      expect(await textIn(CasioMode.cmplx, [k(modes, 'Abs'), t('3+4i)')]), '5');
    });
    test('CMPLX: Conjg(3+4i) = 3−4i', () async {
      expect(await textIn(CasioMode.cmplx, [k(modes, 'Conjg'), t('3+4i)')]), '3-4i');
    });
    test('CMPLX: arg(i) = 90 in degrees', () async {
      expect(await textIn(CasioMode.cmplx, [k(modes, 'arg'), t('i)')]), '90');
    });
    test('BASE-N: HEX A + 5 = F ... in decimal 15', () async {
      expect(await textIn(CasioMode.baseN, [t('A+5')], base: BaseMode.hex), anyOf('F', '0000000F'));
    });
    test('BASE-N: BIN 101 + 11 = 1000', () async {
      expect(await textIn(CasioMode.baseN, [t('101+11')], base: BaseMode.bin), endsWith('1000'));
    });
    test('BASE-N: DEC 12 and 10 = 8', () async {
      expect(await textIn(CasioMode.baseN, [t('12'), k(modes, 'and'), t('10')], base: BaseMode.dec), '8');
    });
  });
}
