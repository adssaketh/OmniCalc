import 'dart:math' as math;

import 'chem_constants.dart';
import 'solver_types.dart';
import 'solver_util.dart';

// ---------------------------------------------------------------------------------------------------------------
// thermochemistry
// ---------------------------------------------------------------------------------------------------------------

final ChemSolver heatQ = ChemSolver(
  id: 'q_mcdt',
  group: 'Thermochemistry',
  title: 'Heat: q = m·c·ΔT',
  summary: 'Heat absorbed or released when a substance changes temperature.',
  modes: [
    ChemMode(
      id: 'q',
      label: 'Heat q',
      formula: 'q = m · c · ΔT',
      inputs: [inp('m', 'mass m', 'g'), inp('c', 'specific heat c', 'J/(g·K)'), inp('dT', 'temperature change ΔT', 'K or °C')],
      solve: (x) {
        final q = x['m']! * x['c']! * x['dT']!;
        return one('Heat q', q, 'J', [
          'q = m · c · ΔT',
          'q = ${f(x['m']!)} × ${f(x['c']!)} × ${f(x['dT']!)} = ${f(q)} J',
          'q = ${f(q / 1000)} kJ',
        ]);
      },
    ),
    ChemMode(
      id: 'm',
      label: 'Mass m',
      formula: 'm = q / (c · ΔT)',
      inputs: [inp('q', 'heat q', 'J'), inp('c', 'specific heat c', 'J/(g·K)'), inp('dT', 'ΔT', 'K or °C')],
      solve: (x) {
        need(x['c']! != 0 && x['dT']! != 0, 'c and ΔT cannot be 0');
        final m = x['q']! / (x['c']! * x['dT']!);
        return one('Mass m', m, 'g', ['m = q / (c · ΔT)', 'm = ${f(x['q']!)} / (${f(x['c']!)} × ${f(x['dT']!)}) = ${f(m)} g']);
      },
    ),
    ChemMode(
      id: 'c',
      label: 'Specific heat c',
      formula: 'c = q / (m · ΔT)',
      inputs: [inp('q', 'heat q', 'J'), inp('m', 'mass m', 'g'), inp('dT', 'ΔT', 'K or °C')],
      solve: (x) {
        need(x['m']! != 0 && x['dT']! != 0, 'm and ΔT cannot be 0');
        final c = x['q']! / (x['m']! * x['dT']!);
        return one('Specific heat c', c, 'J/(g·K)', ['c = q / (m · ΔT)', 'c = ${f(x['q']!)} / (${f(x['m']!)} × ${f(x['dT']!)}) = ${f(c)} J/(g·K)']);
      },
    ),
    ChemMode(
      id: 'dt',
      label: 'Temperature change ΔT',
      formula: 'ΔT = q / (m · c)',
      inputs: [inp('q', 'heat q', 'J'), inp('m', 'mass m', 'g'), inp('c', 'specific heat c', 'J/(g·K)')],
      solve: (x) {
        need(x['m']! != 0 && x['c']! != 0, 'm and c cannot be 0');
        final d = x['q']! / (x['m']! * x['c']!);
        return one('ΔT', d, 'K', ['ΔT = q / (m · c)', 'ΔT = ${f(x['q']!)} / (${f(x['m']!)} × ${f(x['c']!)}) = ${f(d)} K']);
      },
    ),
  ],
);

final ChemSolver calorimetry = ChemSolver(
  id: 'calorimetry',
  group: 'Thermochemistry',
  title: 'Calorimetry',
  summary: 'Enthalpy or energy change of a reaction from a measured temperature change.',
  modes: [
    ChemMode(
      id: 'cup',
      label: 'Coffee-cup (constant pressure)',
      formula: 'q_rxn = −m · c · ΔT,  ΔH = q_rxn / n',
      inputs: [
        inp('m', 'mass of solution', 'g'),
        inp('c', 'specific heat of solution', 'J/(g·K)', initial: 4.184),
        inp('dT', 'temperature change ΔT', 'K or °C'),
        inp('n', 'moles of reaction n', 'mol'),
      ],
      solve: (x) {
        positive(x['n']!, 'Moles');
        final qs = x['m']! * x['c']! * x['dT']!;
        final qr = -qs;
        final dh = qr / x['n']! / 1000;
        return ChemResult([out('q of reaction', qr, 'J'), out('ΔH', dh, 'kJ/mol')], [
          'q_solution = m · c · ΔT = ${f(x['m']!)} × ${f(x['c']!)} × ${f(x['dT']!)} = ${f(qs)} J',
          'q_rxn = −q_solution = ${f(qr)} J',
          'ΔH = q_rxn / n = ${f(qr)} J / ${f(x['n']!)} mol = ${f(dh)} kJ/mol',
        ]);
      },
    ),
    ChemMode(
      id: 'bomb',
      label: 'Bomb (constant volume)',
      formula: 'q_rxn = −C_cal · ΔT,  ΔU = q_rxn / n',
      inputs: [
        inp('C', 'calorimeter heat capacity', 'kJ/K'),
        inp('dT', 'temperature change ΔT', 'K or °C'),
        inp('n', 'moles burned n', 'mol'),
      ],
      solve: (x) {
        positive(x['n']!, 'Moles');
        final qr = -x['C']! * x['dT']!;
        final du = qr / x['n']!;
        return ChemResult([out('q of reaction', qr, 'kJ'), out('ΔU', du, 'kJ/mol')], [
          'q_rxn = −C_cal · ΔT = −${f(x['C']!)} × ${f(x['dT']!)} = ${f(qr)} kJ',
          'ΔU = q_rxn / n = ${f(qr)} / ${f(x['n']!)} = ${f(du)} kJ/mol',
        ]);
      },
    ),
  ],
);

final ChemSolver hess = ChemSolver(
  id: 'hess',
  group: 'Thermochemistry',
  title: "Hess's law",
  summary: 'ΔH of a reaction as the sum of step enthalpies, each times the factor (and sign) you apply to the step.',
  modes: [
    ChemMode(
      id: 'sum',
      label: 'Sum of up to five steps',
      formula: 'ΔH_rxn = Σ factorᵢ · ΔHᵢ',
      inputs: [
        for (var i = 1; i <= 5; i++) ...[
          inp('h$i', 'step $i ΔH', 'kJ', initial: i <= 2 ? null : 0),
          inp('f$i', 'step $i factor (×, negative to reverse)', '', initial: i <= 2 ? 1 : 0),
        ],
      ],
      solve: (x) {
        var total = 0.0;
        final steps = <String>[];
        for (var i = 1; i <= 5; i++) {
          final h = x['h$i']!, fac = x['f$i']!;
          if (fac == 0) continue;
          total += fac * h;
          steps.add('Step $i: ${f(fac)} × (${f(h)}) = ${f(fac * h)} kJ');
        }
        need(steps.isNotEmpty, 'Use at least one step (factor other than 0)');
        steps.add('ΔH_rxn = ${f(total)} kJ');
        return ChemResult([out('ΔH of the reaction', total, 'kJ')], steps);
      },
    ),
  ],
);

final ChemSolver gibbs = ChemSolver(
  id: 'gibbs',
  group: 'Thermochemistry',
  title: 'Gibbs energy',
  summary: 'ΔG = ΔH − TΔS and ΔG° = −RT ln K.',
  modes: [
    ChemMode(
      id: 'dg',
      label: 'ΔG from ΔH, ΔS, T',
      formula: 'ΔG = ΔH − T·ΔS',
      inputs: [inp('dH', 'ΔH', 'kJ/mol'), inp('dS', 'ΔS', 'J/(mol·K)'), inp('T', 'temperature T', 'K')],
      solve: (x) {
        positive(x['T']!, 'Temperature');
        final tds = x['T']! * x['dS']! / 1000;
        final dg = x['dH']! - tds;
        return ChemResult([
          out('ΔG', dg, 'kJ/mol', note: dg < 0 ? 'spontaneous' : (dg > 0 ? 'not spontaneous' : 'at equilibrium')),
        ], [
          'ΔG = ΔH − T·ΔS',
          'T·ΔS = ${f(x['T']!)} × ${f(x['dS']!)} J/mol = ${f(tds)} kJ/mol',
          'ΔG = ${f(x['dH']!)} − ${f(tds)} = ${f(dg)} kJ/mol',
          dg < 0 ? 'ΔG < 0: spontaneous at this temperature' : (dg > 0 ? 'ΔG > 0: not spontaneous at this temperature' : 'ΔG = 0: at equilibrium'),
        ]);
      },
    ),
    ChemMode(
      id: 't',
      label: 'Temperature where ΔG = 0',
      formula: 'T = ΔH / ΔS',
      inputs: [inp('dH', 'ΔH', 'kJ/mol'), inp('dS', 'ΔS', 'J/(mol·K)')],
      solve: (x) {
        need(x['dS']! != 0, 'ΔS cannot be 0');
        final t = x['dH']! * 1000 / x['dS']!;
        need(t > 0, 'ΔH and ΔS must have the same sign for ΔG = 0 at a positive temperature');
        return one('Crossover temperature T', t, 'K', [
          'ΔG = 0  →  T = ΔH / ΔS',
          'T = (${f(x['dH']!)} × 1000 J) / ${f(x['dS']!)} J/K = ${f(t)} K',
        ]);
      },
    ),
    ChemMode(
      id: 'dg0',
      label: 'ΔG° from K',
      formula: 'ΔG° = −R·T·ln K',
      inputs: [inp('K', 'equilibrium constant K', ''), inp('T', 'temperature T', 'K', initial: 298.15)],
      solve: (x) {
        positive(x['K']!, 'K');
        positive(x['T']!, 'Temperature');
        final dg = -rJoule * x['T']! * math.log(x['K']!) / 1000;
        return one('ΔG°', dg, 'kJ/mol', [
          'ΔG° = −R·T·ln K',
          'ΔG° = −(${f(rJoule)} J/(mol·K) × ${f(x['T']!)} K × ln ${f(x['K']!)}) / 1000 = ${f(dg)} kJ/mol',
        ]);
      },
    ),
    ChemMode(
      id: 'k',
      label: 'K from ΔG°',
      formula: 'K = e^(−ΔG° / RT)',
      inputs: [inp('dG', 'ΔG°', 'kJ/mol'), inp('T', 'temperature T', 'K', initial: 298.15)],
      solve: (x) {
        positive(x['T']!, 'Temperature');
        final k = math.exp(-x['dG']! * 1000 / (rJoule * x['T']!));
        return one('K', finite(k), '', [
          'K = e^(−ΔG° / RT)',
          'K = exp(−(${f(x['dG']!)} × 1000) / (${f(rJoule)} × ${f(x['T']!)})) = ${f(k)}',
        ]);
      },
    ),
  ],
);

final ChemSolver phaseChange = ChemSolver(
  id: 'phase_change',
  group: 'Thermochemistry',
  title: 'Heat of a phase change',
  summary: 'q = n · ΔH(fusion or vaporization) for melting, freezing, boiling or condensing.',
  modes: [
    ChemMode(
      id: 'moles',
      label: 'From moles',
      formula: 'q = n · ΔH_phase',
      inputs: [inp('n', 'moles n', 'mol'), inp('dH', 'ΔH of the phase change', 'kJ/mol')],
      solve: (x) {
        final q = x['n']! * x['dH']!;
        return one('Heat q', q, 'kJ', ['q = n · ΔH', 'q = ${f(x['n']!)} × ${f(x['dH']!)} = ${f(q)} kJ']);
      },
    ),
    ChemMode(
      id: 'grams',
      label: 'From grams',
      formula: 'q = (m / M) · ΔH_phase',
      inputs: [inp('m', 'mass m', 'g'), inp('M', 'molar mass M', 'g/mol'), inp('dH', 'ΔH of the phase change', 'kJ/mol')],
      solve: (x) {
        positive(x['M']!, 'Molar mass');
        final n = x['m']! / x['M']!;
        final q = n * x['dH']!;
        return ChemResult([out('Moles n', n, 'mol'), out('Heat q', q, 'kJ')], [
          'n = m / M = ${f(x['m']!)} / ${f(x['M']!)} = ${f(n)} mol',
          'q = n · ΔH = ${f(n)} × ${f(x['dH']!)} = ${f(q)} kJ',
        ]);
      },
    ),
  ],
);

// ---------------------------------------------------------------------------------------------------------------
// kinetics
// ---------------------------------------------------------------------------------------------------------------

final ChemSolver zeroOrder = ChemSolver(
  id: 'zero_order',
  group: 'Kinetics',
  title: 'Zero-order reaction',
  summary: '[A] = [A]₀ − kt;  t½ = [A]₀ / 2k.',
  modes: [
    ChemMode(
      id: 'a',
      label: 'Concentration [A]',
      formula: '[A] = [A]₀ − k·t',
      inputs: [inp('A0', '[A]₀', 'mol/L'), inp('k', 'k', 'mol/(L·s)'), inp('t', 'time t', 's')],
      solve: (x) {
        final a = x['A0']! - x['k']! * x['t']!;
        need(a >= 0, 'The reactant is used up before this time ([A] would be negative)');
        return one('[A]', a, 'mol/L', ['[A] = [A]₀ − k·t', '[A] = ${f(x['A0']!)} − ${f(x['k']!)} × ${f(x['t']!)} = ${f(a)} mol/L']);
      },
    ),
    ChemMode(
      id: 't',
      label: 'Time t',
      formula: 't = ([A]₀ − [A]) / k',
      inputs: [inp('A0', '[A]₀', 'mol/L'), inp('A', '[A]', 'mol/L'), inp('k', 'k', 'mol/(L·s)')],
      solve: (x) {
        positive(x['k']!, 'k');
        final t = (x['A0']! - x['A']!) / x['k']!;
        return one('Time t', t, 's', ['t = ([A]₀ − [A]) / k', 't = (${f(x['A0']!)} − ${f(x['A']!)}) / ${f(x['k']!)} = ${f(t)} s']);
      },
    ),
    ChemMode(
      id: 'k',
      label: 'Rate constant k',
      formula: 'k = ([A]₀ − [A]) / t',
      inputs: [inp('A0', '[A]₀', 'mol/L'), inp('A', '[A]', 'mol/L'), inp('t', 'time t', 's')],
      solve: (x) {
        positive(x['t']!, 'Time');
        final k = (x['A0']! - x['A']!) / x['t']!;
        return one('k', k, 'mol/(L·s)', ['k = ([A]₀ − [A]) / t', 'k = (${f(x['A0']!)} − ${f(x['A']!)}) / ${f(x['t']!)} = ${f(k)} mol/(L·s)']);
      },
    ),
    ChemMode(
      id: 'half',
      label: 'Half-life t½',
      formula: 't½ = [A]₀ / (2k)',
      inputs: [inp('A0', '[A]₀', 'mol/L'), inp('k', 'k', 'mol/(L·s)')],
      solve: (x) {
        positive(x['k']!, 'k');
        final t = x['A0']! / (2 * x['k']!);
        return one('Half-life t½', t, 's', ['t½ = [A]₀ / (2k)', 't½ = ${f(x['A0']!)} / (2 × ${f(x['k']!)}) = ${f(t)} s']);
      },
    ),
  ],
);

final ChemSolver firstOrder = ChemSolver(
  id: 'first_order',
  group: 'Kinetics',
  title: 'First-order reaction',
  summary: 'ln[A] = ln[A]₀ − kt;  t½ = ln 2 / k.',
  modes: [
    ChemMode(
      id: 'a',
      label: 'Concentration [A]',
      formula: '[A] = [A]₀ · e^(−k·t)',
      inputs: [inp('A0', '[A]₀', 'mol/L'), inp('k', 'k', '1/s'), inp('t', 'time t', 's')],
      solve: (x) {
        final a = x['A0']! * math.exp(-x['k']! * x['t']!);
        return one('[A]', a, 'mol/L', ['[A] = [A]₀ · e^(−kt)', '[A] = ${f(x['A0']!)} × e^(−${f(x['k']!)} × ${f(x['t']!)}) = ${f(a)} mol/L']);
      },
    ),
    ChemMode(
      id: 't',
      label: 'Time t',
      formula: 't = ln([A]₀ / [A]) / k',
      inputs: [inp('A0', '[A]₀', 'mol/L'), inp('A', '[A]', 'mol/L'), inp('k', 'k', '1/s')],
      solve: (x) {
        positive(x['A0']!, '[A]₀');
        positive(x['A']!, '[A]');
        positive(x['k']!, 'k');
        final t = math.log(x['A0']! / x['A']!) / x['k']!;
        return one('Time t', t, 's', ['t = ln([A]₀ / [A]) / k', 't = ln(${f(x['A0']!)} / ${f(x['A']!)}) / ${f(x['k']!)} = ${f(t)} s']);
      },
    ),
    ChemMode(
      id: 'k',
      label: 'Rate constant k',
      formula: 'k = ln([A]₀ / [A]) / t',
      inputs: [inp('A0', '[A]₀', 'mol/L'), inp('A', '[A]', 'mol/L'), inp('t', 'time t', 's')],
      solve: (x) {
        positive(x['A0']!, '[A]₀');
        positive(x['A']!, '[A]');
        positive(x['t']!, 'Time');
        final k = math.log(x['A0']! / x['A']!) / x['t']!;
        return one('k', k, '1/s', ['k = ln([A]₀ / [A]) / t', 'k = ln(${f(x['A0']!)} / ${f(x['A']!)}) / ${f(x['t']!)} = ${f(k)} 1/s']);
      },
    ),
    ChemMode(
      id: 'half',
      label: 'Half-life t½ from k',
      formula: 't½ = ln 2 / k',
      inputs: [inp('k', 'k', '1/s')],
      solve: (x) {
        positive(x['k']!, 'k');
        final t = math.ln2 / x['k']!;
        return one('Half-life t½', t, 's', ['t½ = ln 2 / k', 't½ = 0.693147 / ${f(x['k']!)} = ${f(t)} s']);
      },
    ),
    ChemMode(
      id: 'k_from_half',
      label: 'k from half-life',
      formula: 'k = ln 2 / t½',
      inputs: [inp('t12', 'half-life t½', 's')],
      solve: (x) {
        positive(x['t12']!, 'Half-life');
        final k = math.ln2 / x['t12']!;
        return one('k', k, '1/s', ['k = ln 2 / t½', 'k = 0.693147 / ${f(x['t12']!)} = ${f(k)} 1/s']);
      },
    ),
  ],
);

final ChemSolver secondOrder = ChemSolver(
  id: 'second_order',
  group: 'Kinetics',
  title: 'Second-order reaction',
  summary: '1/[A] = 1/[A]₀ + kt;  t½ = 1 / (k[A]₀).',
  modes: [
    ChemMode(
      id: 'a',
      label: 'Concentration [A]',
      formula: '1/[A] = 1/[A]₀ + k·t',
      inputs: [inp('A0', '[A]₀', 'mol/L'), inp('k', 'k', 'L/(mol·s)'), inp('t', 'time t', 's')],
      solve: (x) {
        positive(x['A0']!, '[A]₀');
        final inv = 1 / x['A0']! + x['k']! * x['t']!;
        positive(inv, '1/[A]');
        final a = 1 / inv;
        return one('[A]', a, 'mol/L', [
          '1/[A] = 1/[A]₀ + k·t = 1/${f(x['A0']!)} + ${f(x['k']!)} × ${f(x['t']!)} = ${f(inv)} L/mol',
          '[A] = ${f(a)} mol/L',
        ]);
      },
    ),
    ChemMode(
      id: 't',
      label: 'Time t',
      formula: 't = (1/[A] − 1/[A]₀) / k',
      inputs: [inp('A0', '[A]₀', 'mol/L'), inp('A', '[A]', 'mol/L'), inp('k', 'k', 'L/(mol·s)')],
      solve: (x) {
        positive(x['A0']!, '[A]₀');
        positive(x['A']!, '[A]');
        positive(x['k']!, 'k');
        final t = (1 / x['A']! - 1 / x['A0']!) / x['k']!;
        return one('Time t', t, 's', ['t = (1/[A] − 1/[A]₀) / k', 't = (1/${f(x['A']!)} − 1/${f(x['A0']!)}) / ${f(x['k']!)} = ${f(t)} s']);
      },
    ),
    ChemMode(
      id: 'k',
      label: 'Rate constant k',
      formula: 'k = (1/[A] − 1/[A]₀) / t',
      inputs: [inp('A0', '[A]₀', 'mol/L'), inp('A', '[A]', 'mol/L'), inp('t', 'time t', 's')],
      solve: (x) {
        positive(x['A0']!, '[A]₀');
        positive(x['A']!, '[A]');
        positive(x['t']!, 'Time');
        final k = (1 / x['A']! - 1 / x['A0']!) / x['t']!;
        return one('k', k, 'L/(mol·s)', ['k = (1/[A] − 1/[A]₀) / t', 'k = (1/${f(x['A']!)} − 1/${f(x['A0']!)}) / ${f(x['t']!)} = ${f(k)} L/(mol·s)']);
      },
    ),
    ChemMode(
      id: 'half',
      label: 'Half-life t½',
      formula: 't½ = 1 / (k·[A]₀)',
      inputs: [inp('A0', '[A]₀', 'mol/L'), inp('k', 'k', 'L/(mol·s)')],
      solve: (x) {
        positive(x['A0']!, '[A]₀');
        positive(x['k']!, 'k');
        final t = 1 / (x['k']! * x['A0']!);
        return one('Half-life t½', t, 's', ['t½ = 1 / (k·[A]₀)', 't½ = 1 / (${f(x['k']!)} × ${f(x['A0']!)}) = ${f(t)} s']);
      },
    ),
  ],
);

final ChemSolver arrhenius = ChemSolver(
  id: 'arrhenius',
  group: 'Kinetics',
  title: 'Arrhenius equation',
  summary: 'k = A·e^(−Ea/RT), and the two-temperature form.',
  modes: [
    ChemMode(
      id: 'k',
      label: 'k from A, Ea, T',
      formula: 'k = A · e^(−Ea / RT)',
      inputs: [inp('A', 'frequency factor A', 'same unit as k'), inp('Ea', 'activation energy Ea', 'kJ/mol'), inp('T', 'temperature T', 'K')],
      solve: (x) {
        positive(x['T']!, 'Temperature');
        final e = -x['Ea']! * 1000 / (rJoule * x['T']!);
        final k = x['A']! * math.exp(e);
        return one('k', finite(k), '', [
          'k = A · e^(−Ea / RT)',
          '−Ea/RT = −(${f(x['Ea']!)} × 1000) / (${f(rJoule)} × ${f(x['T']!)}) = ${f(e)}',
          'k = ${f(x['A']!)} × e^(${f(e)}) = ${f(k)}',
        ]);
      },
    ),
    ChemMode(
      id: 'ea_two',
      label: 'Ea from k at two temperatures',
      formula: 'Ea = R · ln(k₂/k₁) / (1/T₁ − 1/T₂)',
      inputs: [inp('k1', 'k₁', ''), inp('T1', 'T₁', 'K'), inp('k2', 'k₂ (same unit)', ''), inp('T2', 'T₂', 'K')],
      solve: (x) {
        positive(x['k1']!, 'k₁');
        positive(x['k2']!, 'k₂');
        positive(x['T1']!, 'T₁');
        positive(x['T2']!, 'T₂');
        need(x['T1']! != x['T2']!, 'The two temperatures must differ');
        final ea = rJoule * math.log(x['k2']! / x['k1']!) / (1 / x['T1']! - 1 / x['T2']!) / 1000;
        return one('Ea', ea, 'kJ/mol', [
          'ln(k₂/k₁) = (Ea/R)(1/T₁ − 1/T₂)',
          'Ea = R · ln(${f(x['k2']!)} / ${f(x['k1']!)}) / (1/${f(x['T1']!)} − 1/${f(x['T2']!)})',
          'Ea = ${f(ea)} kJ/mol',
        ]);
      },
    ),
    ChemMode(
      id: 'k2',
      label: 'k₂ from k₁, Ea and two temperatures',
      formula: 'k₂ = k₁ · exp[(Ea/R)(1/T₁ − 1/T₂)]',
      inputs: [inp('k1', 'k₁', ''), inp('Ea', 'Ea', 'kJ/mol'), inp('T1', 'T₁', 'K'), inp('T2', 'T₂', 'K')],
      solve: (x) {
        positive(x['T1']!, 'T₁');
        positive(x['T2']!, 'T₂');
        final e = x['Ea']! * 1000 / rJoule * (1 / x['T1']! - 1 / x['T2']!);
        final k2 = x['k1']! * math.exp(e);
        return one('k₂', finite(k2), '', [
          'k₂ = k₁ · exp[(Ea/R)(1/T₁ − 1/T₂)]',
          'exponent = (${f(x['Ea']!)} × 1000 / ${f(rJoule)}) × (1/${f(x['T1']!)} − 1/${f(x['T2']!)}) = ${f(e)}',
          'k₂ = ${f(x['k1']!)} × e^(${f(e)}) = ${f(k2)}',
        ]);
      },
    ),
    ChemMode(
      id: 't2',
      label: 'T₂ for a target k₂',
      formula: '1/T₂ = 1/T₁ − R·ln(k₂/k₁) / Ea',
      inputs: [inp('k1', 'k₁', ''), inp('k2', 'k₂', ''), inp('Ea', 'Ea', 'kJ/mol'), inp('T1', 'T₁', 'K')],
      solve: (x) {
        positive(x['k1']!, 'k₁');
        positive(x['k2']!, 'k₂');
        positive(x['Ea']!, 'Ea');
        positive(x['T1']!, 'T₁');
        final inv = 1 / x['T1']! - rJoule * math.log(x['k2']! / x['k1']!) / (x['Ea']! * 1000);
        need(inv > 0, 'No positive temperature gives that k₂');
        final t2 = 1 / inv;
        return one('T₂', t2, 'K', [
          '1/T₂ = 1/T₁ − R·ln(k₂/k₁) / Ea',
          '1/T₂ = 1/${f(x['T1']!)} − ${f(rJoule)} × ln(${f(x['k2']!)}/${f(x['k1']!)}) / (${f(x['Ea']!)} × 1000) = ${f(inv)}',
          'T₂ = ${f(t2)} K',
        ]);
      },
    ),
  ],
);

final ChemSolver rateLaw = ChemSolver(
  id: 'rate_law',
  group: 'Kinetics',
  title: 'Rate law',
  summary: 'rate = k [A]ᵐ [B]ⁿ.',
  modes: [
    ChemMode(
      id: 'rate',
      label: 'Rate from concentrations',
      formula: 'rate = k · [A]^m · [B]^n',
      inputs: [
        inp('k', 'rate constant k', ''),
        inp('A', '[A]', 'mol/L'),
        inp('m', 'order in A (m)', ''),
        inp('B', '[B]', 'mol/L', initial: 1),
        inp('n', 'order in B (n, 0 if none)', '', initial: 0),
      ],
      solve: (x) {
        nonNegative(x['A']!, '[A]');
        nonNegative(x['B']!, '[B]');
        final r = x['k']! * math.pow(x['A']!, x['m']!) * math.pow(x['B']!, x['n']!);
        return one('Rate', finite(r), 'mol/(L·s)', [
          'rate = k · [A]^m · [B]^n',
          'rate = ${f(x['k']!)} × ${f(x['A']!)}^${f(x['m']!)} × ${f(x['B']!)}^${f(x['n']!)} = ${f(r)} mol/(L·s)',
        ]);
      },
    ),
    ChemMode(
      id: 'k',
      label: 'k from a measured rate',
      formula: 'k = rate / ([A]^m · [B]^n)',
      inputs: [
        inp('rate', 'rate', 'mol/(L·s)'),
        inp('A', '[A]', 'mol/L'),
        inp('m', 'order in A (m)', ''),
        inp('B', '[B]', 'mol/L', initial: 1),
        inp('n', 'order in B (n, 0 if none)', '', initial: 0),
      ],
      solve: (x) {
        positive(x['A']!, '[A]');
        positive(x['B']!, '[B]');
        final k = x['rate']! / (math.pow(x['A']!, x['m']!) * math.pow(x['B']!, x['n']!));
        return one('k', finite(k), '', [
          'k = rate / ([A]^m · [B]^n)',
          'k = ${f(x['rate']!)} / (${f(x['A']!)}^${f(x['m']!)} × ${f(x['B']!)}^${f(x['n']!)}) = ${f(k)}',
        ]);
      },
    ),
  ],
);

final List<ChemSolver> thermoSolvers = [heatQ, calorimetry, hess, gibbs, phaseChange];
final List<ChemSolver> kineticsSolvers = [zeroOrder, firstOrder, secondOrder, arrhenius, rateLaw];
