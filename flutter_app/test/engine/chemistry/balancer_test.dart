import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/calc_error.dart';
import 'package:omnicalc/engine/chemistry/balancer.dart';
import 'package:omnicalc/engine/chemistry/formula.dart';
import 'package:omnicalc/engine/chemistry/reference_tables.dart';

Matcher throwsCalc(String text) => throwsA(isA<CalcError>().having((e) => e.message, 'message', contains(text)));

List<int> coefs(String eq) {
  final b = balanceEquation(eq);
  return [...b.reactants.map((s) => s.coefficient), ...b.products.map((s) => s.coefficient)];
}

void main() {
  group('balancer', () {
    test('combustion of propane (C3H8 + O2 -> CO2 + H2O): 1, 5, 3, 4', () {
      expect(coefs('C3H8 + O2 -> CO2 + H2O'), [1, 5, 3, 4]);
    });
    test('Fe2O3 + CO -> Fe + CO2: 1, 3, 2, 3', () {
      expect(coefs('Fe2O3 + CO -> Fe + CO2'), [1, 3, 2, 3]);
    });
    test('redox with charges: permanganate and iron(II) in acid: 1, 5, 8, 1, 5, 4', () {
      expect(coefs('MnO4^- + Fe^2+ + H+ -> Mn^2+ + Fe^3+ + H2O'), [1, 5, 8, 1, 5, 4]);
    });
    test('dichromate and iron(II): 1, 6, 14, 2, 6, 7', () {
      expect(coefs('Cr2O7^2- + Fe^2+ + H+ -> Cr^3+ + Fe^3+ + H2O'), [1, 6, 14, 2, 6, 7]);
    });
    test('KMnO4 + HCl: 2, 16, 2, 2, 8, 5', () {
      expect(coefs('KMnO4 + HCl -> KCl + MnCl2 + H2O + Cl2'), [2, 16, 2, 2, 8, 5]);
    });
    test('Unicode input works', () {
      expect(coefs('H₂ + O₂ → H₂O'), [2, 1, 2]);
      expect(coefs('Al + O2 = Al2O3'), [4, 3, 2]);
    });
    test('coefficients typed by the user are ignored; hydrates work', () {
      expect(coefs('2 H2 + O2 -> 2 H2O'), [2, 1, 2]);
      expect(coefs('CuSO4.5H2O -> CuSO4 + H2O'), [1, 1, 5]);
    });
    test('plus signs without spaces work when no charge is involved', () {
      expect(coefs('H2+O2->H2O'), [2, 1, 2]);
    });
    test('the text shows coefficients and subscripts', () {
      expect(balanceEquation('C3H8 + O2 -> CO2 + H2O').text, 'C₃H₈ + 5 O₂ → 3 CO₂ + 4 H₂O');
      expect(balanceEquation('Fe2O3 + CO -> Fe + CO2').text, 'Fe₂O₃ + 3 CO → 2 Fe + 3 CO₂');
      expect(balanceEquation('MnO4^- + Fe^2+ + H+ -> Mn^2+ + Fe^3+ + H2O').text,
          'MnO₄⁻ + 5 Fe²⁺ + 8 H⁺ → Mn²⁺ + 5 Fe³⁺ + 4 H₂O');
    });
    test('every balanced equation really balances (atoms and charge)', () {
      for (final eq in [
        'C3H8 + O2 -> CO2 + H2O',
        'Fe2O3 + CO -> Fe + CO2',
        'MnO4^- + Fe^2+ + H+ -> Mn^2+ + Fe^3+ + H2O',
        'KMnO4 + HCl -> KCl + MnCl2 + H2O + Cl2',
        'Ca(OH)2 + H3PO4 -> Ca3(PO4)2 + H2O',
        'C6H12O6 + O2 -> CO2 + H2O',
      ]) {
        final b = balanceEquation(eq);
        final left = <String, int>{}, right = <String, int>{};
        var cl = 0, cr = 0;
        for (final s in b.reactants) {
          for (final p in s.formula.parts) {
            left[p.key] = (left[p.key] ?? 0) + p.count * s.coefficient;
          }
          cl += s.formula.charge * s.coefficient;
        }
        for (final s in b.products) {
          for (final p in s.formula.parts) {
            right[p.key] = (right[p.key] ?? 0) + p.count * s.coefficient;
          }
          cr += s.formula.charge * s.coefficient;
        }
        expect(left, right, reason: eq);
        expect(cl, cr, reason: eq);
        expect(b.steps, isNotEmpty);
      }
    });
    test('coefficients are the smallest whole numbers (gcd 1)', () {
      int gcd(int a, int b) => b == 0 ? a : gcd(b, a % b);
      final c = coefs('C6H12O6 + O2 -> CO2 + H2O');
      expect(c, [1, 6, 6, 6]);
      expect(c.reduce(gcd), 1);
    });
    test('errors', () {
      expect(() => balanceEquation(''), throwsCalc('Enter an equation'));
      expect(() => balanceEquation('H2 + O2'), throwsCalc('arrow'));
      expect(() => balanceEquation('H2 -> '), throwsCalc('Both sides'));
      expect(() => balanceEquation('H2 + O2 -> H2O + NaCl'), throwsCalc('appears on only one side'));
      expect(() => balanceEquation('H2 + Xx -> H2O'), throwsCalc('Unknown element'));
      expect(() => balanceEquation('H2 + O2 + H2O2 -> H2O'), throwsCalc('More than one balance'));
      expect(() => balanceEquation('H2 -> O2 -> H2O'), throwsCalc('only one arrow'));
    });
    test('a species on the wrong side has no all-positive balance', () {
      expect(() => balanceEquation('H2O2 + O2 -> H2O'), throwsCalc('wrong side'));
    });
    test('charge mismatch cannot be balanced', () {
      expect(() => balanceEquation('Fe^2+ -> Fe^3+'), throwsCalc('cannot be balanced'));
    });
  });

  group('limiting reagent and yield', () {
    test('N2 + 3 H2 -> 2 NH3 with 10.0 g N2 and 3.0 g H2: N2 limits, 12.16 g NH3, 0.841 g H2 left', () {
      final eq = balanceEquation('N2 + H2 -> NH3');
      expect(eq.reactants.map((s) => s.coefficient), [1, 3]);
      final r = limitingReagent(eq, [10.0, 3.0]);
      expect(r.outputs.first.unit, 'N₂');
      final theo = r.outputs.firstWhere((o) => o.label.startsWith('Theoretical')).value;
      expect(theo, closeTo(12.16, 0.01));
      expect(r.outputs.firstWhere((o) => o.label.contains('H₂ left over')).value, closeTo(0.841, 0.005));
      expect(r.steps.any((s) => s.contains('Limiting reagent: N₂')), isTrue);
    });
    test('percent yield from an actual yield', () {
      final eq = balanceEquation('N2 + H2 -> NH3');
      final r = limitingReagent(eq, [10.0, 3.0], actualGrams: 9.0);
      expect(r.outputs.firstWhere((o) => o.label == 'Percent yield').value, closeTo(9.0 / 12.16 * 100, 0.1));
    });
    test('exact stoichiometric amounts: both reagents limit and nothing is left', () {
      final eq = balanceEquation('N2 + H2 -> NH3');
      final n2 = parseFormula('N2').molarMass;
      final h2 = parseFormula('H2').molarMass;
      final r = limitingReagent(eq, [n2, 3 * h2]);
      expect(r.outputs.first.unit, 'N₂, H₂');
      expect(r.outputs.where((o) => o.label.contains('left over')), isEmpty);
    });
    test('picking the second product', () {
      final eq = balanceEquation('C3H8 + O2 -> CO2 + H2O');
      final r = limitingReagent(eq, [44.0, 200.0], productIndex: 1);
      expect(r.outputs.any((o) => o.label.contains('H₂O')), isTrue);
    });
    test('input checks', () {
      final eq = balanceEquation('N2 + H2 -> NH3');
      expect(() => limitingReagent(eq, [1.0]), throwsCalc('every reactant'));
      expect(() => limitingReagent(eq, [1.0, -2.0]), throwsCalc('positive'));
      expect(() => limitingReagent(eq, [1.0, 2.0], productIndex: 4), throwsCalc('Pick a product'));
      expect(() => limitingReagent(eq, [1.0, 2.0], actualGrams: -1), throwsCalc('Actual yield'));
    });
  });

  group('organic and formula text helpers', () {
    test('degrees of unsaturation from a formula', () {
      expect(degreesOfUnsaturation(parseFormula('C6H6')), 4);
      expect(degreesOfUnsaturation(parseFormula('C2H6O')), 0);
      expect(degreesOfUnsaturation(parseFormula('C3H6O')), 1);
      expect(degreesOfUnsaturation(parseFormula('C2H3Cl')), 1);
      expect(() => degreesOfUnsaturation(parseFormula('NaCl')), throwsCalc('organic'));
      expect(() => degreesOfUnsaturation(parseFormula('H2O')), throwsCalc('carbon'));
    });
    test('molecular formula from the empirical formula and the molar mass', () {
      expect(molecularFormulaText('CH2O', 180.16), 'C₆H₁₂O₆');
      expect(molecularFormulaText('CH', 78.11), 'C₆H₆');
      expect(molecularFormulaText('CH2O', 10), 'CH₂O');
    });
    test('prettyFormula', () {
      expect(prettyFormula('Al2(SO4)3'), 'Al₂(SO₄)₃');
      expect(prettyFormula('CuSO4.5H2O'), 'CuSO₄·5H₂O');
      expect(prettyFormula('SO4^2-'), 'SO₄²⁻');
      expect(prettyFormula('Fe+3'), 'Fe³⁺');
      expect(prettyFormula('H₂O'), 'H₂O');
      expect(prettyFormula('NaCl'), 'NaCl');
    });
  });

  group('reference tables', () {
    test('every polyatomic ion parses and carries the charge written in its formula', () {
      for (final ion in polyatomicIons) {
        final f = parseFormula(ion.formula);
        final m = RegExp(r'\^(\d*)([+-])$').firstMatch(ion.formula)!;
        final n = m[1]!.isEmpty ? 1 : int.parse(m[1]!);
        expect(f.charge, m[2] == '+' ? n : -n, reason: ion.name);
        expect(ion.name, isNotEmpty);
      }
      expect({for (final i in polyatomicIons) i.formula}.length, polyatomicIons.length);
    });
    test('static tables have the right number of columns in every row', () {
      for (final t in staticReferenceTables) {
        expect(t.rows, isNotEmpty, reason: t.id);
        for (final r in t.rows) {
          expect(r.length, t.columns.length, reason: '${t.id}: $r');
        }
      }
    });
    test('common molar masses are computed from the element table', () {
      final rows = commonMolarMassRows();
      expect(rows.length, commonCompounds.length);
      final water = rows.firstWhere((r) => r[0] == 'Water');
      expect(water[1], 'H₂O');
      expect(water[2], '18.015');
      expect(double.parse(rows.firstWhere((r) => r[0] == 'Sodium chloride')[2]), closeTo(58.44, 0.01));
      for (final r in rows) {
        expect(double.parse(r[2]), greaterThan(0));
      }
    });
    test('the electronegativity table is read from the element data, fluorine highest', () {
      final rows = electronegativityRows();
      expect(rows, isNotEmpty);
      final byEn = [...rows]..sort((a, b) => double.parse(b[4]).compareTo(double.parse(a[4])));
      expect(byEn.first[0], 'F');
    });
  });
}
