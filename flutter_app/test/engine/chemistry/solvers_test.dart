import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/calc_error.dart';
import 'package:omnicalc/engine/chemistry/all_solvers.dart';
import 'package:omnicalc/engine/chemistry/chem_constants.dart';
import 'package:omnicalc/engine/chemistry/solver_types.dart';
import 'package:omnicalc/engine/chemistry/solvers_equilibrium.dart';

ChemSolver solver(String id) => allChemSolvers.firstWhere((s) => s.id == id);

ChemResult run(String solverId, String modeId, Map<String, double> v) =>
    solver(solverId).modes.firstWhere((m) => m.id == modeId).run(v);

double val(ChemResult r, String label) => r.outputs.firstWhere((o) => o.label == label).value;

void main() {
  group('structure', () {
    test('ids are unique, groups are known, every mode has inputs, a formula and a label', () {
      final ids = <String>{};
      for (final s in allChemSolvers) {
        expect(ids.add(s.id), isTrue, reason: 'duplicate solver id ${s.id}');
        expect(chemSolverGroups, contains(s.group), reason: s.id);
        expect(s.modes, isNotEmpty, reason: s.id);
        final modeIds = <String>{};
        for (final m in s.modes) {
          expect(modeIds.add(m.id), isTrue, reason: '${s.id}/${m.id}');
          expect(m.inputs, isNotEmpty);
          expect(m.formula, isNotEmpty);
          expect(m.label, isNotEmpty);
          final inputIds = {for (final i in m.inputs) i.id};
          expect(inputIds.length, m.inputs.length, reason: '${s.id}/${m.id} has duplicate input ids');
        }
      }
    });

    test('every group of the list has at least one solver', () {
      for (final g in chemSolverGroups) {
        if (g == 'Stoichiometry') continue; // balancer and limiting reagent are separate tools, plus two numeric solvers
        expect(solversInGroup(g), isNotEmpty, reason: g);
      }
      expect(solversInGroup('Stoichiometry').length, 2);
    });

    test('a missing input is a CalcError that names it', () {
      expect(
        () => solver('ideal_gas').modes.first.run({'n': 1}),
        throwsA(isA<CalcError>().having((e) => e.message, 'message', startsWith('Enter'))),
      );
      expect(
        () => solver('ideal_gas').modes.first.run({'n': 1, 'T': double.nan, 'V': 1}),
        throwsA(isA<CalcError>()),
      );
    });
  });

  group('constants', () {
    test('R flavors and derived values', () {
      expect(rJoule, 8.314462618);
      expect(rLAtm, closeTo(0.082057366, 1e-9));
      expect(rLkPa, 8.314462618);
      expect(rCal, closeTo(1.987204259, 1e-8));
      expect(faraday, closeTo(96485.33212, 1e-4));
    });
    test('the chemistry list has the molar volumes, Kw, water constants and 0 °C', () {
      double byId(String id) => chemConstants.firstWhere((c) => c.id == id).value;
      expect(byId('Vm_273_1atm'), closeTo(22.41397, 1e-4)); // CODATA 2018: 22.41396954
      expect(byId('Vm_273_1bar'), closeTo(22.71095, 1e-4)); // CODATA 2018: 22.71095464
      expect(byId('Kw'), 1e-14);
      expect(byId('c_water'), 4.184);
      expect(byId('Kf_water'), 1.86);
      expect(byId('Kb_water'), 0.512);
      expect(byId('T0'), 273.15);
      expect(byId('atm'), 101325);
      expect(byId('NA'), 6.02214076e23);
      expect(byId('R'), 8.314462618);
      expect({for (final c in chemConstants) c.id}.length, chemConstants.length);
      for (final c in chemConstants) {
        expect(chemConstantCategories, contains(c.category), reason: c.id);
      }
    });
  });

  group('gas laws', () {
    test('ideal gas at 0 °C and 1 atm: 22.414 L/mol', () {
      expect(val(run('ideal_gas', 'v', {'n': 1, 'T': 273.15, 'P': 1}), 'Volume V'), closeTo(22.414, 0.001));
    });
    test('ideal gas: the four modes agree with each other', () {
      final p = val(run('ideal_gas', 'p', {'n': 2, 'T': 300, 'V': 10}), 'Pressure P');
      expect(val(run('ideal_gas', 'v', {'n': 2, 'T': 300, 'P': p}), 'Volume V'), closeTo(10, 1e-9));
      expect(val(run('ideal_gas', 'n', {'P': p, 'V': 10, 'T': 300}), 'Moles n'), closeTo(2, 1e-9));
      expect(val(run('ideal_gas', 't', {'P': p, 'V': 10, 'n': 2}), 'Temperature T'), closeTo(300, 1e-9));
    });
    test('Boyle, Charles, Gay-Lussac, Avogadro, combined', () {
      expect(val(run('boyle', 'p2', {'P1': 1, 'V1': 2, 'V2': 1}), 'P₂'), 2);
      expect(val(run('boyle', 'v2', {'P1': 1, 'V1': 2, 'P2': 4}), 'V₂'), 0.5);
      expect(val(run('charles', 'v2', {'V1': 2, 'T1': 300, 'T2': 600}), 'V₂'), 4);
      expect(val(run('charles', 't2', {'V1': 2, 'T1': 300, 'V2': 1}), 'T₂'), 150);
      expect(val(run('gay_lussac', 'p2', {'P1': 1, 'T1': 300, 'T2': 450}), 'P₂'), closeTo(1.5, 1e-12));
      expect(val(run('avogadro_law', 'v2', {'V1': 5, 'n1': 1, 'n2': 3}), 'V₂'), 15);
      expect(val(run('combined_gas', 'p2', {'P1': 1, 'V1': 2, 'T1': 300, 'V2': 1, 'T2': 600}), 'P₂'), 4);
      expect(val(run('combined_gas', 'v2', {'P1': 1, 'V1': 2, 'T1': 300, 'P2': 2, 'T2': 600}), 'V₂'), 2);
      expect(val(run('combined_gas', 't2', {'P1': 1, 'V1': 2, 'T1': 300, 'P2': 2, 'V2': 2}), 'T₂'), 600);
    });
    test('Dalton: mole fractions and partial pressures add up', () {
      final r = run('dalton', 'from_moles', {'Ptot': 2, 'n1': 1, 'n2': 3, 'n3': 0, 'n4': 0});
      expect(val(r, 'Partial pressure P1'), closeTo(0.5, 1e-12));
      expect(val(r, 'Partial pressure P2'), closeTo(1.5, 1e-12));
      expect(r.outputs.length, 4); // gases 3 and 4 are skipped
      expect(val(run('dalton', 'total', {'P1': 0.5, 'P2': 1.5, 'P3': 0, 'P4': 0}), 'P_total'), 2);
    });
    test('Graham: H2 vs O2 effuses 4 times faster', () {
      expect(val(run('graham', 'ratio', {'M1': 2.016, 'M2': 31.998}), 'rate₁ / rate₂'), closeTo(3.984, 0.001));
      expect(val(run('graham', 'm2', {'M1': 4, 'ratio': 2}), 'M₂'), 16);
    });
    test('van der Waals: no attraction and no size gives the ideal gas', () {
      final ideal = val(run('ideal_gas', 'p', {'n': 1, 'T': 300, 'V': 10}), 'Pressure P');
      final vdw = val(run('van_der_waals', 'p', {'n': 1, 'T': 300, 'V': 10, 'a': 0, 'b': 0}), 'Pressure P');
      expect(vdw, closeTo(ideal, 1e-12));
      final p = val(run('van_der_waals', 'p', {'n': 1, 'T': 300, 'V': 1, 'a': 3.64, 'b': 0.04267}), 'Pressure P');
      expect(val(run('van_der_waals', 't', {'P': p, 'n': 1, 'V': 1, 'a': 3.64, 'b': 0.04267}), 'Temperature T'), closeTo(300, 1e-9));
      expect(() => run('van_der_waals', 'p', {'n': 1, 'T': 300, 'V': 0.01, 'a': 1, 'b': 0.04}), throwsA(isA<CalcError>()));
    });
    test('bad input is refused', () {
      expect(() => run('ideal_gas', 'p', {'n': 1, 'T': 0, 'V': 1}), throwsA(isA<CalcError>()));
      expect(() => run('boyle', 'p2', {'P1': 1, 'V1': 1, 'V2': 0}), throwsA(isA<CalcError>()));
    });
  });

  group('solutions', () {
    test('molarity, molality, normality, mole fraction', () {
      expect(val(run('molarity', 'm', {'n': 0.5, 'V': 2}), 'Molarity M'), 0.25);
      expect(val(run('molarity', 'n', {'M': 0.25, 'V': 2}), 'Moles n'), 0.5);
      expect(val(run('molarity', 'v', {'n': 0.5, 'M': 0.25}), 'Volume V'), 2);
      expect(val(run('molality', 'm', {'n': 1, 'kg': 0.5}), 'Molality m'), 2);
      expect(val(run('normality', 'n', {'M': 0.5, 'z': 2}), 'Normality N'), 1);
      final x = run('mole_fraction', 'x', {'n1': 1, 'n2': 9});
      expect(val(x, 'X₁ (solute)'), closeTo(0.1, 1e-12));
      expect(val(x, 'X₂ (solvent)'), closeTo(0.9, 1e-12));
    });
    test('dilution M1V1 = M2V2', () {
      expect(val(run('dilution', 'm2', {'M1': 12, 'V1': 0.05, 'V2': 1}), 'M₂'), closeTo(0.6, 1e-12));
      final r = run('dilution', 'v2', {'M1': 12, 'V1': 0.05, 'M2': 0.6});
      expect(val(r, 'V₂'), closeTo(1, 1e-12));
      expect(val(r, 'Solvent to add'), closeTo(0.95, 1e-12));
      expect(val(run('dilution', 'v1', {'M1': 12, 'M2': 0.6, 'V2': 1}), 'V₁'), closeTo(0.05, 1e-12));
    });
    test('percent and ppm', () {
      expect(val(run('conc_units', 'ww', {'ms': 5, 'msol': 100}), '% w/w'), 5);
      expect(val(run('conc_units', 'wv', {'ms': 5, 'v': 100}), '% w/v'), 5);
      expect(val(run('conc_units', 'vv', {'vs': 40, 'v': 200}), '% v/v'), 20);
      final r = run('conc_units', 'ppm', {'ms': 0.002, 'msol': 1000});
      expect(val(r, 'ppm'), closeTo(2, 1e-9));
      expect(val(r, 'ppb'), closeTo(2000, 1e-6));
      expect(val(run('conc_units', 'convert', {'ppm': 50}), 'Percent (w/w)'), closeTo(0.005, 1e-12));
    });
    test('colligative properties (textbook values)', () {
      expect(val(run('colligative', 'dtf', {'i': 1, 'Kf': 1.86, 'm': 1}), 'ΔTf'), 1.86);
      expect(val(run('colligative', 'dtb', {'i': 2, 'Kb': 0.512, 'm': 1}), 'ΔTb'), closeTo(1.024, 1e-12));
      // 1 M ideal solution at 273.15 K: π = MRT = 22.414 atm
      expect(val(run('colligative', 'osmotic', {'i': 1, 'M': 1, 'T': 273.15}), 'Osmotic pressure π'), closeTo(22.414, 0.001));
      final r = run('colligative', 'raoult', {'X': 0.9, 'P0': 100});
      expect(val(r, 'Solution vapor pressure P'), closeTo(90, 1e-12));
      expect(val(r, 'Lowering ΔP'), closeTo(10, 1e-12));
      expect(() => run('colligative', 'raoult', {'X': 1.2, 'P0': 100}), throwsA(isA<CalcError>()));
    });
  });

  group('acids and bases', () {
    test('pH of 0.01 M HCl = 2', () {
      final r = run('strong_acid_base', 'acid', {'C': 0.01, 'z': 1});
      expect(val(r, 'pH'), closeTo(2, 1e-9));
      expect(val(r, 'pOH'), closeTo(12, 1e-9));
    });
    test('very dilute strong acid includes the water term (1e-8 M gives pH 6.98, not 8)', () {
      expect(val(run('strong_acid_base', 'acid', {'C': 1e-8, 'z': 1}), 'pH'), closeTo(6.978, 0.001));
    });
    test('strong base', () {
      expect(val(run('strong_acid_base', 'base', {'C': 0.01, 'z': 1}), 'pH'), closeTo(12, 1e-9));
      expect(val(run('strong_acid_base', 'base', {'C': 0.005, 'z': 2}), 'pH'), closeTo(12, 1e-9));
    });
    test('pH converter, all four entries', () {
      var r = run('ph', 'from_ph', {'pH': 3});
      expect(val(r, '[H⁺]'), closeTo(1e-3, 1e-15));
      expect(val(r, 'pOH'), closeTo(11, 1e-9));
      r = run('ph', 'from_poh', {'pOH': 4});
      expect(val(r, 'pH'), closeTo(10, 1e-9));
      r = run('ph', 'from_h', {'H': 1e-7});
      expect(val(r, 'pH'), closeTo(7, 1e-9));
      r = run('ph', 'from_oh', {'OH': 1e-2});
      expect(val(r, 'pH'), closeTo(12, 1e-9));
    });
    test('weak acid: 0.10 M acetic acid, Ka 1.8e-5 -> pH 2.875, 1.33 % ionized', () {
      final r = run('weak_acid_base', 'acid', {'Ka': 1.8e-5, 'C': 0.1});
      expect(val(r, 'pH'), closeTo(2.8753, 0.001));
      expect(val(r, 'Percent ionization'), closeTo(1.3326, 0.001));
    });
    test('weak base: 0.10 M NH3, Kb 1.8e-5 -> pH 11.125', () {
      expect(val(run('weak_acid_base', 'base', {'Kb': 1.8e-5, 'C': 0.1}), 'pH'), closeTo(11.1247, 0.001));
    });
    test('Henderson–Hasselbalch: equal acid and base gives pH = pKa', () {
      expect(val(run('buffer', 'ph', {'pKa': 4.76, 'A': 0.2, 'HA': 0.2}), 'pH'), closeTo(4.76, 1e-12));
      expect(val(run('buffer', 'ph', {'pKa': 4.76, 'A': 1, 'HA': 0.1}), 'pH'), closeTo(5.76, 1e-12));
      expect(val(run('buffer', 'ratio', {'pKa': 4.76, 'pH': 5.76}), '[A⁻] / [HA]'), closeTo(10, 1e-9));
    });
    test('strong acid titrated by strong base: 25 mL of 0.100 M HCl with 0.100 M NaOH', () {
      double ph(double vb) =>
          val(run('titration', 'sa_sb', {'Ca': 0.1, 'Va': 25, 'Cb': 0.1, 'Vb': vb}), 'pH');
      expect(ph(0), closeTo(1, 1e-9));
      expect(ph(12.5), closeTo(1.477, 0.001));
      expect(ph(25), 7);
      expect(ph(30), closeTo(11.959, 0.001));
      expect(val(run('titration', 'sa_sb', {'Ca': 0.1, 'Va': 25, 'Cb': 0.1, 'Vb': 5}), 'Equivalence volume'), closeTo(25, 1e-9));
    });
    test('weak acid titrated by strong base: 25 mL of 0.100 M acetic acid (Ka 1.8e-5)', () {
      double ph(double vb) => val(run('titration', 'wa_sb', {'Ca': 0.1, 'Va': 25, 'Ka': 1.8e-5, 'Cb': 0.1, 'Vb': vb}), 'pH');
      expect(ph(0), closeTo(2.875, 0.001));
      expect(ph(12.5), closeTo(4.745, 0.001)); // half-equivalence: pH = pKa
      expect(ph(25), closeTo(8.722, 0.002));
      expect(ph(30), closeTo(11.959, 0.001));
    });
    test('Ka, pKa, Kb, Kw', () {
      expect(val(run('kw_pka', 'pka', {'Ka': 1e-5}), 'pKa'), closeTo(5, 1e-12));
      expect(val(run('kw_pka', 'ka', {'pKa': 4.76}), 'Ka'), closeTo(1.7378e-5, 1e-9));
      expect(val(run('kw_pka', 'kb', {'Ka': 1.8e-5}), 'Kb'), closeTo(5.5556e-10, 1e-13));
      expect(val(run('kw_pka', 'kw', {'H': 1e-3, 'Kw': 1e-14}), '[OH⁻]'), closeTo(1e-11, 1e-20));
    });
  });

  group('thermochemistry', () {
    test('q = m c ΔT', () {
      expect(val(run('q_mcdt', 'q', {'m': 100, 'c': 4.184, 'dT': 10}), 'Heat q'), closeTo(4184, 1e-9));
      expect(val(run('q_mcdt', 'm', {'q': 4184, 'c': 4.184, 'dT': 10}), 'Mass m'), closeTo(100, 1e-9));
      expect(val(run('q_mcdt', 'c', {'q': 4184, 'm': 100, 'dT': 10}), 'Specific heat c'), closeTo(4.184, 1e-12));
      expect(val(run('q_mcdt', 'dt', {'q': 4184, 'm': 100, 'c': 4.184}), 'ΔT'), closeTo(10, 1e-9));
    });
    test('coffee-cup calorimetry: warming the solution means an exothermic reaction', () {
      final r = run('calorimetry', 'cup', {'m': 100, 'c': 4.184, 'dT': 6.5, 'n': 0.05});
      expect(val(r, 'q of reaction'), closeTo(-2719.6, 0.1));
      expect(val(r, 'ΔH'), closeTo(-54.392, 0.01));
    });
    test('bomb calorimetry', () {
      final r = run('calorimetry', 'bomb', {'C': 10.5, 'dT': 2, 'n': 0.5});
      expect(val(r, 'q of reaction'), -21);
      expect(val(r, 'ΔU'), -42);
    });
    test('Hess: step factors (negative reverses)', () {
      final r = run('hess', 'sum', {
        'h1': -393.5, 'f1': 1,
        'h2': -283.0, 'f2': -1,
        'h3': 0, 'f3': 0, 'h4': 0, 'f4': 0, 'h5': 0, 'f5': 0,
      });
      expect(val(r, 'ΔH of the reaction'), closeTo(-110.5, 1e-9)); // C + 1/2 O2 -> CO
      expect(
        () => run('hess', 'sum', {'h1': 1, 'f1': 0, 'h2': 1, 'f2': 0, 'h3': 0, 'f3': 0, 'h4': 0, 'f4': 0, 'h5': 0, 'f5': 0}),
        throwsA(isA<CalcError>()),
      );
    });
    test('ΔG = ΔH − TΔS (Haber: −32.96 kJ/mol at 298.15 K) and the crossover temperature', () {
      final r = run('gibbs', 'dg', {'dH': -92.2, 'dS': -198.7, 'T': 298.15});
      expect(val(r, 'ΔG'), closeTo(-32.96, 0.01));
      expect(r.outputs.first.note, 'spontaneous');
      expect(val(run('gibbs', 't', {'dH': -92.2, 'dS': -198.7}), 'Crossover temperature T'), closeTo(464.0, 0.1));
      expect(() => run('gibbs', 't', {'dH': 10, 'dS': -5}), throwsA(isA<CalcError>()));
    });
    test('ΔG° = −RT ln K', () {
      expect(val(run('gibbs', 'dg0', {'K': 1, 'T': 298.15}), 'ΔG°'), closeTo(0, 1e-12));
      expect(val(run('gibbs', 'dg0', {'K': 10, 'T': 298.15}), 'ΔG°'), closeTo(-5.708, 0.001));
      expect(val(run('gibbs', 'k', {'dG': -5.708, 'T': 298.15}), 'K'), closeTo(10, 0.01));
    });
    test('phase change heat', () {
      expect(val(run('phase_change', 'moles', {'n': 2, 'dH': 6.01}), 'Heat q'), closeTo(12.02, 1e-12));
      final r = run('phase_change', 'grams', {'m': 36.03, 'M': 18.015, 'dH': 40.7});
      expect(val(r, 'Heat q'), closeTo(81.4, 1e-9));
    });
  });

  group('kinetics', () {
    test('zero order', () {
      expect(val(run('zero_order', 'a', {'A0': 1, 'k': 0.01, 't': 50}), '[A]'), closeTo(0.5, 1e-12));
      expect(val(run('zero_order', 't', {'A0': 1, 'A': 0.5, 'k': 0.01}), 'Time t'), closeTo(50, 1e-9));
      expect(val(run('zero_order', 'k', {'A0': 1, 'A': 0.5, 't': 50}), 'k'), closeTo(0.01, 1e-12));
      expect(val(run('zero_order', 'half', {'A0': 1, 'k': 0.01}), 'Half-life t½'), closeTo(50, 1e-9));
      expect(() => run('zero_order', 'a', {'A0': 1, 'k': 0.1, 't': 50}), throwsA(isA<CalcError>()));
    });
    test('first order: half-life 30 s, one half-life leaves half', () {
      final k = val(run('first_order', 'k_from_half', {'t12': 30}), 'k');
      expect(k, closeTo(0.023105, 1e-6));
      expect(val(run('first_order', 'half', {'k': k}), 'Half-life t½'), closeTo(30, 1e-9));
      expect(val(run('first_order', 'a', {'A0': 1, 'k': k, 't': 30}), '[A]'), closeTo(0.5, 1e-12));
      expect(val(run('first_order', 't', {'A0': 1, 'A': 0.25, 'k': k}), 'Time t'), closeTo(60, 1e-9));
      expect(val(run('first_order', 'k', {'A0': 1, 'A': 0.25, 't': 60}), 'k'), closeTo(k, 1e-12));
    });
    test('second order', () {
      expect(val(run('second_order', 'half', {'A0': 0.5, 'k': 0.1}), 'Half-life t½'), closeTo(20, 1e-12));
      expect(val(run('second_order', 'a', {'A0': 0.5, 'k': 0.1, 't': 20}), '[A]'), closeTo(0.25, 1e-12));
      expect(val(run('second_order', 't', {'A0': 0.5, 'A': 0.25, 'k': 0.1}), 'Time t'), closeTo(20, 1e-12));
      expect(val(run('second_order', 'k', {'A0': 0.5, 'A': 0.25, 't': 20}), 'k'), closeTo(0.1, 1e-12));
    });
    test('Arrhenius: k doubles between 300 K and 310 K for Ea = 53.6 kJ/mol; the modes agree', () {
      final ea = val(run('arrhenius', 'ea_two', {'k1': 1, 'T1': 300, 'k2': 2, 'T2': 310}), 'Ea');
      expect(ea, closeTo(53.6, 0.05));
      expect(val(run('arrhenius', 'k2', {'k1': 1, 'Ea': ea, 'T1': 300, 'T2': 310}), 'k₂'), closeTo(2, 1e-9));
      expect(val(run('arrhenius', 't2', {'k1': 1, 'k2': 2, 'Ea': ea, 'T1': 300}), 'T₂'), closeTo(310, 1e-6));
      final k = val(run('arrhenius', 'k', {'A': 1e13, 'Ea': 50, 'T': 298.15}), 'k');
      expect(k, closeTo(1e13 * 1.7e-9, 1e13 * 1e-10)); // e^(−20.17) = 1.74e-9
    });
    test('rate law', () {
      expect(val(run('rate_law', 'rate', {'k': 0.5, 'A': 0.2, 'm': 2, 'B': 0.1, 'n': 1}), 'Rate'), closeTo(0.002, 1e-12));
      expect(val(run('rate_law', 'k', {'rate': 0.002, 'A': 0.2, 'm': 2, 'B': 0.1, 'n': 1}), 'k'), closeTo(0.5, 1e-12));
    });
  });

  group('equilibrium', () {
    test('Kc to Kp for N2 + 3 H2 ⇌ 2 NH3 (Δn = −2) and back', () {
      final kp = val(run('kc_kp', 'kp', {'Kc': 0.5, 'T': 500, 'dn': -2}), 'Kp');
      final rt = 0.082057366 * 500;
      expect(kp, closeTo(0.5 / (rt * rt), 1e-9));
      expect(val(run('kc_kp', 'kc', {'Kp': kp, 'T': 500, 'dn': -2}), 'Kc'), closeTo(0.5, 1e-9));
      // Δn = 0: the two constants are equal
      expect(val(run('kc_kp', 'kp', {'Kc': 3.2, 'T': 400, 'dn': 0}), 'Kp'), 3.2);
    });
    test('ICE, quadratic case: N2O4 ⇌ 2 NO2, K = 0.36, start 0.10 M N2O4 -> x = 0.06', () {
      final r = run('ice', 'ice', {'a': 1, 'A0': 0.1, 'b': 0, 'B0': 0, 'c': 2, 'C0': 0, 'd': 0, 'D0': 0, 'K': 0.36});
      expect(val(r, 'Extent x'), closeTo(0.06, 1e-12));
      expect(val(r, '[A] at equilibrium'), closeTo(0.04, 1e-12));
      expect(val(r, '[C] at equilibrium'), closeTo(0.12, 1e-12));
    });
    test('ICE, two reactants: H2 + I2 ⇌ 2 HI, K = 50 from 1.00 M each -> x = 0.7795, [HI] = 1.559', () {
      // K = (2x)^2 / (1-x)^2 = 50  ->  2x/(1-x) = sqrt(50) = 7.07107  ->  x = 7.07107 / 9.07107 = 0.779519
      final r = run('ice', 'ice', {'a': 1, 'A0': 1, 'b': 1, 'B0': 1, 'c': 2, 'C0': 0, 'd': 0, 'D0': 0, 'K': 50});
      expect(val(r, 'Extent x'), closeTo(0.779519, 1e-5));
      expect(val(r, '[C] at equilibrium'), closeTo(1.559038, 1e-5));
    });
    test('ICE: starting with products only runs the reaction in reverse (negative x)', () {
      final r = run('ice', 'ice', {'a': 1, 'A0': 0, 'b': 0, 'B0': 0, 'c': 2, 'C0': 0.2, 'd': 0, 'D0': 0, 'K': 0.36});
      expect(val(r, 'Extent x'), lessThan(0));
      final a = val(r, '[A] at equilibrium');
      final c = val(r, '[C] at equilibrium');
      expect(c * c / a, closeTo(0.36, 1e-9));
    });
    test('ICE returns the exact root for a cubic-type stoichiometry', () {
      final x = iceExtent({'a': 2, 'A0': 1, 'b': 0, 'B0': 0, 'c': 3, 'C0': 0, 'd': 0, 'D0': 0, 'K': 0.5});
      // K = (3x)^3 / (1 - 2x)^2
      expect(27 * x * x * x / ((1 - 2 * x) * (1 - 2 * x)), closeTo(0.5, 1e-9));
    });
    test('ICE input checks', () {
      expect(
        () => run('ice', 'ice', {'a': 1, 'A0': 1, 'b': 0, 'B0': 0, 'c': 0, 'C0': 0, 'd': 0, 'D0': 0, 'K': 1}),
        throwsA(isA<CalcError>().having((e) => e.message, 'm', contains('product'))),
      );
      expect(
        () => run('ice', 'ice', {'a': 1.5, 'A0': 1, 'b': 0, 'B0': 0, 'c': 1, 'C0': 0, 'd': 0, 'D0': 0, 'K': 1}),
        throwsA(isA<CalcError>().having((e) => e.message, 'm', contains('whole'))),
      );
      expect(
        () => run('ice', 'ice', {'a': 1, 'A0': 1, 'b': 0, 'B0': 0, 'c': 1, 'C0': 0, 'd': 0, 'D0': 0, 'K': 0}),
        throwsA(isA<CalcError>()),
      );
    });
    test('Q vs K tells the direction', () {
      Map<String, double> conc(double a, double c) => {'a': 1, 'A0': a, 'b': 0, 'B0': 0, 'c': 1, 'C0': c, 'd': 0, 'D0': 0, 'K': 1};
      expect(run('ice', 'q', conc(2, 1)).message, contains('right'));
      expect(run('ice', 'q', conc(1, 2)).message, contains('left'));
      expect(run('ice', 'q', conc(1, 1)).message, contains('equilibrium'));
      expect(val(run('ice', 'q', conc(2, 1)), 'Q'), 0.5);
    });
  });

  group('electrochemistry', () {
    test('Zn/Cu cell: E° = 1.10 V, ΔG° = −212.3 kJ/mol, K ≈ 1.5e37', () {
      expect(val(run('cell_potential', 'e', {'Ec': 0.34, 'Ea': -0.76}), 'E°cell'), closeTo(1.10, 1e-12));
      expect(val(run('dg_nfe', 'dg', {'n': 2, 'E': 1.10}), 'ΔG'), closeTo(-212.27, 0.01));
      expect(val(run('dg_nfe', 'k', {'n': 2, 'E0': 1.10, 'T': 298.15}), 'K'), closeTo(1.5e37, 0.1e37));
      expect(val(run('dg_nfe', 'e', {'dG': -212.27, 'n': 2}), 'E'), closeTo(1.10, 1e-4));
      expect(val(run('dg_nfe', 'e0', {'n': 2, 'K': 1.5e37, 'T': 298.15}), 'E°'), closeTo(1.10, 0.002));
    });
    test('Nernst: Q = 1 gives E°, a tenfold Q at 25 °C lowers E by 0.0592/n V', () {
      expect(val(run('nernst', 'e', {'E0': 1.10, 'n': 2, 'Q': 1, 'T': 298.15}), 'E'), closeTo(1.10, 1e-12));
      expect(val(run('nernst', 'e', {'E0': 1.10, 'n': 2, 'Q': 10, 'T': 298.15}), 'E'), closeTo(1.10 - 0.0592 / 2, 1e-4));
      expect(val(run('nernst', 'q', {'E0': 1.10, 'E': 1.10 - 0.0592 / 2, 'n': 2, 'T': 298.15}), 'Q'), closeTo(10, 0.02));
    });
    test("Faraday's laws", () {
      expect(val(run('faraday', 'm', {'I': 1, 't': 96485.33212, 'M': 1, 'n': 1}), 'Mass m'), closeTo(1, 1e-9));
      // copper: 2.00 A for 1.00 h
      expect(val(run('faraday', 'm', {'I': 2, 't': 3600, 'M': 63.55, 'n': 2}), 'Mass m'), closeTo(2.3711, 0.001));
      final t = val(run('faraday', 't', {'m': 2.3711, 'I': 2, 'M': 63.55, 'n': 2}), 'Time t');
      expect(t, closeTo(3600, 0.5));
      expect(val(run('faraday', 'i', {'m': 2.3711, 't': 3600, 'M': 63.55, 'n': 2}), 'Current I'), closeTo(2, 0.001));
    });
  });

  group('nuclear', () {
    test('carbon-14: 11460 years is two half-lives (25 % left); the other modes agree', () {
      final r = run('decay', 'n', {'N0': 100, 't': 11460, 't12': 5730});
      expect(val(r, 'Amount remaining N'), closeTo(25, 1e-9));
      expect(val(r, 'Fraction remaining'), closeTo(0.25, 1e-12));
      expect(val(run('decay', 't', {'N0': 100, 'N': 25, 't12': 5730}), 'Time t'), closeTo(11460, 1e-6));
      expect(val(run('decay', 't12', {'N0': 100, 'N': 25, 't': 11460}), 'Half-life t½'), closeTo(5730, 1e-6));
    });
    test('activity: 1 g of Ra-226 (t½ 1600 y) is about 1 Ci', () {
      final nuclei = 6.02214076e23 / 226.025;
      final r = run('activity', 'a', {'N': nuclei, 't12': 1600 * 365.25 * 86400});
      expect(val(r, 'Activity A'), closeTo(3.66e10, 0.1e10));
      expect(val(run('activity', 'n', {'A': 3.66e10, 't12': 1600 * 365.25 * 86400}), 'Number of nuclei N'), closeTo(nuclei, nuclei * 0.01));
    });
    test('binding energy of helium-4: 28.30 MeV, 7.07 MeV per nucleon', () {
      final r = run('binding', 'be', {'Z': 2, 'A': 4, 'm': 4.00260325413});
      expect(val(r, 'Mass defect Δm'), closeTo(0.0303766, 1e-6));
      expect(val(r, 'Binding energy'), closeTo(28.296, 0.005));
      expect(val(r, 'Per nucleon'), closeTo(7.074, 0.002));
      expect(() => run('binding', 'be', {'Z': 5, 'A': 4, 'm': 4}), throwsA(isA<CalcError>()));
    });
  });

  group('quantum and atomic', () {
    test('a 500 nm photon: 2.480 eV, 5.996e14 Hz', () {
      final r = run('photon', 'from_wl', {'wl': 500});
      expect(val(r, 'Frequency f'), closeTo(5.9958e14, 1e10));
      expect(r.outputs.firstWhere((o) => o.label == 'Energy E' && o.unit == 'eV').value, closeTo(2.4797, 0.0005));
      expect(r.outputs.firstWhere((o) => o.unit == 'kJ/mol').value, closeTo(239.2, 0.2));
    });
    test('photon: the three entry points agree', () {
      final a = run('photon', 'from_f', {'f': 5.9958492e14});
      expect(val(a, 'Wavelength λ'), closeTo(500, 0.01));
      final b = run('photon', 'from_ev', {'E': 2.4796837});
      expect(val(b, 'Wavelength λ'), closeTo(500, 0.01));
    });
    test('hydrogen Balmer-alpha: 656.1 nm; Lyman limit; He+ scales with Z²', () {
      expect(val(run('bohr', 'line', {'Z': 1, 'n1': 2, 'n2': 3}), 'Wavelength λ'), closeTo(656.11, 0.05));
      expect(val(run('bohr', 'line', {'Z': 1, 'n1': 2, 'n2': 3}), 'Photon energy'), closeTo(1.8888, 0.001));
      expect(val(run('bohr', 'line', {'Z': 2, 'n1': 2, 'n2': 3}), 'Photon energy'), closeTo(1.8888 * 4, 0.005));
      expect(() => run('bohr', 'line', {'Z': 1, 'n1': 3, 'n2': 2}), throwsA(isA<CalcError>()));
    });
    test('Bohr levels: E1 = −13.606 eV, r1 = 52.92 pm, He+ n = 2', () {
      final r = run('bohr', 'level', {'Z': 1, 'n': 1});
      expect(r.outputs.firstWhere((o) => o.unit == 'eV').value, closeTo(-13.6057, 1e-4));
      expect(val(r, 'Orbit radius rₙ'), closeTo(52.9177, 1e-3));
      expect(run('bohr', 'level', {'Z': 2, 'n': 2}).outputs.firstWhere((o) => o.unit == 'eV').value, closeTo(-13.6057, 1e-4));
    });
    test('de Broglie: electron at 100 V is 122.6 pm; a 0.145 kg ball at 40 m/s is about 1.1e-34 m', () {
      expect(val(run('de_broglie', 'electron', {'V': 100}), 'Wavelength λ'), closeTo(122.64, 0.05));
      expect(val(run('de_broglie', 'wl', {'m': 0.145, 'v': 40}), 'Wavelength λ'), closeTo(1.1424e-34, 1e-37));
      expect(val(run('de_broglie', 'v', {'m': 9.1093837015e-31, 'wl': 1e-9}), 'Speed v'), closeTo(727384.7, 5));
    });
  });

  group('organic helpers', () {
    test('degrees of unsaturation', () {
      expect(val(run('unsaturation', 'dou', {'C': 6, 'H': 6, 'N': 0, 'X': 0}), 'Degrees of unsaturation'), 4); // benzene
      expect(val(run('unsaturation', 'dou', {'C': 2, 'H': 6, 'N': 0, 'X': 0}), 'Degrees of unsaturation'), 0); // ethane
      expect(val(run('unsaturation', 'dou', {'C': 2, 'H': 4, 'N': 0, 'X': 0}), 'Degrees of unsaturation'), 1); // ethene
      expect(val(run('unsaturation', 'dou', {'C': 2, 'H': 3, 'N': 0, 'X': 1}), 'Degrees of unsaturation'), 1); // vinyl chloride
      expect(val(run('unsaturation', 'dou', {'C': 5, 'H': 5, 'N': 1, 'X': 0}), 'Degrees of unsaturation'), 4); // pyridine
    });
    test('molecular formula multiplier', () {
      final r = run('mol_from_emp', 'n', {'M': 180.16, 'Me': 30.026});
      expect(val(r, 'n (rounded)'), 6);
    });
  });
}
