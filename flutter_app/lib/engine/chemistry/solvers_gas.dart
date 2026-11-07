import 'dart:math' as math;

import 'chem_constants.dart';
import 'solver_types.dart';
import 'solver_util.dart';

const _p = 'atm';
const _v = 'L';
const _n = 'mol';
const _t = 'K';

ChemInput pIn(String id, String label) => inp(id, label, _p);
ChemInput vIn(String id, String label) => inp(id, label, _v);
ChemInput tIn(String id, String label) => inp(id, label, _t);
ChemInput nIn(String id, String label) => inp(id, label, _n);

final String _r = f(rLAtm);

final ChemSolver idealGas = ChemSolver(
  id: 'ideal_gas',
  group: 'Gas laws',
  title: 'Ideal gas law',
  summary: 'PV = nRT. Solve any one variable.',
  modes: [
    ChemMode(
      id: 'p',
      label: 'Pressure P',
      formula: 'P = nRT / V',
      inputs: [nIn('n', 'moles n'), tIn('T', 'temperature T'), vIn('V', 'volume V')],
      solve: (x) {
        positive(x['V']!, 'Volume');
        positive(x['T']!, 'Temperature');
        nonNegative(x['n']!, 'Moles');
        final p = x['n']! * rLAtm * x['T']! / x['V']!;
        return one('Pressure P', p, 'atm', [
          'PV = nRT  →  P = nRT / V',
          'R = $_r L·atm/(mol·K)',
          'P = (${f(x['n']!)} × $_r × ${f(x['T']!)}) / ${f(x['V']!)} = ${f(p)} atm',
        ]);
      },
    ),
    ChemMode(
      id: 'v',
      label: 'Volume V',
      formula: 'V = nRT / P',
      inputs: [nIn('n', 'moles n'), tIn('T', 'temperature T'), pIn('P', 'pressure P')],
      solve: (x) {
        positive(x['P']!, 'Pressure');
        positive(x['T']!, 'Temperature');
        nonNegative(x['n']!, 'Moles');
        final vol = x['n']! * rLAtm * x['T']! / x['P']!;
        return one('Volume V', vol, 'L', [
          'PV = nRT  →  V = nRT / P',
          'R = $_r L·atm/(mol·K)',
          'V = (${f(x['n']!)} × $_r × ${f(x['T']!)}) / ${f(x['P']!)} = ${f(vol)} L',
        ]);
      },
    ),
    ChemMode(
      id: 'n',
      label: 'Moles n',
      formula: 'n = PV / RT',
      inputs: [pIn('P', 'pressure P'), vIn('V', 'volume V'), tIn('T', 'temperature T')],
      solve: (x) {
        positive(x['T']!, 'Temperature');
        final n = x['P']! * x['V']! / (rLAtm * x['T']!);
        return one('Moles n', n, 'mol', [
          'PV = nRT  →  n = PV / RT',
          'R = $_r L·atm/(mol·K)',
          'n = (${f(x['P']!)} × ${f(x['V']!)}) / ($_r × ${f(x['T']!)}) = ${f(n)} mol',
        ]);
      },
    ),
    ChemMode(
      id: 't',
      label: 'Temperature T',
      formula: 'T = PV / nR',
      inputs: [pIn('P', 'pressure P'), vIn('V', 'volume V'), nIn('n', 'moles n')],
      solve: (x) {
        positive(x['n']!, 'Moles');
        final t = x['P']! * x['V']! / (x['n']! * rLAtm);
        return one('Temperature T', t, 'K', [
          'PV = nRT  →  T = PV / nR',
          'R = $_r L·atm/(mol·K)',
          'T = (${f(x['P']!)} × ${f(x['V']!)}) / (${f(x['n']!)} × $_r) = ${f(t)} K',
        ]);
      },
    ),
  ],
);

final ChemSolver combinedGas = ChemSolver(
  id: 'combined_gas',
  group: 'Gas laws',
  title: 'Combined gas law',
  summary: 'P₁V₁/T₁ = P₂V₂/T₂ for a fixed amount of gas.',
  modes: [
    ChemMode(
      id: 'p2',
      label: 'Final pressure P₂',
      formula: 'P₂ = P₁V₁T₂ / (T₁V₂)',
      inputs: [pIn('P1', 'P₁'), vIn('V1', 'V₁'), tIn('T1', 'T₁'), vIn('V2', 'V₂'), tIn('T2', 'T₂')],
      solve: (x) {
        positive(x['T1']!, 'T₁');
        positive(x['V2']!, 'V₂');
        final r = x['P1']! * x['V1']! * x['T2']! / (x['T1']! * x['V2']!);
        return one('P₂', r, 'atm', [
          'P₁V₁/T₁ = P₂V₂/T₂  →  P₂ = P₁V₁T₂ / (T₁V₂)',
          'P₂ = (${f(x['P1']!)} × ${f(x['V1']!)} × ${f(x['T2']!)}) / (${f(x['T1']!)} × ${f(x['V2']!)}) = ${f(r)} atm',
        ]);
      },
    ),
    ChemMode(
      id: 'v2',
      label: 'Final volume V₂',
      formula: 'V₂ = P₁V₁T₂ / (T₁P₂)',
      inputs: [pIn('P1', 'P₁'), vIn('V1', 'V₁'), tIn('T1', 'T₁'), pIn('P2', 'P₂'), tIn('T2', 'T₂')],
      solve: (x) {
        positive(x['T1']!, 'T₁');
        positive(x['P2']!, 'P₂');
        final r = x['P1']! * x['V1']! * x['T2']! / (x['T1']! * x['P2']!);
        return one('V₂', r, 'L', [
          'P₁V₁/T₁ = P₂V₂/T₂  →  V₂ = P₁V₁T₂ / (T₁P₂)',
          'V₂ = (${f(x['P1']!)} × ${f(x['V1']!)} × ${f(x['T2']!)}) / (${f(x['T1']!)} × ${f(x['P2']!)}) = ${f(r)} L',
        ]);
      },
    ),
    ChemMode(
      id: 't2',
      label: 'Final temperature T₂',
      formula: 'T₂ = P₂V₂T₁ / (P₁V₁)',
      inputs: [pIn('P1', 'P₁'), vIn('V1', 'V₁'), tIn('T1', 'T₁'), pIn('P2', 'P₂'), vIn('V2', 'V₂')],
      solve: (x) {
        final d = x['P1']! * x['V1']!;
        need(d != 0, 'P₁ and V₁ cannot be 0');
        final r = x['P2']! * x['V2']! * x['T1']! / d;
        return one('T₂', r, 'K', [
          'P₁V₁/T₁ = P₂V₂/T₂  →  T₂ = P₂V₂T₁ / (P₁V₁)',
          'T₂ = (${f(x['P2']!)} × ${f(x['V2']!)} × ${f(x['T1']!)}) / (${f(x['P1']!)} × ${f(x['V1']!)}) = ${f(r)} K',
        ]);
      },
    ),
  ],
);

final ChemSolver boyle = ChemSolver(
  id: 'boyle',
  group: 'Gas laws',
  title: "Boyle's law",
  summary: 'P₁V₁ = P₂V₂ at constant temperature and amount.',
  modes: [
    ChemMode(
      id: 'p2',
      label: 'Final pressure P₂',
      formula: 'P₂ = P₁V₁ / V₂',
      inputs: [pIn('P1', 'P₁'), vIn('V1', 'V₁'), vIn('V2', 'V₂')],
      solve: (x) {
        positive(x['V2']!, 'V₂');
        final r = x['P1']! * x['V1']! / x['V2']!;
        return one('P₂', r, 'atm', [
          'P₁V₁ = P₂V₂  →  P₂ = P₁V₁ / V₂',
          'P₂ = (${f(x['P1']!)} × ${f(x['V1']!)}) / ${f(x['V2']!)} = ${f(r)} atm',
        ]);
      },
    ),
    ChemMode(
      id: 'v2',
      label: 'Final volume V₂',
      formula: 'V₂ = P₁V₁ / P₂',
      inputs: [pIn('P1', 'P₁'), vIn('V1', 'V₁'), pIn('P2', 'P₂')],
      solve: (x) {
        positive(x['P2']!, 'P₂');
        final r = x['P1']! * x['V1']! / x['P2']!;
        return one('V₂', r, 'L', [
          'P₁V₁ = P₂V₂  →  V₂ = P₁V₁ / P₂',
          'V₂ = (${f(x['P1']!)} × ${f(x['V1']!)}) / ${f(x['P2']!)} = ${f(r)} L',
        ]);
      },
    ),
  ],
);

final ChemSolver charles = ChemSolver(
  id: 'charles',
  group: 'Gas laws',
  title: "Charles's law",
  summary: 'V₁/T₁ = V₂/T₂ at constant pressure and amount. Use kelvin.',
  modes: [
    ChemMode(
      id: 'v2',
      label: 'Final volume V₂',
      formula: 'V₂ = V₁T₂ / T₁',
      inputs: [vIn('V1', 'V₁'), tIn('T1', 'T₁'), tIn('T2', 'T₂')],
      solve: (x) {
        positive(x['T1']!, 'T₁');
        final r = x['V1']! * x['T2']! / x['T1']!;
        return one('V₂', r, 'L', [
          'V₁/T₁ = V₂/T₂  →  V₂ = V₁T₂ / T₁',
          'V₂ = (${f(x['V1']!)} × ${f(x['T2']!)}) / ${f(x['T1']!)} = ${f(r)} L',
        ]);
      },
    ),
    ChemMode(
      id: 't2',
      label: 'Final temperature T₂',
      formula: 'T₂ = V₂T₁ / V₁',
      inputs: [vIn('V1', 'V₁'), tIn('T1', 'T₁'), vIn('V2', 'V₂')],
      solve: (x) {
        positive(x['V1']!, 'V₁');
        final r = x['V2']! * x['T1']! / x['V1']!;
        return one('T₂', r, 'K', [
          'V₁/T₁ = V₂/T₂  →  T₂ = V₂T₁ / V₁',
          'T₂ = (${f(x['V2']!)} × ${f(x['T1']!)}) / ${f(x['V1']!)} = ${f(r)} K',
        ]);
      },
    ),
  ],
);

final ChemSolver gayLussac = ChemSolver(
  id: 'gay_lussac',
  group: 'Gas laws',
  title: "Gay-Lussac's law",
  summary: 'P₁/T₁ = P₂/T₂ at constant volume and amount. Use kelvin.',
  modes: [
    ChemMode(
      id: 'p2',
      label: 'Final pressure P₂',
      formula: 'P₂ = P₁T₂ / T₁',
      inputs: [pIn('P1', 'P₁'), tIn('T1', 'T₁'), tIn('T2', 'T₂')],
      solve: (x) {
        positive(x['T1']!, 'T₁');
        final r = x['P1']! * x['T2']! / x['T1']!;
        return one('P₂', r, 'atm', [
          'P₁/T₁ = P₂/T₂  →  P₂ = P₁T₂ / T₁',
          'P₂ = (${f(x['P1']!)} × ${f(x['T2']!)}) / ${f(x['T1']!)} = ${f(r)} atm',
        ]);
      },
    ),
    ChemMode(
      id: 't2',
      label: 'Final temperature T₂',
      formula: 'T₂ = P₂T₁ / P₁',
      inputs: [pIn('P1', 'P₁'), tIn('T1', 'T₁'), pIn('P2', 'P₂')],
      solve: (x) {
        positive(x['P1']!, 'P₁');
        final r = x['P2']! * x['T1']! / x['P1']!;
        return one('T₂', r, 'K', [
          'P₁/T₁ = P₂/T₂  →  T₂ = P₂T₁ / P₁',
          'T₂ = (${f(x['P2']!)} × ${f(x['T1']!)}) / ${f(x['P1']!)} = ${f(r)} K',
        ]);
      },
    ),
  ],
);

final ChemSolver avogadroLaw = ChemSolver(
  id: 'avogadro_law',
  group: 'Gas laws',
  title: "Avogadro's law",
  summary: 'V₁/n₁ = V₂/n₂ at constant temperature and pressure.',
  modes: [
    ChemMode(
      id: 'v2',
      label: 'Final volume V₂',
      formula: 'V₂ = V₁n₂ / n₁',
      inputs: [vIn('V1', 'V₁'), nIn('n1', 'n₁'), nIn('n2', 'n₂')],
      solve: (x) {
        positive(x['n1']!, 'n₁');
        final r = x['V1']! * x['n2']! / x['n1']!;
        return one('V₂', r, 'L', [
          'V₁/n₁ = V₂/n₂  →  V₂ = V₁n₂ / n₁',
          'V₂ = (${f(x['V1']!)} × ${f(x['n2']!)}) / ${f(x['n1']!)} = ${f(r)} L',
        ]);
      },
    ),
    ChemMode(
      id: 'n2',
      label: 'Final moles n₂',
      formula: 'n₂ = n₁V₂ / V₁',
      inputs: [vIn('V1', 'V₁'), nIn('n1', 'n₁'), vIn('V2', 'V₂')],
      solve: (x) {
        positive(x['V1']!, 'V₁');
        final r = x['n1']! * x['V2']! / x['V1']!;
        return one('n₂', r, 'mol', [
          'V₁/n₁ = V₂/n₂  →  n₂ = n₁V₂ / V₁',
          'n₂ = (${f(x['n1']!)} × ${f(x['V2']!)}) / ${f(x['V1']!)} = ${f(r)} mol',
        ]);
      },
    ),
  ],
);

final ChemSolver dalton = ChemSolver(
  id: 'dalton',
  group: 'Gas laws',
  title: "Dalton's law",
  summary: 'Partial pressures of a gas mixture.',
  modes: [
    ChemMode(
      id: 'from_moles',
      label: 'Partial pressures from moles',
      formula: 'Pᵢ = Xᵢ · P_total,  Xᵢ = nᵢ / n_total',
      inputs: [
        pIn('Ptot', 'total pressure'),
        nIn('n1', 'gas 1 moles'),
        nIn('n2', 'gas 2 moles'),
        const ChemInput('n3', 'gas 3 moles (0 if none)', _n, initial: 0),
        const ChemInput('n4', 'gas 4 moles (0 if none)', _n, initial: 0),
      ],
      solve: (x) {
        final ns = [x['n1']!, x['n2']!, x['n3']!, x['n4']!];
        for (final n in ns) {
          nonNegative(n, 'Moles');
        }
        final total = ns.fold(0.0, (a, b) => a + b);
        positive(total, 'Total moles');
        positive(x['Ptot']!, 'Total pressure');
        final outs = <ChemOutput>[];
        final steps = <String>['n_total = ${ns.map(f).join(' + ')} = ${f(total)} mol'];
        for (var i = 0; i < 4; i++) {
          if (ns[i] == 0) continue;
          final xi = ns[i] / total;
          final pi = xi * x['Ptot']!;
          outs.add(out('Mole fraction X${i + 1}', xi, ''));
          outs.add(out('Partial pressure P${i + 1}', pi, 'atm'));
          steps.add('X${i + 1} = ${f(ns[i])} / ${f(total)} = ${f(xi)};  P${i + 1} = ${f(xi)} × ${f(x['Ptot']!)} = ${f(pi)} atm');
        }
        return ChemResult(outs, steps);
      },
    ),
    ChemMode(
      id: 'total',
      label: 'Total pressure from partial pressures',
      formula: 'P_total = P₁ + P₂ + P₃ + P₄',
      inputs: [
        pIn('P1', 'P₁'),
        pIn('P2', 'P₂'),
        const ChemInput('P3', 'P₃ (0 if none)', _p, initial: 0),
        const ChemInput('P4', 'P₄ (0 if none)', _p, initial: 0),
      ],
      solve: (x) {
        final ps = [x['P1']!, x['P2']!, x['P3']!, x['P4']!];
        for (final p in ps) {
          nonNegative(p, 'Pressure');
        }
        final t = ps.fold(0.0, (a, b) => a + b);
        return one('P_total', t, 'atm', ['P_total = ${ps.map(f).join(' + ')} = ${f(t)} atm']);
      },
    ),
  ],
);

final ChemSolver graham = ChemSolver(
  id: 'graham',
  group: 'Gas laws',
  title: "Graham's law",
  summary: 'Effusion rates: rate₁ / rate₂ = √(M₂ / M₁).',
  modes: [
    ChemMode(
      id: 'ratio',
      label: 'Rate ratio from molar masses',
      formula: 'rate₁ / rate₂ = √(M₂ / M₁)',
      inputs: [inp('M1', 'M₁ (gas 1)', 'g/mol'), inp('M2', 'M₂ (gas 2)', 'g/mol')],
      solve: (x) {
        positive(x['M1']!, 'M₁');
        positive(x['M2']!, 'M₂');
        final r = math.sqrt(x['M2']! / x['M1']!);
        return one('rate₁ / rate₂', r, '', [
          'rate₁ / rate₂ = √(M₂ / M₁)',
          '= √(${f(x['M2']!)} / ${f(x['M1']!)}) = ${f(r)}',
        ]);
      },
    ),
    ChemMode(
      id: 'm2',
      label: 'Molar mass of gas 2',
      formula: 'M₂ = M₁ · (rate₁ / rate₂)²',
      inputs: [inp('M1', 'M₁ (gas 1)', 'g/mol'), inp('ratio', 'rate₁ / rate₂', '')],
      solve: (x) {
        positive(x['M1']!, 'M₁');
        positive(x['ratio']!, 'Rate ratio');
        final r = x['M1']! * x['ratio']! * x['ratio']!;
        return one('M₂', r, 'g/mol', [
          'rate₁/rate₂ = √(M₂/M₁)  →  M₂ = M₁ · (rate₁/rate₂)²',
          'M₂ = ${f(x['M1']!)} × ${f(x['ratio']!)}² = ${f(r)} g/mol',
        ]);
      },
    ),
  ],
);

final ChemSolver vanDerWaals = ChemSolver(
  id: 'van_der_waals',
  group: 'Gas laws',
  title: 'van der Waals equation',
  summary: '(P + a n²/V²)(V − nb) = nRT for a real gas. a and b are specific to each gas (look them up).',
  modes: [
    ChemMode(
      id: 'p',
      label: 'Pressure P',
      formula: 'P = nRT / (V − nb) − a n² / V²',
      inputs: [
        nIn('n', 'moles n'),
        tIn('T', 'temperature T'),
        vIn('V', 'volume V'),
        inp('a', 'a', 'L²·atm/mol²'),
        inp('b', 'b', 'L/mol'),
      ],
      solve: (x) {
        final n = x['n']!, t = x['T']!, vol = x['V']!, a = x['a']!, b = x['b']!;
        positive(vol, 'Volume');
        positive(t, 'Temperature');
        need(vol > n * b, 'V must be larger than n·b');
        final p = n * rLAtm * t / (vol - n * b) - a * n * n / (vol * vol);
        return one('Pressure P', p, 'atm', [
          'P = nRT / (V − nb) − a n² / V²',
          'nRT/(V − nb) = (${f(n)} × $_r × ${f(t)}) / (${f(vol)} − ${f(n * b)}) = ${f(n * rLAtm * t / (vol - n * b))} atm',
          'a n²/V² = ${f(a)} × ${f(n)}² / ${f(vol)}² = ${f(a * n * n / (vol * vol))} atm',
          'P = ${f(p)} atm',
        ]);
      },
    ),
    ChemMode(
      id: 't',
      label: 'Temperature T',
      formula: 'T = (P + a n² / V²)(V − nb) / nR',
      inputs: [
        pIn('P', 'pressure P'),
        nIn('n', 'moles n'),
        vIn('V', 'volume V'),
        inp('a', 'a', 'L²·atm/mol²'),
        inp('b', 'b', 'L/mol'),
      ],
      solve: (x) {
        final p = x['P']!, n = x['n']!, vol = x['V']!, a = x['a']!, b = x['b']!;
        positive(vol, 'Volume');
        positive(n, 'Moles');
        need(vol > n * b, 'V must be larger than n·b');
        final t = (p + a * n * n / (vol * vol)) * (vol - n * b) / (n * rLAtm);
        return one('Temperature T', t, 'K', [
          'T = (P + a n² / V²)(V − nb) / nR',
          'P + a n²/V² = ${f(p)} + ${f(a * n * n / (vol * vol))} = ${f(p + a * n * n / (vol * vol))} atm',
          'V − nb = ${f(vol)} − ${f(n * b)} = ${f(vol - n * b)} L',
          'T = ${f(t)} K',
        ]);
      },
    ),
  ],
);

final List<ChemSolver> gasSolvers = [
  idealGas,
  combinedGas,
  boyle,
  charles,
  gayLussac,
  avogadroLaw,
  dalton,
  graham,
  vanDerWaals,
];
