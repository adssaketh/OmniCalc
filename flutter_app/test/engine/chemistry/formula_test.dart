import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/calc_error.dart';
import 'package:omnicalc/engine/chemistry/elements.dart';
import 'package:omnicalc/engine/chemistry/formula.dart';

Matcher throwsCalc(String text) =>
    throwsA(isA<CalcError>().having((e) => e.message, 'message', contains(text)));

Map<String, int> counts(ChemFormula f) => {for (final p in f.parts) p.key: p.count};

void main() {
  group('known answers (g/mol)', () {
    // Reference values: standard atomic weights (IUPAC / CIAAW). The app's table uses the rounded weights of
    // Appendix A, so a few hundredths of difference against the 5-digit reference is expected.
    test('H2O 18.015', () => expect(parseFormula('H2O').molarMass, closeTo(18.015, 0.01)));
    test('NaCl 58.44', () => expect(parseFormula('NaCl').molarMass, closeTo(58.44, 0.01)));
    test('Ca(OH)2 74.093', () => expect(parseFormula('Ca(OH)2').molarMass, closeTo(74.093, 0.01)));
    test('Al2(SO4)3 342.15', () => expect(parseFormula('Al2(SO4)3').molarMass, closeTo(342.15, 0.02)));
    test('CuSO4.5H2O 249.685', () => expect(parseFormula('CuSO4.5H2O').molarMass, closeTo(249.685, 0.02)));
  });

  test('molar mass uses exactly the table masses', () {
    for (final e in chemElements) {
      expect(parseFormula(e.symbol).molarMass, e.mass, reason: e.symbol);
    }
    // sum by hand from the table: H2O = 2*1.008 + 15.999
    expect(parseFormula('H2O').molarMass, 2 * 1.008 + 15.999);
  });

  group('typing styles give the same formula', () {
    test('subscripts, brackets', () {
      expect(counts(parseFormula('Al₂(SO₄)₃')), {'Al': 2, 'S': 3, 'O': 12});
      expect(counts(parseFormula('Al2(SO4)3')), {'Al': 2, 'S': 3, 'O': 12});
      expect(counts(parseFormula('Ca(OH)₂')), {'Ca': 1, 'O': 2, 'H': 2});
      expect(counts(parseFormula('K4[Fe(CN)6]')), {'K': 4, 'Fe': 1, 'C': 6, 'N': 6});
      expect(counts(parseFormula('Mg{OH}2')), {'Mg': 1, 'O': 2, 'H': 2});
    });
    test('hydrates: ·, ., *, bullet, and a leading coefficient', () {
      final want = {'Cu': 1, 'S': 1, 'O': 9, 'H': 10};
      expect(counts(parseFormula('CuSO₄·5H₂O')), want);
      expect(counts(parseFormula('CuSO4.5H2O')), want);
      expect(counts(parseFormula('CuSO4*5H2O')), want);
      expect(counts(parseFormula('CuSO4•5H2O')), want);
      expect(parseFormula('CuSO4.5H2O').molarMass, parseFormula('CuSO4·5H₂O').molarMass);
    });
    test('first-appearance order is kept', () {
      expect(parseFormula('C6H12O6').parts.map((p) => p.symbol), ['C', 'H', 'O']);
    });
    test('Mn vs MN style: case decides the symbol', () {
      expect(counts(parseFormula('MnCr')), {'Mn': 1, 'Cr': 1});
      expect(counts(parseFormula('CO')), {'C': 1, 'O': 1});
      expect(counts(parseFormula('Co')), {'Co': 1});
    });
  });

  group('charge', () {
    test('Unicode superscripts', () {
      final f = parseFormula('Fe³⁺');
      expect(f.charge, 3);
      expect(counts(f), {'Fe': 1});
      expect(parseFormula('SO₄²⁻').charge, -2);
      expect(parseFormula('Na⁺').charge, 1);
    });
    test('ASCII forms', () {
      expect(parseFormula('Fe+3').charge, 3);
      expect(parseFormula('SO4^2-').charge, -2);
      expect(parseFormula('SO4 2-').charge, -2);
      expect(parseFormula('Fe^3+').charge, 3);
      expect(parseFormula('Cl-').charge, -1);
      expect(parseFormula('Na+').charge, 1);
      expect(parseFormula('[Fe(CN)6]4-').charge, -4);
      expect(counts(parseFormula('SO4^2-')), {'S': 1, 'O': 4});
    });
    test('Fe3+ means three Fe atoms with charge +1 (digit after a symbol is a subscript)', () {
      final f = parseFormula('Fe3+');
      expect(f.charge, 1);
      expect(counts(f), {'Fe': 3});
    });
    test('display', () {
      expect(parseFormula('SO4^2-').display, 'SO₄²⁻');
      expect(parseFormula('Fe+3').display, 'Fe³⁺');
      expect(parseFormula('Na+').display, 'Na⁺');
      expect(parseFormula('H2O').display, 'H₂O');
    });
  });

  test('isotope: mass number replaces the atomic weight and is flagged', () {
    final f = parseFormula('¹⁴CO2');
    expect(f.hasIsotopes, isTrue);
    expect(f.molarMass, closeTo(14 + 2 * 15.999, 1e-9));
    expect(counts(f), {'14C': 1, 'O': 2});
    expect(parseFormula('^14CO2').molarMass, closeTo(14 + 2 * 15.999, 1e-9));
    expect(parseFormula('CO2').hasIsotopes, isFalse);
  });

  group('errors read like CalcErrors', () {
    test('empty', () => expect(() => parseFormula('  '), throwsCalc('Enter a formula')));
    test('unknown element', () {
      expect(() => parseFormula('Xx2'), throwsCalc('Unknown element "Xx"'));
      expect(() => parseFormula('x2'), throwsCalc('Invalid formula'));
      expect(() => parseFormula('Hx'), throwsCalc('Unknown element "Hx"'));
    });
    test('unbalanced brackets', () {
      expect(() => parseFormula('Ca(OH'), throwsCalc('Unbalanced brackets'));
      expect(() => parseFormula('CaOH)2'), throwsCalc('Unbalanced brackets'));
      expect(() => parseFormula('Ca(OH]2'), throwsCalc('Unbalanced brackets'));
    });
    test('zero subscript, stray characters', () {
      expect(() => parseFormula('H0O'), throwsCalc('subscript of 0'));
      expect(() => parseFormula('H2O#'), throwsCalc('Invalid formula'));
      expect(() => parseFormula('2'), throwsCalc('Invalid formula'));
    });
  });

  test('mass percent composition adds up to 100', () {
    final f = parseFormula('C6H12O6');
    final p = f.massPercents;
    expect(p.reduce((a, b) => a + b), closeTo(100, 1e-9));
    // glucose: C 40.0 %, H 6.71 %, O 53.3 % (textbook values)
    expect(p[0], closeTo(40.0, 0.1));
    expect(p[1], closeTo(6.71, 0.05));
    expect(p[2], closeTo(53.3, 0.1));
    final water = parseFormula('H2O').massPercents;
    expect(water[0], closeTo(11.19, 0.02));
  });

  test('moles <-> grams <-> particles', () {
    expect(molesFromGrams(36.03, 18.015), closeTo(2, 1e-12));
    expect(gramsFromMoles(2, 18.015), closeTo(36.03, 1e-12));
    expect(particlesFromMoles(1), 6.02214076e23);
    expect(molesFromParticles(1.204428152e24), closeTo(2, 1e-9));
    expect(avogadro, 6.02214076e23);
  });

  group('empirical formula', () {
    test('glucose percent data -> CH2O, then C6H12O6 from the molar mass', () {
      final r = empiricalFormula(['C', 'H', 'O'], [40.0, 6.71, 53.3]);
      expect(r.counts, [1, 2, 1]);
      expect(r.multiplier, 1);
      expect(molecularMultiplier(180.16, r.empiricalMass), 6);
    });
    test('Fe 69.94 %, O 30.06 % -> Fe2O3 (needs multiplier 2)', () {
      final r = empiricalFormula(['Fe', 'O'], [69.94, 30.06]);
      expect(r.counts, [2, 3]);
      expect(r.multiplier, 2);
    });
    test('mass data work the same as percent', () {
      expect(empiricalFormula(['Na', 'Cl'], [2.299, 3.545]).counts, [1, 1]);
    });
    test('bad input', () {
      expect(() => empiricalFormula(['C'], []), throwsCalc('amount for every element'));
      expect(() => empiricalFormula(['Zz'], [1]), throwsCalc('Unknown element'));
      expect(() => empiricalFormula(['C', 'H'], [0, 1]), throwsCalc('positive'));
    });
  });
}
