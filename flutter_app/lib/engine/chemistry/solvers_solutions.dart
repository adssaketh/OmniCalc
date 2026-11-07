import 'dart:math' as math;

import 'chem_constants.dart';
import 'solver_types.dart';
import 'solver_util.dart';

final ChemSolver molarity = ChemSolver(
  id: 'molarity',
  group: 'Solutions',
  title: 'Molarity',
  summary: 'M = n / V (moles of solute per litre of solution).',
  modes: [
    ChemMode(
      id: 'm',
      label: 'Molarity M',
      formula: 'M = n / V',
      inputs: [inp('n', 'moles of solute n', 'mol'), inp('V', 'solution volume V', 'L')],
      solve: (x) {
        positive(x['V']!, 'Volume');
        final m = x['n']! / x['V']!;
        return one('Molarity M', m, 'mol/L', ['M = n / V', 'M = ${f(x['n']!)} / ${f(x['V']!)} = ${f(m)} mol/L']);
      },
    ),
    ChemMode(
      id: 'n',
      label: 'Moles n',
      formula: 'n = M · V',
      inputs: [inp('M', 'molarity M', 'mol/L'), inp('V', 'solution volume V', 'L')],
      solve: (x) {
        final n = x['M']! * x['V']!;
        return one('Moles n', n, 'mol', ['n = M · V', 'n = ${f(x['M']!)} × ${f(x['V']!)} = ${f(n)} mol']);
      },
    ),
    ChemMode(
      id: 'v',
      label: 'Volume V',
      formula: 'V = n / M',
      inputs: [inp('n', 'moles of solute n', 'mol'), inp('M', 'molarity M', 'mol/L')],
      solve: (x) {
        positive(x['M']!, 'Molarity');
        final v = x['n']! / x['M']!;
        return one('Volume V', v, 'L', ['V = n / M', 'V = ${f(x['n']!)} / ${f(x['M']!)} = ${f(v)} L']);
      },
    ),
  ],
);

final ChemSolver molality = ChemSolver(
  id: 'molality',
  group: 'Solutions',
  title: 'Molality',
  summary: 'm = n / kg of solvent.',
  modes: [
    ChemMode(
      id: 'm',
      label: 'Molality m',
      formula: 'm = n_solute / kg_solvent',
      inputs: [inp('n', 'moles of solute', 'mol'), inp('kg', 'mass of solvent', 'kg')],
      solve: (x) {
        positive(x['kg']!, 'Solvent mass');
        final m = x['n']! / x['kg']!;
        return one('Molality m', m, 'mol/kg', ['m = n / kg of solvent', 'm = ${f(x['n']!)} / ${f(x['kg']!)} = ${f(m)} mol/kg']);
      },
    ),
    ChemMode(
      id: 'n',
      label: 'Moles of solute',
      formula: 'n = m · kg_solvent',
      inputs: [inp('m', 'molality m', 'mol/kg'), inp('kg', 'mass of solvent', 'kg')],
      solve: (x) {
        final n = x['m']! * x['kg']!;
        return one('Moles of solute', n, 'mol', ['n = m × kg of solvent', 'n = ${f(x['m']!)} × ${f(x['kg']!)} = ${f(n)} mol']);
      },
    ),
  ],
);

final ChemSolver normality = ChemSolver(
  id: 'normality',
  group: 'Solutions',
  title: 'Normality',
  summary: 'N = M × equivalents per mole (H⁺ or OH⁻ per formula unit, or electrons transferred).',
  modes: [
    ChemMode(
      id: 'n',
      label: 'Normality N',
      formula: 'N = M · z',
      inputs: [inp('M', 'molarity M', 'mol/L'), inp('z', 'equivalents per mole z', '')],
      solve: (x) {
        positive(x['z']!, 'z');
        final n = x['M']! * x['z']!;
        return one('Normality N', n, 'eq/L', ['N = M × z', 'N = ${f(x['M']!)} × ${f(x['z']!)} = ${f(n)} eq/L']);
      },
    ),
    ChemMode(
      id: 'm',
      label: 'Molarity M',
      formula: 'M = N / z',
      inputs: [inp('N', 'normality N', 'eq/L'), inp('z', 'equivalents per mole z', '')],
      solve: (x) {
        positive(x['z']!, 'z');
        final m = x['N']! / x['z']!;
        return one('Molarity M', m, 'mol/L', ['M = N / z', 'M = ${f(x['N']!)} / ${f(x['z']!)} = ${f(m)} mol/L']);
      },
    ),
  ],
);

final ChemSolver moleFraction = ChemSolver(
  id: 'mole_fraction',
  group: 'Solutions',
  title: 'Mole fraction',
  summary: 'X = moles of one component / total moles.',
  modes: [
    ChemMode(
      id: 'x',
      label: 'Mole fractions of solute and solvent',
      formula: 'X₁ = n₁ / (n₁ + n₂)',
      inputs: [inp('n1', 'moles of solute n₁', 'mol'), inp('n2', 'moles of solvent n₂', 'mol')],
      solve: (x) {
        nonNegative(x['n1']!, 'n₁');
        nonNegative(x['n2']!, 'n₂');
        final tot = x['n1']! + x['n2']!;
        positive(tot, 'Total moles');
        final x1 = x['n1']! / tot;
        return ChemResult([
          out('X₁ (solute)', x1, ''),
          out('X₂ (solvent)', 1 - x1, ''),
        ], [
          'n_total = ${f(x['n1']!)} + ${f(x['n2']!)} = ${f(tot)} mol',
          'X₁ = ${f(x['n1']!)} / ${f(tot)} = ${f(x1)}',
          'X₂ = 1 − X₁ = ${f(1 - x1)}',
        ]);
      },
    ),
  ],
);

final ChemSolver dilution = ChemSolver(
  id: 'dilution',
  group: 'Solutions',
  title: 'Dilution',
  summary: 'M₁V₁ = M₂V₂ (the amount of solute stays the same).',
  modes: [
    ChemMode(
      id: 'm2',
      label: 'Final molarity M₂',
      formula: 'M₂ = M₁V₁ / V₂',
      inputs: [inp('M1', 'M₁', 'mol/L'), inp('V1', 'V₁', 'L'), inp('V2', 'V₂', 'L')],
      solve: (x) {
        positive(x['V2']!, 'V₂');
        final m = x['M1']! * x['V1']! / x['V2']!;
        return one('M₂', m, 'mol/L', [
          'M₁V₁ = M₂V₂  →  M₂ = M₁V₁ / V₂',
          'M₂ = (${f(x['M1']!)} × ${f(x['V1']!)}) / ${f(x['V2']!)} = ${f(m)} mol/L',
        ]);
      },
    ),
    ChemMode(
      id: 'v2',
      label: 'Final volume V₂',
      formula: 'V₂ = M₁V₁ / M₂',
      inputs: [inp('M1', 'M₁', 'mol/L'), inp('V1', 'V₁', 'L'), inp('M2', 'M₂', 'mol/L')],
      solve: (x) {
        positive(x['M2']!, 'M₂');
        final v = x['M1']! * x['V1']! / x['M2']!;
        return ChemResult([
          out('V₂', v, 'L'),
          out('Solvent to add', v - x['V1']!, 'L'),
        ], [
          'M₁V₁ = M₂V₂  →  V₂ = M₁V₁ / M₂',
          'V₂ = (${f(x['M1']!)} × ${f(x['V1']!)}) / ${f(x['M2']!)} = ${f(v)} L',
          'Solvent to add = V₂ − V₁ = ${f(v - x['V1']!)} L',
        ]);
      },
    ),
    ChemMode(
      id: 'v1',
      label: 'Stock volume V₁',
      formula: 'V₁ = M₂V₂ / M₁',
      inputs: [inp('M1', 'M₁ (stock)', 'mol/L'), inp('M2', 'M₂', 'mol/L'), inp('V2', 'V₂', 'L')],
      solve: (x) {
        positive(x['M1']!, 'M₁');
        final v = x['M2']! * x['V2']! / x['M1']!;
        return one('V₁', v, 'L', [
          'M₁V₁ = M₂V₂  →  V₁ = M₂V₂ / M₁',
          'V₁ = (${f(x['M2']!)} × ${f(x['V2']!)}) / ${f(x['M1']!)} = ${f(v)} L',
        ]);
      },
    ),
  ],
);

final ChemSolver concentrationUnits = ChemSolver(
  id: 'conc_units',
  group: 'Solutions',
  title: 'ppm, ppb and percent',
  summary: '% w/w, % w/v, % v/v, ppm and ppb.',
  modes: [
    ChemMode(
      id: 'ww',
      label: '% w/w (mass percent)',
      formula: '% w/w = m_solute / m_solution × 100',
      inputs: [inp('ms', 'mass of solute', 'g'), inp('msol', 'mass of solution', 'g')],
      solve: (x) {
        positive(x['msol']!, 'Solution mass');
        final p = x['ms']! / x['msol']! * 100;
        return one('% w/w', p, '%', ['% w/w = (${f(x['ms']!)} / ${f(x['msol']!)}) × 100 = ${f(p)} %']);
      },
    ),
    ChemMode(
      id: 'wv',
      label: '% w/v',
      formula: '% w/v = g of solute / 100 mL of solution',
      inputs: [inp('ms', 'mass of solute', 'g'), inp('v', 'volume of solution', 'mL')],
      solve: (x) {
        positive(x['v']!, 'Volume');
        final p = x['ms']! / x['v']! * 100;
        return one('% w/v', p, '%', ['% w/v = (${f(x['ms']!)} g / ${f(x['v']!)} mL) × 100 = ${f(p)} %']);
      },
    ),
    ChemMode(
      id: 'vv',
      label: '% v/v',
      formula: '% v/v = V_solute / V_solution × 100',
      inputs: [inp('vs', 'volume of solute', 'mL'), inp('v', 'volume of solution', 'mL')],
      solve: (x) {
        positive(x['v']!, 'Volume');
        final p = x['vs']! / x['v']! * 100;
        return one('% v/v', p, '%', ['% v/v = (${f(x['vs']!)} / ${f(x['v']!)}) × 100 = ${f(p)} %']);
      },
    ),
    ChemMode(
      id: 'ppm',
      label: 'ppm from masses',
      formula: 'ppm = m_solute / m_solution × 10⁶',
      inputs: [inp('ms', 'mass of solute', 'g'), inp('msol', 'mass of solution (same unit)', 'g')],
      solve: (x) {
        positive(x['msol']!, 'Solution mass');
        final p = x['ms']! / x['msol']! * 1e6;
        return ChemResult([
          out('ppm', p, 'ppm'),
          out('ppb', p * 1000, 'ppb'),
          out('Percent', p / 1e4, '%'),
        ], [
          'ppm = (${f(x['ms']!)} / ${f(x['msol']!)}) × 10⁶ = ${f(p)}',
          'ppb = ppm × 1000 = ${f(p * 1000)}',
          '% = ppm / 10⁴ = ${f(p / 1e4)}',
        ]);
      },
    ),
    ChemMode(
      id: 'convert',
      label: 'Convert ppm',
      formula: '1 ppm = 1000 ppb = 0.0001 %',
      inputs: [inp('ppm', 'concentration', 'ppm')],
      solve: (x) {
        final p = x['ppm']!;
        return ChemResult([
          out('ppb', p * 1000, 'ppb'),
          out('Percent (w/w)', p / 1e4, '%'),
          out('Dilute water solution', p, 'mg/L', note: 'about 1 mg/L per ppm in water near 4 to 25 °C'),
        ], [
          'ppb = ${f(p)} × 1000 = ${f(p * 1000)}',
          '% = ${f(p)} / 10⁴ = ${f(p / 1e4)}',
        ]);
      },
    ),
  ],
);

final ChemSolver colligative = ChemSolver(
  id: 'colligative',
  group: 'Solutions',
  title: 'Colligative properties',
  summary: 'Boiling-point elevation, freezing-point depression, osmotic pressure and Raoult’s law.',
  modes: [
    ChemMode(
      id: 'dtb',
      label: 'Boiling-point elevation ΔTb',
      formula: 'ΔTb = i · Kb · m',
      inputs: [
        inp('i', 'van ’t Hoff factor i', '', initial: 1),
        inp('Kb', 'Kb', 'K·kg/mol', initial: 0.512),
        inp('m', 'molality m', 'mol/kg'),
      ],
      solve: (x) {
        final d = x['i']! * x['Kb']! * x['m']!;
        return one('ΔTb', d, 'K', ['ΔTb = i · Kb · m', 'ΔTb = ${f(x['i']!)} × ${f(x['Kb']!)} × ${f(x['m']!)} = ${f(d)} K']);
      },
    ),
    ChemMode(
      id: 'dtf',
      label: 'Freezing-point depression ΔTf',
      formula: 'ΔTf = i · Kf · m',
      inputs: [
        inp('i', 'van ’t Hoff factor i', '', initial: 1),
        inp('Kf', 'Kf', 'K·kg/mol', initial: 1.86),
        inp('m', 'molality m', 'mol/kg'),
      ],
      solve: (x) {
        final d = x['i']! * x['Kf']! * x['m']!;
        return one('ΔTf', d, 'K', ['ΔTf = i · Kf · m', 'ΔTf = ${f(x['i']!)} × ${f(x['Kf']!)} × ${f(x['m']!)} = ${f(d)} K']);
      },
    ),
    ChemMode(
      id: 'osmotic',
      label: 'Osmotic pressure π',
      formula: 'π = i · M · R · T',
      inputs: [
        inp('i', 'van ’t Hoff factor i', '', initial: 1),
        inp('M', 'molarity M', 'mol/L'),
        inp('T', 'temperature T', 'K'),
      ],
      solve: (x) {
        positive(x['T']!, 'Temperature');
        final pi = x['i']! * x['M']! * rLAtm * x['T']!;
        return one('Osmotic pressure π', pi, 'atm', [
          'π = i · M · R · T',
          'π = ${f(x['i']!)} × ${f(x['M']!)} × ${f(rLAtm)} × ${f(x['T']!)} = ${f(pi)} atm',
        ]);
      },
    ),
    ChemMode(
      id: 'raoult',
      label: 'Vapor pressure (Raoult)',
      formula: 'P = X_solvent · P°',
      inputs: [inp('X', 'solvent mole fraction X', ''), inp('P0', 'pure-solvent vapor pressure P°', 'any pressure unit')],
      solve: (x) {
        need(x['X']! >= 0 && x['X']! <= 1, 'Mole fraction must be between 0 and 1');
        final p = x['X']! * x['P0']!;
        return ChemResult([
          out('Solution vapor pressure P', p, ''),
          out('Lowering ΔP', x['P0']! - p, ''),
        ], [
          'P = X_solvent · P° = ${f(x['X']!)} × ${f(x['P0']!)} = ${f(p)}',
          'ΔP = P° − P = ${f(x['P0']! - p)}',
        ]);
      },
    ),
  ],
);

// ---------------------------------------------------------------------------------------------------------------
// acids and bases
// ---------------------------------------------------------------------------------------------------------------

ChemResult _phFromH(double h, List<String> head) {
  positive(h, '[H⁺]');
  final ph = -log10(h);
  final oh = kw25 / h;
  final poh = -log10(oh);
  return ChemResult([
    out('pH', ph, ''),
    out('pOH', poh, ''),
    out('[H⁺]', h, 'mol/L'),
    out('[OH⁻]', oh, 'mol/L'),
  ], [
    ...head,
    'pH = −log₁₀[H⁺] = ${f(ph)}',
    '[OH⁻] = Kw / [H⁺] = ${f(kw25)} / ${f(h)} = ${f(oh)} mol/L',
    'pOH = 14 − pH = ${f(poh)}',
  ]);
}

final ChemSolver phConverter = ChemSolver(
  id: 'ph',
  group: 'Acids & bases',
  title: 'pH, pOH, [H⁺], [OH⁻]',
  summary: 'Convert between the four at 25 °C (Kw = 1.0 × 10⁻¹⁴).',
  modes: [
    ChemMode(
      id: 'from_ph',
      label: 'From pH',
      formula: '[H⁺] = 10^(−pH)',
      inputs: [inp('pH', 'pH', '')],
      solve: (x) => _phFromH(math.pow(10, -x['pH']!).toDouble(), ['[H⁺] = 10^(−pH) = 10^(−${f(x['pH']!)})']),
    ),
    ChemMode(
      id: 'from_poh',
      label: 'From pOH',
      formula: '[OH⁻] = 10^(−pOH)',
      inputs: [inp('pOH', 'pOH', '')],
      solve: (x) {
        final oh = math.pow(10, -x['pOH']!).toDouble();
        return _phFromH(kw25 / oh, ['[OH⁻] = 10^(−pOH) = ${f(oh)} mol/L', '[H⁺] = Kw / [OH⁻]']);
      },
    ),
    ChemMode(
      id: 'from_h',
      label: 'From [H⁺]',
      formula: 'pH = −log₁₀[H⁺]',
      inputs: [inp('H', '[H⁺]', 'mol/L')],
      solve: (x) => _phFromH(x['H']!, const []),
    ),
    ChemMode(
      id: 'from_oh',
      label: 'From [OH⁻]',
      formula: 'pOH = −log₁₀[OH⁻]',
      inputs: [inp('OH', '[OH⁻]', 'mol/L')],
      solve: (x) {
        positive(x['OH']!, '[OH⁻]');
        return _phFromH(kw25 / x['OH']!, ['[H⁺] = Kw / [OH⁻] = ${f(kw25)} / ${f(x['OH']!)}']);
      },
    ),
  ],
);

final ChemSolver strongAcidBase = ChemSolver(
  id: 'strong_acid_base',
  group: 'Acids & bases',
  title: 'Strong acid or base',
  summary: 'pH of a fully dissociated acid or base, including the water term for very dilute solutions.',
  modes: [
    ChemMode(
      id: 'acid',
      label: 'Strong acid',
      formula: '[H⁺] = (c + √(c² + 4Kw)) / 2,  c = z · C',
      inputs: [inp('C', 'concentration C', 'mol/L'), inp('z', 'H⁺ per formula unit z', '', initial: 1)],
      solve: (x) {
        positive(x['C']!, 'Concentration');
        positive(x['z']!, 'z');
        final c = x['C']! * x['z']!;
        final h = (c + math.sqrt(c * c + 4 * kw25)) / 2;
        return _phFromH(h, [
          'c = z · C = ${f(x['z']!)} × ${f(x['C']!)} = ${f(c)} mol/L',
          '[H⁺] = (c + √(c² + 4Kw)) / 2 = ${f(h)} mol/L  (includes water’s own H⁺)',
        ]);
      },
    ),
    ChemMode(
      id: 'base',
      label: 'Strong base',
      formula: '[OH⁻] = (c + √(c² + 4Kw)) / 2,  c = z · C',
      inputs: [inp('C', 'concentration C', 'mol/L'), inp('z', 'OH⁻ per formula unit z', '', initial: 1)],
      solve: (x) {
        positive(x['C']!, 'Concentration');
        positive(x['z']!, 'z');
        final c = x['C']! * x['z']!;
        final oh = (c + math.sqrt(c * c + 4 * kw25)) / 2;
        return _phFromH(kw25 / oh, [
          'c = z · C = ${f(x['z']!)} × ${f(x['C']!)} = ${f(c)} mol/L',
          '[OH⁻] = (c + √(c² + 4Kw)) / 2 = ${f(oh)} mol/L',
        ]);
      },
    ),
  ],
);

final ChemSolver weakAcidBase = ChemSolver(
  id: 'weak_acid_base',
  group: 'Acids & bases',
  title: 'Weak acid or base',
  summary: 'pH from Ka or Kb by solving the quadratic exactly (no “x is small” shortcut).',
  modes: [
    ChemMode(
      id: 'acid',
      label: 'Weak acid (Ka)',
      formula: 'Ka = x² / (C − x)',
      inputs: [inp('Ka', 'Ka', ''), inp('C', 'initial concentration C', 'mol/L')],
      solve: (x) {
        positive(x['Ka']!, 'Ka');
        positive(x['C']!, 'Concentration');
        final ka = x['Ka']!, c = x['C']!;
        final h = (-ka + math.sqrt(ka * ka + 4 * ka * c)) / 2;
        final r = _phFromH(h, [
          'HA ⇌ H⁺ + A⁻;  Ka = x² / (C − x)',
          'x² + Ka·x − Ka·C = 0  →  x = (−Ka + √(Ka² + 4·Ka·C)) / 2',
          'x = [H⁺] = ${f(h)} mol/L',
        ]);
        return ChemResult([...r.outputs, out('Percent ionization', h / c * 100, '%')], [
          ...r.steps,
          'Percent ionization = x / C × 100 = ${f(h / c * 100)} %',
        ]);
      },
    ),
    ChemMode(
      id: 'base',
      label: 'Weak base (Kb)',
      formula: 'Kb = x² / (C − x)',
      inputs: [inp('Kb', 'Kb', ''), inp('C', 'initial concentration C', 'mol/L')],
      solve: (x) {
        positive(x['Kb']!, 'Kb');
        positive(x['C']!, 'Concentration');
        final kb = x['Kb']!, c = x['C']!;
        final oh = (-kb + math.sqrt(kb * kb + 4 * kb * c)) / 2;
        final r = _phFromH(kw25 / oh, [
          'B + H₂O ⇌ BH⁺ + OH⁻;  Kb = x² / (C − x)',
          'x = [OH⁻] = (−Kb + √(Kb² + 4·Kb·C)) / 2 = ${f(oh)} mol/L',
        ]);
        return ChemResult([...r.outputs, out('Percent ionization', oh / c * 100, '%')], [
          ...r.steps,
          'Percent ionization = x / C × 100 = ${f(oh / c * 100)} %',
        ]);
      },
    ),
  ],
);

final ChemSolver buffer = ChemSolver(
  id: 'buffer',
  group: 'Acids & bases',
  title: 'Buffer (Henderson–Hasselbalch)',
  summary: 'pH = pKa + log₁₀([A⁻] / [HA]).',
  modes: [
    ChemMode(
      id: 'ph',
      label: 'pH of a buffer',
      formula: 'pH = pKa + log₁₀([A⁻] / [HA])',
      inputs: [inp('pKa', 'pKa', ''), inp('A', '[A⁻] (base form)', 'mol/L'), inp('HA', '[HA] (acid form)', 'mol/L')],
      solve: (x) {
        positive(x['A']!, '[A⁻]');
        positive(x['HA']!, '[HA]');
        final ph = x['pKa']! + log10(x['A']! / x['HA']!);
        return one('pH', ph, '', [
          'pH = pKa + log₁₀([A⁻] / [HA])',
          'pH = ${f(x['pKa']!)} + log₁₀(${f(x['A']!)} / ${f(x['HA']!)}) = ${f(ph)}',
        ]);
      },
    ),
    ChemMode(
      id: 'ratio',
      label: 'Ratio [A⁻]/[HA] for a target pH',
      formula: '[A⁻] / [HA] = 10^(pH − pKa)',
      inputs: [inp('pKa', 'pKa', ''), inp('pH', 'target pH', '')],
      solve: (x) {
        final r = math.pow(10, x['pH']! - x['pKa']!).toDouble();
        return one('[A⁻] / [HA]', r, '', [
          'pH = pKa + log₁₀([A⁻]/[HA])  →  [A⁻]/[HA] = 10^(pH − pKa)',
          '[A⁻]/[HA] = 10^(${f(x['pH']!)} − ${f(x['pKa']!)}) = ${f(r)}',
        ]);
      },
    ),
  ],
);

ChemResult _titrationResult(double ph, double nA, double nB, double veq, List<String> steps) {
  return ChemResult([
    out('pH', ph, ''),
    out('Equivalence volume', veq, 'mL'),
  ], steps);
}

final ChemSolver titration = ChemSolver(
  id: 'titration',
  group: 'Acids & bases',
  title: 'Titration pH',
  summary: 'pH after adding a volume of strong base to an acid.',
  modes: [
    ChemMode(
      id: 'sa_sb',
      label: 'Strong acid + strong base',
      formula: 'pH from the excess acid or base',
      inputs: [
        inp('Ca', 'acid concentration', 'mol/L'),
        inp('Va', 'acid volume', 'mL'),
        inp('Cb', 'base concentration', 'mol/L'),
        inp('Vb', 'base added', 'mL'),
      ],
      solve: (x) {
        positive(x['Ca']!, 'Acid concentration');
        positive(x['Va']!, 'Acid volume');
        positive(x['Cb']!, 'Base concentration');
        nonNegative(x['Vb']!, 'Base volume');
        final nA = x['Ca']! * x['Va']! / 1000;
        final nB = x['Cb']! * x['Vb']! / 1000;
        final vTot = (x['Va']! + x['Vb']!) / 1000;
        final veq = x['Ca']! * x['Va']! / x['Cb']! ;
        final steps = <String>[
          'n(acid) = ${f(x['Ca']!)} × ${f(x['Va']!)} mL = ${f(nA * 1000)} mmol',
          'n(base) = ${f(x['Cb']!)} × ${f(x['Vb']!)} mL = ${f(nB * 1000)} mmol',
          'Equivalence at ${f(veq)} mL of base',
        ];
        double ph;
        if ((nA - nB).abs() < 1e-15) {
          ph = 7;
          steps.add('Exactly at equivalence: only a neutral salt remains, pH = 7.00');
        } else if (nA > nB) {
          final c = (nA - nB) / vTot;
          final h = (c + math.sqrt(c * c + 4 * kw25)) / 2;
          ph = -log10(h);
          steps.add('Excess H⁺ = (${f(nA * 1000)} − ${f(nB * 1000)}) mmol in ${f(vTot * 1000)} mL = ${f(c)} mol/L');
          steps.add('pH = −log₁₀[H⁺] = ${f(ph)}');
        } else {
          final c = (nB - nA) / vTot;
          final oh = (c + math.sqrt(c * c + 4 * kw25)) / 2;
          ph = 14 + log10(oh);
          steps.add('Excess OH⁻ = (${f(nB * 1000)} − ${f(nA * 1000)}) mmol in ${f(vTot * 1000)} mL = ${f(c)} mol/L');
          steps.add('pOH = ${f(-log10(oh))},  pH = 14 − pOH = ${f(ph)}');
        }
        return _titrationResult(ph, nA, nB, veq, steps);
      },
    ),
    ChemMode(
      id: 'wa_sb',
      label: 'Weak acid + strong base',
      formula: 'buffer before equivalence, hydrolysis at it, excess OH⁻ after',
      inputs: [
        inp('Ca', 'acid concentration', 'mol/L'),
        inp('Va', 'acid volume', 'mL'),
        inp('Ka', 'Ka of the acid', ''),
        inp('Cb', 'base concentration', 'mol/L'),
        inp('Vb', 'base added', 'mL'),
      ],
      solve: (x) {
        positive(x['Ca']!, 'Acid concentration');
        positive(x['Va']!, 'Acid volume');
        positive(x['Ka']!, 'Ka');
        positive(x['Cb']!, 'Base concentration');
        nonNegative(x['Vb']!, 'Base volume');
        final ka = x['Ka']!;
        final nA = x['Ca']! * x['Va']! / 1000;
        final nB = x['Cb']! * x['Vb']! / 1000;
        final vTot = (x['Va']! + x['Vb']!) / 1000;
        final veq = x['Ca']! * x['Va']! / x['Cb']!;
        final steps = <String>[
          'n(HA) = ${f(nA * 1000)} mmol,  n(OH⁻ added) = ${f(nB * 1000)} mmol',
          'Equivalence at ${f(veq)} mL of base',
        ];
        double ph;
        if (nB == 0) {
          final c = nA / vTot;
          final h = (-ka + math.sqrt(ka * ka + 4 * ka * c)) / 2;
          ph = -log10(h);
          steps.add('No base yet: weak acid, [H⁺] = (−Ka + √(Ka² + 4·Ka·C)) / 2 = ${f(h)},  pH = ${f(ph)}');
        } else if (nB < nA - 1e-15) {
          ph = -log10(ka) + log10(nB / (nA - nB));
          steps.add('Buffer: [A⁻]/[HA] = ${f(nB * 1000)} / ${f((nA - nB) * 1000)}');
          steps.add('pH = pKa + log₁₀([A⁻]/[HA]) = ${f(-log10(ka))} + ${f(log10(nB / (nA - nB)))} = ${f(ph)}');
        } else if ((nA - nB).abs() <= 1e-15) {
          final c = nA / vTot;
          final kb = kw25 / ka;
          final oh = (-kb + math.sqrt(kb * kb + 4 * kb * c)) / 2;
          ph = 14 + log10(oh);
          steps.add('At equivalence only A⁻ remains: ${f(c)} mol/L,  Kb = Kw/Ka = ${f(kb)}');
          steps.add('[OH⁻] = (−Kb + √(Kb² + 4·Kb·C)) / 2 = ${f(oh)},  pH = ${f(ph)}');
        } else {
          final c = (nB - nA) / vTot;
          final oh = (c + math.sqrt(c * c + 4 * kw25)) / 2;
          ph = 14 + log10(oh);
          steps.add('Excess OH⁻ = ${f((nB - nA) * 1000)} mmol in ${f(vTot * 1000)} mL = ${f(c)} mol/L');
          steps.add('pOH = ${f(-log10(oh))},  pH = ${f(ph)}');
        }
        return _titrationResult(ph, nA, nB, veq, steps);
      },
    ),
  ],
);

final ChemSolver kwKaKb = ChemSolver(
  id: 'kw_pka',
  group: 'Acids & bases',
  title: 'Kw, Ka, Kb, pKa',
  summary: 'Kw = [H⁺][OH⁻] and Ka · Kb = Kw for a conjugate pair.',
  modes: [
    ChemMode(
      id: 'pka',
      label: 'pKa from Ka',
      formula: 'pKa = −log₁₀ Ka',
      inputs: [inp('Ka', 'Ka', '')],
      solve: (x) {
        positive(x['Ka']!, 'Ka');
        final p = -log10(x['Ka']!);
        return one('pKa', p, '', ['pKa = −log₁₀(${f(x['Ka']!)}) = ${f(p)}']);
      },
    ),
    ChemMode(
      id: 'ka',
      label: 'Ka from pKa',
      formula: 'Ka = 10^(−pKa)',
      inputs: [inp('pKa', 'pKa', '')],
      solve: (x) {
        final k = math.pow(10, -x['pKa']!).toDouble();
        return one('Ka', k, '', ['Ka = 10^(−pKa) = 10^(−${f(x['pKa']!)}) = ${f(k)}']);
      },
    ),
    ChemMode(
      id: 'kb',
      label: 'Kb of the conjugate base',
      formula: 'Kb = Kw / Ka',
      inputs: [inp('Ka', 'Ka of the acid', '')],
      solve: (x) {
        positive(x['Ka']!, 'Ka');
        final kb = kw25 / x['Ka']!;
        return ChemResult([out('Kb', kb, ''), out('pKb', -log10(kb), '')], [
          'Kb = Kw / Ka = ${f(kw25)} / ${f(x['Ka']!)} = ${f(kb)}',
          'pKb = ${f(-log10(kb))}',
        ]);
      },
    ),
    ChemMode(
      id: 'kw',
      label: '[OH⁻] from [H⁺] and Kw',
      formula: 'Kw = [H⁺][OH⁻]',
      inputs: [inp('H', '[H⁺]', 'mol/L'), inp('Kw', 'Kw', '', initial: 1.0e-14)],
      solve: (x) {
        positive(x['H']!, '[H⁺]');
        positive(x['Kw']!, 'Kw');
        final oh = x['Kw']! / x['H']!;
        return one('[OH⁻]', oh, 'mol/L', ['[OH⁻] = Kw / [H⁺] = ${f(x['Kw']!)} / ${f(x['H']!)} = ${f(oh)} mol/L']);
      },
    ),
  ],
);

final List<ChemSolver> solutionSolvers = [
  molarity,
  molality,
  normality,
  moleFraction,
  dilution,
  concentrationUnits,
  colligative,
];

final List<ChemSolver> acidBaseSolvers = [
  phConverter,
  strongAcidBase,
  weakAcidBase,
  buffer,
  titration,
  kwKaKb,
];
