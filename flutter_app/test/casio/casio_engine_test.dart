// Behaviour of the COMP engine that the manual states in words: formats, forms, ranges, errors, memory (Phase 7b).

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/casio_constants_data.dart';
import 'package:omnicalc/engine/casio/casio_conversions.dart';
import 'package:omnicalc/engine/casio/config.dart';
import 'package:omnicalc/engine/casio/cval.dart';
import 'package:omnicalc/engine/casio/engine.dart';
import 'package:omnicalc/engine/casio/format.dart';

CasioEngine make([CasioConfig cfg = const CasioConfig()]) => CasioEngine(config: cfg);

String shown(String expr, [CasioConfig cfg = const CasioConfig()]) => make(cfg).evaluate(expr).text;

String? err(String expr, [CasioConfig cfg = const CasioConfig()]) {
  try {
    make(cfg).evaluate(expr);
    return null;
  } on CasioError catch (e) {
    return e.message;
  }
}

const rad = CasioConfig(angle: CasioAngle.rad);
const gra = CasioConfig(angle: CasioAngle.gra);

void main() {
  group('number formats (manual p.11-12, p.97)', () {
    test('Norm 1: exponent form below 1e-2 and from 1e10', () {
      expect(shown('0.01'), '0.01');
      expect(shown('0.0099'), '9.9×10⁻³');
      expect(shown('9999999999'), '9999999999');
      expect(shown('10000000000'), '1×10¹⁰');
      expect(shown('1÷3', const CasioConfig(decimalFirst: true)), '0.3333333333');
    });
    test('Norm 2: exponent form below 1e-9 and from 1e10', () {
      const n2 = CasioConfig(numberFormat: CasioNumberFormat.norm2);
      expect(shown('0.0099', n2), '0.0099');
      expect(shown('0.000000001', n2), '0.000000001');
      expect(shown('0.0000000001', n2), '1×10⁻¹⁰');
    });
    test('Fix and Sci', () {
      const fix2 = CasioConfig(numberFormat: CasioNumberFormat.fix, digits: 2);
      expect(shown('2÷3', fix2.copyWith(decimalFirst: true)), '0.67');
      expect(shown('5', fix2), '5.00'); // Fix shows the zeros
      expect(shown('5.5', fix2), '5.50');
      const sci4 = CasioConfig(numberFormat: CasioNumberFormat.sci, digits: 4);
      expect(shown('12345.678', sci4), '1.235×10⁴');
      const sci0 = CasioConfig(numberFormat: CasioNumberFormat.sci, digits: 0);
      expect(shown('1234.5', sci0), '1.234500000×10³'); // Sci 0 is 10 significant digits (zeros shown: UNVERIFIED on a unit)
    });
    test('comma decimal separator', () {
      expect(shown('1.5', const CasioConfig(commaDecimal: true)), '1,5');
    });
    test('ENG shifts the exponent by multiples of 3 (manual p.24-25)', () {
      const f = CasioFormatter(CasioConfig());
      expect(f.eng(1234, 3).display, '1.234×10³');
      expect(f.eng(1234, 0).display, '1234×10⁰');
      expect(f.eng(123, 3).display, '0.123×10³');
      expect(f.eng(123, 6).display, '0.000123×10⁶');
      expect(CasioFormatter.nextEng(0, right: true), 3);
      expect(CasioFormatter.nextEng(3, right: false), 0);
      expect(CasioFormatter.nextEng(0, right: false), -3);
    });
    test('the OmniCalc decimal-places setting still rounds decimal results', () {
      expect(shown('2÷3', const CasioConfig(decimalFirst: true, legacyPrecision: 2)), '0.67');
      expect(shown('1.5', const CasioConfig(legacyPrecision: 4)), '1.5');
    });
  });

  group('result forms (manual p.18-22, p.26-30)', () {
    test('exact integers and decimals never offer another form', () {
      expect(make().evaluate('7').forms.length, 1);
      expect(make().evaluate('0.5+0.5').forms.length, 1);
    });
    test('decimal operands make a decimal result', () {
      expect(shown('0.5+1÷2'), '1');
      expect(make().evaluate('0.5×1÷3').forms.length, 1);
    });
    test('fractions are reduced; mixed form when asked', () {
      expect(shown('6÷8'), '3⌟4');
      expect(shown('7÷6', const CasioConfig(mixedFractions: true)), '1⌟1⌟6');
      expect(shown('−7÷6', const CasioConfig(mixedFractions: true)), '-1⌟1⌟6');
    });
    test('SHIFT S⇔D toggles improper and mixed', () {
      final e = make()..evaluate('7÷6');
      final f = CasioFormatter(e.config);
      expect(f.toggleMixed(e.memory.ans)!.display, '1⌟1⌟6');
      expect(f.toggleMixed(make().evaluate('1÷3').value!), isNull);
    });
    test('a fraction needs at most 10 digits, otherwise a decimal', () {
      expect(shown('1÷123456789'), '8.100000074×10⁻⁹');
      expect(shown('1÷12345'), '1⌟12345');
    });
    test('√ form: two terms, coefficient ranges (p.18-19)', () {
      expect(shown('10√2+15×3√3'), '45√3+10√2');
      expect(shown('99√999'), '3129.089165');
      expect(shown('√2'), '√2');
      expect(shown('1+√3'), '1+√3');
      expect(shown('(√6−√2)÷4'), '(√6-√2)÷4');
      expect(shown('√2+√3+√5'), '5.382332347');
    });
    test('π form: |x| < 1e6', () {
      expect(shown('2π'), '2π');
      expect(shown('π÷6'), 'π÷6');
      expect(shown('100000π'), '100000π');
      expect(shown('1000000π'), '3141592.654'); // 3141592.65 is above 1e6: no π form
      expect(shown('π+1'), '4.141592654');
    });
    test('recurring decimals need Rdec and ≤10 digits (p.26-30)', () {
      final forms = make().evaluate('1÷3').forms.map((f) => f.display).toList();
      expect(forms, ['1⌟3', '0.3̅', '0.3333333333']);
      expect(make(const CasioConfig(recurring: false)).evaluate('1÷3').forms.length, 2);
      expect(make().evaluate('1÷1234567').forms.length, 2); // 1+7+1 over the digit limit... no recurring form
    });
    test('Line IO starts with the decimal and S⇔D cycles decimal → fraction → recurring', () {
      const line = CasioConfig(displayFormat: CasioDisplayFormat.lineIO, decimalFirst: true);
      expect(make(line).evaluate('1÷7').forms.map((f) => f.display).toList(), ['0.1428571429', '1⌟7', '0.1̅4̅2̅8̅5̅7̅']);
    });
    test('DMS', () {
      expect(shown('1°30′0″×2'), '3°0′0″');
      expect(shown('0°0′0.5″'), '0°0′0.5″');
    });
  });

  group('priorities (manual p.96)', () {
    test('level order', () {
      expect(shown('2+3×4'), '14');
      expect(shown('2×3²'), '18');
      expect(shown('−2²'), '-4');
      expect(shown('(−2)²'), '4');
      expect(shown('2^3^2'), '64');
      expect(shown('1÷2π'), '0.1591549431');
      expect(shown('2sin30'), '1');
      expect(shown('sin30cos60'), '1⌟4');
      expect(shown('12÷3×2'), '8');
      expect(shown('6÷2(1+2)'), '1');
      expect(shown('3nCr2+1'), '4');
      expect(shown('2×3nCr2'), '6');
      expect(shown('10−2−3'), '5');
      expect(shown('2^−2'), '1⌟4');
      expect(shown('−3!'), '-6');
      expect(shown('(2+3)!'), '120');
    });
    test('closing parenthesis can be left off only at the end', () {
      expect(shown('sin(30'), '1⌟2');
      expect(err('sin(30+15)×2)'), 'Syntax ERROR');
      expect(err('2×(3+4'), isNull);
    });
  });

  group('input ranges (manual p.98-100): Math ERROR outside', () {
    test('trigonometry per angle unit', () {
      expect(err('sin(9000000000)'), 'Math ERROR');
      expect(err('sin(8999999999)'), isNull);
      expect(err('sin(157079632.7)', rad), 'Math ERROR');
      expect(err('sin(157079632)', rad), isNull);
      expect(err('cos(10000000000)', gra), 'Math ERROR');
      expect(err('tan(90)'), 'Math ERROR');
      expect(err('tan(270)'), 'Math ERROR');
      expect(err('tan(100)', gra), 'Math ERROR');
      expect(err('tan(π÷2)', rad), 'Math ERROR');
      expect(shown('tan(45)'), '1');
      expect(shown('sin(180)'), '0');
      expect(shown('cos(90)'), '0');
    });
    test('inverse functions', () {
      expect(err('asin(1.0000001)'), 'Math ERROR');
      expect(err('acos(−2)'), 'Math ERROR');
      expect(shown('asin(1)'), '90');
      expect(shown('acos(0)'), '90');
      expect(shown('atan(1)'), '45');
      expect(shown('asin(1)', rad), 'π÷2');
      expect(shown('atan(1)', gra), '50');
      expect(err('acosh(0.5)'), 'Math ERROR');
      expect(err('atanh(1)'), 'Math ERROR');
      expect(err('sinh(231)'), 'Math ERROR');
      expect(err('cosh(−231)'), 'Math ERROR');
      expect(err('asinh(5E99)'), 'Math ERROR');
    });
    test('logs, exponentials, roots, powers', () {
      expect(err('ln(0)'), 'Math ERROR');
      expect(err('log(−1)'), 'Math ERROR');
      expect(err('ln(1E100)'), 'Math ERROR');
      expect(err('e^231'), 'Math ERROR');
      expect(shown('e^−1000'), '0');
      expect(err('10^100'), 'Math ERROR');
      expect(shown('10^99'), '1×10⁹⁹');
      expect(err('√(−1)'), 'Math ERROR');
      expect(err('(1E50)²'), 'Math ERROR');
      expect(err('1÷0'), 'Math ERROR');
      expect(err('0^0'), 'Math ERROR');
      expect(err('0^(−1)'), 'Math ERROR');
      expect(err('(−2)^0.5'), 'Math ERROR');
      expect(shown('(−8)^(1÷3)'), '-2');
      expect(err('root(0,5)'), 'Math ERROR');
      expect(shown('root(3,−27)'), '-3');
      expect(err('root(2,−4)'), 'Math ERROR');
      expect(err('log(1,5)'), 'Math ERROR');
    });
    test('factorial, permutations, combinations', () {
      expect(shown('69!'), '1.711224524×10⁹⁸');
      expect(err('70!'), 'Math ERROR');
      expect(err('2.5!'), 'Math ERROR');
      expect(err('(−1)!'), 'Math ERROR');
      expect(err('5nCr6'), 'Math ERROR');
      expect(err('5nPr(−1)'), 'Math ERROR');
      expect(err('100nPr100'), 'Math ERROR'); // 100! is over 1e100
      expect(shown('52nCr5'), '2598960');
    });
    test('results beyond ±9.999999999e99 are an error, below 1e-99 are zero', () {
      expect(err('9E99×10'), 'Math ERROR');
      expect(shown('1E−99÷10'), '0');
      expect(shown('9E99'), '9×10⁹⁹');
    });
    test('Pol, Rec, DMS, RanInt#, GCD, LCM', () {
      expect(err('Rec(−1,30)'), 'Math ERROR');
      expect(err('Pol(1E100,1)'), 'Math ERROR');
      expect(err('GCD(1.5,3)'), 'Argument ERROR');
      expect(err('GCD(10000000000,3)'), 'Argument ERROR');
      expect(err('LCM(−4,6)'), 'Argument ERROR');
      expect(err('RanInt#(5,1)'), 'Argument ERROR');
      expect(err('CONST(41)'), 'Argument ERROR');
      expect(err('CONV(0)'), 'Argument ERROR');
      expect(err('÷'), 'Syntax ERROR');
      expect(err('2+×3'), 'Syntax ERROR');
      expect(err('(2'), isNull);
      expect(err('2)'), 'Syntax ERROR');
    });
  });

  group('÷R (manual p.25-26)', () {
    test('quotient and remainder; only the quotient continues', () {
      final o = make().evaluate('17÷R5');
      expect(o.text, '3');
      expect(o.remainder, '2');
      expect(shown('10+17÷R5'), '13');
    });
    test('becomes ordinary division when it cannot divide with remainder', () {
      expect(shown('1÷R2'), '1⌟2'); // quotient 0
      expect(shown('4÷R2'), '2'); // remainder 0
      expect(shown('5.5÷R2'), '2.75');
      expect(err('5÷R0'), 'Math ERROR');
    });
    test('FACT is not available on a remainder result', () {
      expect(make().evaluate('17÷R5').factorable, isFalse);
      expect(make().evaluate('17÷5').factorable, isFalse);
      expect(make().evaluate('15').factorable, isTrue);
    });
  });

  group('FACT (manual p.30-31)', () {
    test('prime factorization', () {
      final e = make()..evaluate('1014');
      expect(e.factorize(), '2×3×13²');
      e.evaluate('2^10');
      expect(e.factorize(), '2¹⁰');
      e.evaluate('97');
      expect(e.factorize(), '97');
    });
    test('only a positive integer of at most 10 digits', () {
      final e = make();
      e.evaluate('1÷2');
      expect(e.factorize, throwsA(isA<CasioError>()));
      e.evaluate('−6');
      expect(e.factorize, throwsA(isA<CasioError>()));
      e.evaluate('1.5');
      expect(e.factorize, throwsA(isA<CasioError>()));
      e.evaluate('10000000000');
      expect(e.factorize, throwsA(isA<CasioError>()));
      e.evaluate('1');
      expect(e.factorize, throwsA(isA<CasioError>()));
    });
  });

  group('Rnd, multi-statements, memory (manual p.24, p.35, p.46)', () {
    test('Rnd replaces the internal value', () {
      const f3 = CasioConfig(numberFormat: CasioNumberFormat.fix, digits: 3);
      expect(shown('10÷3×3', f3), '10.000');
      expect(shown('Rnd(10÷3)×3', f3), '9.999');
      expect(shown('Rnd(2÷3)', const CasioConfig(decimalFirst: true)), '0.6666666667');
    });
    test('Ans and PreAns', () {
      final e = make();
      e.evaluate('3');
      e.evaluate('4');
      expect(e.evaluate('Ans+PreAns').text, '7');
      expect(e.evaluate('Ans×2').text, '14');
    });
    test('continuing a result keeps its full precision', () {
      final e = make(const CasioConfig(decimalFirst: true));
      expect(e.evaluate('1÷3').text, '0.3333333333');
      // the shown text followed by an operator is Ans, which holds 15 digits: 0.333333333333333 × 3 = 1
      expect(e.evaluate('0.3333333333×3', continuesAns: true).text, '1');
      // typed afresh it is only the 10 digits that were typed
      expect(e.evaluate('0.3333333333×3').text, '0.9999999999');
    });
    test('variables A..F, M, X, Y start at 0', () {
      final e = make();
      expect(e.evaluate('A+B+C+D+F+M+X+Y').text, '0');
      e.memory.vars['A'] = CVal.int(5);
      expect(e.evaluate('A×2').text, '10');
    });
    test('multi-statements show Disp on intermediate results', () {
      final o = make().evaluate('1+1:2+2:3+3');
      expect(o.text, '6');
      expect(o.disp, ['2', '4']);
    });
    test('Pol and Rec store X and Y', () {
      final e = make();
      e.evaluate('Pol(1,1)');
      expect(e.evaluate('X').text, '√2');
      expect(e.evaluate('Y').text, '45');
      e.evaluate('Rec(2,60)');
      expect(e.evaluate('X').text, '1');
      expect(e.evaluate('Y').text, '√3');
    });
  });

  group('exact results', () {
    test('trigonometry of multiples of 15 degrees', () {
      expect(shown('sin30'), '1⌟2');
      expect(shown('cos45'), '√2÷2');
      expect(shown('sin60'), '√3÷2');
      expect(shown('tan60'), '√3');
      expect(shown('sin15'), '(√6-√2)÷4');
      expect(shown('cos(−60)'), '1⌟2');
      expect(shown('sin(210)'), '-1⌟2');
      expect(shown('sin(π÷6)', rad), '1⌟2');
      expect(shown('cos(π)', rad), '-1');
      expect(shown('sin(0.5)', rad), '0.4794255386');
    });
    test('powers, roots, logs', () {
      expect(shown('2^10'), '1024');
      expect(shown('(2÷3)^3'), '8⌟27');
      expect(shown('4^(1÷2)'), '2');
      expect(shown('8^(2÷3)'), '4');
      expect(shown('2^0.5'), '1.414213562');
      expect(shown('√18'), '3√2');
      expect(shown('√(1÷4)'), '1⌟2');
      expect(shown('√(2÷3)'), '√6÷3');
      expect(shown('log(1000)'), '3');
      expect(shown('log(0.01)'), '-2');
      expect(shown('ln(1)'), '0');
      expect(shown('log(2,8)'), '3');
      expect(shown('e^0'), '1');
    });
    test('the decimal approximations stay correct', () {
      expect(shown('0.1+0.2'), '0.3');
      expect(shown('1÷3×3'), '1');
      expect(shown('√2×√2'), '2');
      expect(shown('(√2)^2'), '2');
    });
  });

  group('CONST and CONV (manual p.52-55)', () {
    test('40 constants, CODATA 2014', () {
      expect(kCasioConstants.length, 40);
      expect(shown('CONST(1)'), '1.672621898×10⁻²⁷');
      expect(shown('CONST(6)'), '6.62607004×10⁻³⁴');
      expect(shown('CONST(28)'), '299792458');
      expect(shown('CONST(38)'), '273.15');
      expect(shown('CONST(35)'), '9.80665'); // g
      expect(shown('CONST(39)'), '6.67408×10⁻¹¹'); // G
      expect(shown('CONST(40)'), '101325');
      for (var i = 1; i <= 40; i++) {
        final want = kCasioConstants[i - 1].value;
        expect(make().evaluate('CONST($i)').value!.v, closeTo(want, want.abs() * 1e-14), reason: 'constant $i'); // held with 15 digits
      }
    });
    test('40 conversions, NIST SP 811', () {
      expect(kCasioConversions.length, 40);
      expect(shown('1CONV(1)'), '2.54'); // in → cm
      expect(shown('1CONV(2)'), '0.3937007874'); // cm → in
      expect(shown('100CONV(38)'), '212'); // °C → °F
      expect(shown('212CONV(37)'), '100'); // °F → °C
      expect(shown('1CONV(13)'), '3.785411784'); // gal(US) → l
    });
  });

  group('calculation style and percent', () {
    test('legacy style gives the old results', () {
      const legacy = CasioConfig(useCasio: false);
      expect(shown('√2×√3', legacy), '2.44948974278');
      expect(shown('1÷3', legacy), '0.333333333333');
      expect(shown('10÷4', legacy), '2.5');
      expect(shown('2^3^2', legacy), '512');
      expect(make(legacy).evaluate('1÷3').legacy, isTrue);
    });
    test('legacy functions without a Casio form keep working in both styles', () {
      expect(shown('max(3,1,2)'), '3');
      expect(shown('mean(2,4)'), '3');
      expect(shown('17 mod 5'), '2');
      expect(shown('int(x^2,0,1)'), '0.333333333333');
    });
    test('percent style', () {
      expect(shown('100+10%'), '110');
      expect(shown('200−10%'), '180');
      expect(shown('50%'), '1⌟2');
      expect(make(const CasioConfig(phonePercent: false)).evaluate('100+10%').value!.v, 100.1);
      expect(make(const CasioConfig(phonePercent: false)).evaluate('50%').value!.v, 0.5);
    });
    test('the angle unit mark converts', () {
      expect(shown('sin(90°)', rad), '1');
      expect(make().evaluate('π').forms.map((f) => f.display).toList(), ['π', '3.141592654']);
      expect(shown('180°', rad), 'π');
      expect(shown('90ʳ'), '5156.620156');
    });
  });

  group('STO, E notation, random numbers, templates', () {
    test('STO stores the value; only the quotient of ÷R', () {
      final e = make();
      expect(e.evaluate('5→A').text, '5');
      expect(e.evaluate('A×2').text, '10');
      e.evaluate('5÷R2→X');
      expect(e.memory.vars['X']!.v, 2);
      e.evaluate('7→E');
      expect(e.evaluate('E+1').text, '8');
      expect(err('5→'), 'Syntax ERROR');
      expect(err('5→3'), 'Syntax ERROR');
    });
    test('E notation and the ³√ prefix', () {
      expect(shown('1.5E3'), '1500');
      expect(shown('1e10'), '1×10¹⁰');
      expect(shown('6E−2'), '0.06');
      expect(shown('³√27'), '3');
      expect(shown('³√(−8)'), '-2');
      expect(shown('logb(2,8)'), '3');
    });
    test('Ran# is a 3-digit decimal below 1; RanInt# stays in range', () {
      for (var i = 0; i < 30; i++) {
        final r = make().evaluate('Ran#').value!.v;
        expect(r >= 0 && r < 1, isTrue);
        expect((r * 1000 - (r * 1000).round()).abs() < 1e-9, isTrue);
        final k = make().evaluate('RanInt#(1,6)').value!.v;
        expect(k >= 1 && k <= 6 && k == k.roundToDouble(), isTrue);
      }
    });
  });
}
