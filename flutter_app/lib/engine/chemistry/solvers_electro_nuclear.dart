import 'dart:math' as math;

import '../physics_constants.dart';
import 'chem_constants.dart';
import 'solver_types.dart';
import 'solver_util.dart';

double _phys(String id) => physicalConstants.firstWhere((c) => c.id == id).value;

// ---------------------------------------------------------------------------------------------------------------
// electrochemistry
// ---------------------------------------------------------------------------------------------------------------

final ChemSolver cellPotential = ChemSolver(
  id: 'cell_potential',
  group: 'Electrochemistry',
  title: 'Cell potential',
  summary: 'E°cell = E°cathode − E°anode (both as reduction potentials).',
  modes: [
    ChemMode(
      id: 'e',
      label: 'Standard cell potential',
      formula: 'E°cell = E°cathode − E°anode',
      inputs: [inp('Ec', 'E° of the cathode', 'V'), inp('Ea', 'E° of the anode', 'V')],
      solve: (x) {
        final e = x['Ec']! - x['Ea']!;
        return ChemResult([
          out('E°cell', e, 'V', note: e > 0 ? 'spontaneous (galvanic)' : (e < 0 ? 'not spontaneous' : 'at equilibrium')),
        ], [
          'E°cell = E°cathode − E°anode',
          'E°cell = ${f(x['Ec']!)} − (${f(x['Ea']!)}) = ${f(e)} V',
          e > 0 ? 'E°cell > 0: spontaneous as a galvanic cell' : (e < 0 ? 'E°cell < 0: not spontaneous (would need electrolysis)' : 'E°cell = 0: at equilibrium'),
        ]);
      },
    ),
  ],
);

final ChemSolver nernst = ChemSolver(
  id: 'nernst',
  group: 'Electrochemistry',
  title: 'Nernst equation',
  summary: 'E = E° − (RT / nF) ln Q.',
  modes: [
    ChemMode(
      id: 'e',
      label: 'Cell potential E',
      formula: 'E = E° − (R·T / n·F) · ln Q',
      inputs: [inp('E0', 'E°', 'V'), inp('n', 'electrons transferred n', ''), inp('Q', 'reaction quotient Q', ''), inp('T', 'temperature T', 'K', initial: 298.15)],
      solve: (x) {
        positive(x['n']!, 'n');
        positive(x['Q']!, 'Q');
        positive(x['T']!, 'Temperature');
        final corr = rJoule * x['T']! / (x['n']! * faraday) * math.log(x['Q']!);
        final e = x['E0']! - corr;
        return one('E', e, 'V', [
          'E = E° − (RT / nF) ln Q',
          'RT/nF = (${f(rJoule)} × ${f(x['T']!)}) / (${f(x['n']!)} × ${f(faraday)}) = ${f(rJoule * x['T']! / (x['n']! * faraday))} V',
          'E = ${f(x['E0']!)} − ${f(rJoule * x['T']! / (x['n']! * faraday))} × ln ${f(x['Q']!)} = ${f(e)} V',
        ]);
      },
    ),
    ChemMode(
      id: 'q',
      label: 'Reaction quotient Q from E',
      formula: 'Q = exp[(E° − E) · nF / RT]',
      inputs: [inp('E0', 'E°', 'V'), inp('E', 'E', 'V'), inp('n', 'electrons transferred n', ''), inp('T', 'temperature T', 'K', initial: 298.15)],
      solve: (x) {
        positive(x['n']!, 'n');
        positive(x['T']!, 'Temperature');
        final q = math.exp((x['E0']! - x['E']!) * x['n']! * faraday / (rJoule * x['T']!));
        return one('Q', finite(q), '', [
          'ln Q = (E° − E) · nF / RT',
          'Q = exp[(${f(x['E0']!)} − ${f(x['E']!)}) × ${f(x['n']!)} × ${f(faraday)} / (${f(rJoule)} × ${f(x['T']!)})] = ${f(q)}',
        ]);
      },
    ),
  ],
);

final ChemSolver faradayLaw = ChemSolver(
  id: 'faraday',
  group: 'Electrochemistry',
  title: "Faraday's laws of electrolysis",
  summary: 'm = I·t·M / (n·F).',
  modes: [
    ChemMode(
      id: 'm',
      label: 'Mass deposited m',
      formula: 'm = I · t · M / (n · F)',
      inputs: [inp('I', 'current I', 'A'), inp('t', 'time t', 's'), inp('M', 'molar mass M', 'g/mol'), inp('n', 'electrons per ion n', '')],
      solve: (x) {
        positive(x['n']!, 'n');
        final q = x['I']! * x['t']!;
        final mol = q / (x['n']! * faraday);
        final m = mol * x['M']!;
        return ChemResult([out('Charge Q', q, 'C'), out('Moles of substance', mol, 'mol'), out('Mass m', m, 'g')], [
          'Q = I · t = ${f(x['I']!)} × ${f(x['t']!)} = ${f(q)} C',
          'n(substance) = Q / (n·F) = ${f(q)} / (${f(x['n']!)} × ${f(faraday)}) = ${f(mol)} mol',
          'm = n(substance) × M = ${f(mol)} × ${f(x['M']!)} = ${f(m)} g',
        ]);
      },
    ),
    ChemMode(
      id: 't',
      label: 'Time needed',
      formula: 't = m · n · F / (I · M)',
      inputs: [inp('m', 'mass m', 'g'), inp('I', 'current I', 'A'), inp('M', 'molar mass M', 'g/mol'), inp('n', 'electrons per ion n', '')],
      solve: (x) {
        positive(x['I']!, 'Current');
        positive(x['M']!, 'Molar mass');
        final t = x['m']! * x['n']! * faraday / (x['I']! * x['M']!);
        return ChemResult([out('Time t', t, 's'), out('Time t', t / 3600, 'h')], [
          't = m · n · F / (I · M)',
          't = (${f(x['m']!)} × ${f(x['n']!)} × ${f(faraday)}) / (${f(x['I']!)} × ${f(x['M']!)}) = ${f(t)} s',
        ]);
      },
    ),
    ChemMode(
      id: 'i',
      label: 'Current needed',
      formula: 'I = m · n · F / (t · M)',
      inputs: [inp('m', 'mass m', 'g'), inp('t', 'time t', 's'), inp('M', 'molar mass M', 'g/mol'), inp('n', 'electrons per ion n', '')],
      solve: (x) {
        positive(x['t']!, 'Time');
        positive(x['M']!, 'Molar mass');
        final i = x['m']! * x['n']! * faraday / (x['t']! * x['M']!);
        return one('Current I', i, 'A', ['I = m · n · F / (t · M)', 'I = (${f(x['m']!)} × ${f(x['n']!)} × ${f(faraday)}) / (${f(x['t']!)} × ${f(x['M']!)}) = ${f(i)} A']);
      },
    ),
  ],
);

final ChemSolver gibbsCell = ChemSolver(
  id: 'dg_nfe',
  group: 'Electrochemistry',
  title: 'ΔG, E and K of a cell',
  summary: 'ΔG° = −nFE° and E° = (RT / nF) ln K.',
  modes: [
    ChemMode(
      id: 'dg',
      label: 'ΔG from E',
      formula: 'ΔG = −n · F · E',
      inputs: [inp('n', 'electrons n', ''), inp('E', 'E', 'V')],
      solve: (x) {
        positive(x['n']!, 'n');
        final dg = -x['n']! * faraday * x['E']! / 1000;
        return one('ΔG', dg, 'kJ/mol', ['ΔG = −nFE', 'ΔG = −${f(x['n']!)} × ${f(faraday)} × ${f(x['E']!)} / 1000 = ${f(dg)} kJ/mol']);
      },
    ),
    ChemMode(
      id: 'e',
      label: 'E from ΔG',
      formula: 'E = −ΔG / (n · F)',
      inputs: [inp('dG', 'ΔG', 'kJ/mol'), inp('n', 'electrons n', '')],
      solve: (x) {
        positive(x['n']!, 'n');
        final e = -x['dG']! * 1000 / (x['n']! * faraday);
        return one('E', e, 'V', ['E = −ΔG / (nF)', 'E = −(${f(x['dG']!)} × 1000) / (${f(x['n']!)} × ${f(faraday)}) = ${f(e)} V']);
      },
    ),
    ChemMode(
      id: 'k',
      label: 'K from E°',
      formula: 'K = exp(n·F·E° / R·T)',
      inputs: [inp('n', 'electrons n', ''), inp('E0', 'E°', 'V'), inp('T', 'temperature T', 'K', initial: 298.15)],
      solve: (x) {
        positive(x['n']!, 'n');
        positive(x['T']!, 'Temperature');
        final k = math.exp(x['n']! * faraday * x['E0']! / (rJoule * x['T']!));
        return one('K', finite(k), '', ['ln K = nFE° / RT', 'K = exp(${f(x['n']!)} × ${f(faraday)} × ${f(x['E0']!)} / (${f(rJoule)} × ${f(x['T']!)})) = ${f(k)}']);
      },
    ),
    ChemMode(
      id: 'e0',
      label: 'E° from K',
      formula: 'E° = (R·T / n·F) · ln K',
      inputs: [inp('n', 'electrons n', ''), inp('K', 'K', ''), inp('T', 'temperature T', 'K', initial: 298.15)],
      solve: (x) {
        positive(x['n']!, 'n');
        positive(x['K']!, 'K');
        positive(x['T']!, 'Temperature');
        final e = rJoule * x['T']! / (x['n']! * faraday) * math.log(x['K']!);
        return one('E°', e, 'V', ['E° = (RT / nF) ln K', 'E° = (${f(rJoule)} × ${f(x['T']!)} / (${f(x['n']!)} × ${f(faraday)})) × ln ${f(x['K']!)} = ${f(e)} V']);
      },
    ),
  ],
);

// ---------------------------------------------------------------------------------------------------------------
// nuclear
// ---------------------------------------------------------------------------------------------------------------

/// Mass of a ¹H atom (u) and of a neutron (u), CODATA 2018 / AME2016. Binding energy uses atomic masses, so the electrons cancel.
const double massH1u = 1.00782503223;
const double massNeutronU = 1.00866491595;

final ChemSolver radioactiveDecay = ChemSolver(
  id: 'decay',
  group: 'Nuclear',
  title: 'Half-life and decay',
  summary: 'N = N₀ · (½)^(t / t½).',
  modes: [
    ChemMode(
      id: 'n',
      label: 'Amount remaining',
      formula: 'N = N₀ · (1/2)^(t / t½)',
      inputs: [inp('N0', 'initial amount N₀', 'any unit'), inp('t', 'elapsed time t', 'same unit as t½'), inp('t12', 'half-life t½', '')],
      solve: (x) {
        positive(x['t12']!, 'Half-life');
        nonNegative(x['t']!, 'Time');
        final halves = x['t']! / x['t12']!;
        final n = x['N0']! * math.pow(0.5, halves);
        return ChemResult([out('Amount remaining N', n, ''), out('Fraction remaining', n / x['N0']!, ''), out('Half-lives elapsed', halves, '')], [
          'half-lives = t / t½ = ${f(x['t']!)} / ${f(x['t12']!)} = ${f(halves)}',
          'N = N₀ · (1/2)^${f(halves)} = ${f(n)}',
        ]);
      },
    ),
    ChemMode(
      id: 't',
      label: 'Time to decay to N',
      formula: 't = t½ · log₂(N₀ / N)',
      inputs: [inp('N0', 'initial amount N₀', 'any unit'), inp('N', 'amount N', 'same unit'), inp('t12', 'half-life t½', '')],
      solve: (x) {
        positive(x['N0']!, 'N₀');
        positive(x['N']!, 'N');
        positive(x['t12']!, 'Half-life');
        final t = x['t12']! * math.log(x['N0']! / x['N']!) / math.ln2;
        return one('Time t', t, 'same unit as t½', ['t = t½ · ln(N₀/N) / ln 2', 't = ${f(x['t12']!)} × ln(${f(x['N0']!)}/${f(x['N']!)}) / 0.693147 = ${f(t)}']);
      },
    ),
    ChemMode(
      id: 't12',
      label: 'Half-life from the fraction left',
      formula: 't½ = t · ln 2 / ln(N₀ / N)',
      inputs: [inp('N0', 'initial amount N₀', 'any unit'), inp('N', 'amount N', 'same unit'), inp('t', 'elapsed time t', '')],
      solve: (x) {
        positive(x['N0']!, 'N₀');
        positive(x['N']!, 'N');
        positive(x['t']!, 'Time');
        need(x['N']! != x['N0']!, 'N must differ from N₀');
        final t12 = x['t']! * math.ln2 / math.log(x['N0']! / x['N']!);
        return ChemResult([out('Half-life t½', t12, 'same unit as t'), out('Decay constant λ', math.ln2 / t12, '1 / time unit')], [
          't½ = t · ln 2 / ln(N₀/N)',
          't½ = ${f(x['t']!)} × 0.693147 / ln(${f(x['N0']!)}/${f(x['N']!)}) = ${f(t12)}',
          'λ = ln 2 / t½ = ${f(math.ln2 / t12)}',
        ]);
      },
    ),
  ],
);

final ChemSolver activity = ChemSolver(
  id: 'activity',
  group: 'Nuclear',
  title: 'Activity',
  summary: 'A = λ·N with λ = ln 2 / t½.',
  modes: [
    ChemMode(
      id: 'a',
      label: 'Activity from number of nuclei',
      formula: 'A = (ln 2 / t½) · N',
      inputs: [inp('N', 'number of nuclei N', ''), inp('t12', 'half-life t½', 's')],
      solve: (x) {
        positive(x['t12']!, 'Half-life');
        final lam = math.ln2 / x['t12']!;
        final a = lam * x['N']!;
        return ChemResult([out('Decay constant λ', lam, '1/s'), out('Activity A', a, 'Bq'), out('Activity A', a / 3.7e10, 'Ci')], [
          'λ = ln 2 / t½ = 0.693147 / ${f(x['t12']!)} = ${f(lam)} s⁻¹',
          'A = λ · N = ${f(lam)} × ${f(x['N']!)} = ${f(a)} Bq',
          '1 Ci = 3.7 × 10¹⁰ Bq  →  ${f(a / 3.7e10)} Ci',
        ]);
      },
    ),
    ChemMode(
      id: 'n',
      label: 'Number of nuclei from activity',
      formula: 'N = A · t½ / ln 2',
      inputs: [inp('A', 'activity A', 'Bq'), inp('t12', 'half-life t½', 's')],
      solve: (x) {
        positive(x['t12']!, 'Half-life');
        final n = x['A']! * x['t12']! / math.ln2;
        return one('Number of nuclei N', n, '', ['N = A / λ = A · t½ / ln 2', 'N = ${f(x['A']!)} × ${f(x['t12']!)} / 0.693147 = ${f(n)}']);
      },
    ),
  ],
);

final ChemSolver bindingEnergy = ChemSolver(
  id: 'binding',
  group: 'Nuclear',
  title: 'Mass defect and binding energy',
  summary: 'Δm = Z·m(¹H) + (A − Z)·mₙ − m(atom);  E = Δm · 931.494 MeV/u.',
  modes: [
    ChemMode(
      id: 'be',
      label: 'Binding energy',
      formula: 'E = [Z·m(¹H) + (A − Z)·mₙ − m(atom)] · 931.494 MeV/u',
      inputs: [inp('Z', 'protons Z', ''), inp('A', 'mass number A', ''), inp('m', 'atomic mass of the atom', 'u')],
      solve: (x) {
        final z = x['Z']!, a = x['A']!;
        need(z >= 1 && z == z.roundToDouble(), 'Z must be a whole number, 1 or more');
        need(a >= z && a == a.roundToDouble(), 'A must be a whole number, at least Z');
        positive(x['m']!, 'Atomic mass');
        final dm = z * massH1u + (a - z) * massNeutronU - x['m']!;
        final e = dm * uMeV;
        return ChemResult([out('Mass defect Δm', dm, 'u'), out('Binding energy', e, 'MeV'), out('Per nucleon', e / a, 'MeV')], [
          'Δm = Z·m(¹H) + (A − Z)·mₙ − m(atom)',
          'Δm = ${f(z)} × ${f(massH1u)} + ${f(a - z)} × ${f(massNeutronU)} − ${f(x['m']!)} = ${f(dm)} u',
          'E = Δm × ${f(uMeV)} MeV/u = ${f(e)} MeV',
          'Per nucleon = ${f(e)} / ${f(a)} = ${f(e / a)} MeV',
        ]);
      },
    ),
  ],
);

// ---------------------------------------------------------------------------------------------------------------
// quantum and atomic
// ---------------------------------------------------------------------------------------------------------------

final ChemSolver photon = ChemSolver(
  id: 'photon',
  group: 'Quantum & atomic',
  title: 'Photon energy, wavelength, frequency',
  summary: 'E = hf = hc / λ.',
  modes: [
    ChemMode(
      id: 'from_wl',
      label: 'From wavelength',
      formula: 'f = c / λ,  E = h·c / λ',
      inputs: [inp('wl', 'wavelength λ', 'nm')],
      solve: (x) => _photonFromWavelength(x['wl']! * 1e-9),
    ),
    ChemMode(
      id: 'from_f',
      label: 'From frequency',
      formula: 'λ = c / f,  E = h·f',
      inputs: [inp('f', 'frequency f', 'Hz')],
      solve: (x) {
        positive(x['f']!, 'Frequency');
        return _photonFromWavelength(_phys('c') / x['f']!);
      },
    ),
    ChemMode(
      id: 'from_ev',
      label: 'From energy',
      formula: 'λ = h·c / E',
      inputs: [inp('E', 'energy E', 'eV')],
      solve: (x) {
        positive(x['E']!, 'Energy');
        return _photonFromWavelength(_phys('h') * _phys('c') / (x['E']! * _phys('e')));
      },
    ),
  ],
);

ChemResult _photonFromWavelength(double wl) {
  positive(wl, 'Wavelength');
  final h = _phys('h'), c = _phys('c'), e = _phys('e');
  final freq = c / wl;
  final energy = h * freq;
  return ChemResult([
    out('Wavelength λ', wl * 1e9, 'nm'),
    out('Frequency f', freq, 'Hz'),
    out('Energy E', energy, 'J'),
    out('Energy E', energy / e, 'eV'),
    out('Energy per mole', energy * avogadroConst / 1000, 'kJ/mol'),
  ], [
    'f = c / λ = ${f(c)} / ${f(wl)} = ${f(freq)} Hz',
    'E = h · f = ${f(h)} × ${f(freq)} = ${f(energy)} J',
    'E in eV = E / e = ${f(energy / e)} eV',
    'Per mole = E × NA = ${f(energy * avogadroConst / 1000)} kJ/mol',
  ]);
}

double get avogadroConst => _phys('NA');

final ChemSolver bohr = ChemSolver(
  id: 'bohr',
  group: 'Quantum & atomic',
  title: 'Hydrogen-like atoms (Rydberg, Bohr)',
  summary: 'Energy levels, orbit radii and spectral lines for one-electron atoms.',
  modes: [
    ChemMode(
      id: 'line',
      label: 'Spectral line (Rydberg formula)',
      formula: '1/λ = R∞ · Z² · (1/n₁² − 1/n₂²)',
      inputs: [inp('Z', 'nuclear charge Z', '', initial: 1), inp('n1', 'lower level n₁', ''), inp('n2', 'upper level n₂', '')],
      solve: (x) {
        final z = x['Z']!, n1 = x['n1']!, n2 = x['n2']!;
        need(z >= 1 && z == z.roundToDouble(), 'Z must be a whole number, 1 or more');
        need(n1 >= 1 && n1 == n1.roundToDouble() && n2 == n2.roundToDouble(), 'Levels must be whole numbers, 1 or more');
        need(n2 > n1, 'n₂ must be larger than n₁');
        final inv = _phys('Rydberg') * z * z * (1 / (n1 * n1) - 1 / (n2 * n2));
        final wl = 1 / inv;
        final de = rydbergEv * z * z * (1 / (n1 * n1) - 1 / (n2 * n2));
        return ChemResult([
          out('Wavelength λ', wl * 1e9, 'nm'),
          out('Photon energy', de, 'eV'),
          out('Frequency f', _phys('c') / wl, 'Hz'),
        ], [
          '1/λ = R∞ · Z² · (1/n₁² − 1/n₂²) = ${f(_phys('Rydberg'))} × ${f(z * z)} × (1/${f(n1 * n1)} − 1/${f(n2 * n2)}) = ${f(inv)} m⁻¹',
          'λ = 1 / ${f(inv)} = ${f(wl * 1e9)} nm',
          'ΔE = ${f(rydbergEv)} eV × Z² × (1/n₁² − 1/n₂²) = ${f(de)} eV',
        ]);
      },
    ),
    ChemMode(
      id: 'level',
      label: 'Energy level and orbit radius',
      formula: 'Eₙ = −13.606 eV · Z² / n²,  rₙ = a₀ · n² / Z',
      inputs: [inp('Z', 'nuclear charge Z', '', initial: 1), inp('n', 'level n', '')],
      solve: (x) {
        final z = x['Z']!, n = x['n']!;
        need(z >= 1 && z == z.roundToDouble(), 'Z must be a whole number, 1 or more');
        need(n >= 1 && n == n.roundToDouble(), 'n must be a whole number, 1 or more');
        final en = -rydbergEv * z * z / (n * n);
        final rn = _phys('a0') * n * n / z;
        return ChemResult([out('Energy Eₙ', en, 'eV'), out('Energy Eₙ', en * _phys('e'), 'J'), out('Orbit radius rₙ', rn * 1e12, 'pm')], [
          'Eₙ = −${f(rydbergEv)} × ${f(z * z)} / ${f(n * n)} = ${f(en)} eV',
          'rₙ = a₀ · n² / Z = ${f(_phys('a0') * 1e12)} pm × ${f(n * n)} / ${f(z)} = ${f(rn * 1e12)} pm',
        ]);
      },
    ),
  ],
);

final ChemSolver deBroglie = ChemSolver(
  id: 'de_broglie',
  group: 'Quantum & atomic',
  title: 'de Broglie wavelength',
  summary: 'λ = h / (m·v).',
  modes: [
    ChemMode(
      id: 'wl',
      label: 'Wavelength from mass and speed',
      formula: 'λ = h / (m · v)',
      inputs: [inp('m', 'mass m', 'kg'), inp('v', 'speed v', 'm/s')],
      solve: (x) {
        positive(x['m']!, 'Mass');
        positive(x['v']!, 'Speed');
        final wl = _phys('h') / (x['m']! * x['v']!);
        return ChemResult([out('Wavelength λ', wl, 'm'), out('Wavelength λ', wl * 1e9, 'nm')], [
          'λ = h / (m·v)',
          'λ = ${f(_phys('h'))} / (${f(x['m']!)} × ${f(x['v']!)}) = ${f(wl)} m',
        ]);
      },
    ),
    ChemMode(
      id: 'v',
      label: 'Speed from wavelength',
      formula: 'v = h / (m · λ)',
      inputs: [inp('m', 'mass m', 'kg'), inp('wl', 'wavelength λ', 'm')],
      solve: (x) {
        positive(x['m']!, 'Mass');
        positive(x['wl']!, 'Wavelength');
        final v = _phys('h') / (x['m']! * x['wl']!);
        return one('Speed v', v, 'm/s', ['v = h / (m·λ)', 'v = ${f(_phys('h'))} / (${f(x['m']!)} × ${f(x['wl']!)}) = ${f(v)} m/s']);
      },
    ),
    ChemMode(
      id: 'electron',
      label: 'Electron accelerated through a voltage',
      formula: 'λ = h / √(2·mₑ·e·V)',
      inputs: [inp('V', 'accelerating voltage V', 'V')],
      solve: (x) {
        positive(x['V']!, 'Voltage');
        final p = math.sqrt(2 * _phys('me') * _phys('e') * x['V']!);
        final wl = _phys('h') / p;
        return ChemResult([out('Wavelength λ', wl * 1e12, 'pm')], [
          'p = √(2·mₑ·e·V) = √(2 × ${f(_phys('me'))} × ${f(_phys('e'))} × ${f(x['V']!)}) = ${f(p)} kg·m/s',
          'λ = h / p = ${f(_phys('h'))} / ${f(p)} = ${f(wl)} m = ${f(wl * 1e12)} pm',
          'Non-relativistic: accurate for voltages well below about 10 kV',
        ]);
      },
    ),
  ],
);

// ---------------------------------------------------------------------------------------------------------------
// organic helpers
// ---------------------------------------------------------------------------------------------------------------

final ChemSolver unsaturation = ChemSolver(
  id: 'unsaturation',
  group: 'Organic',
  title: 'Degrees of unsaturation',
  summary: 'Rings plus pi bonds from a molecular formula. Oxygen and sulfur do not change the count.',
  modes: [
    ChemMode(
      id: 'dou',
      label: 'From atom counts',
      formula: 'DoU = (2C + 2 + N − H − X) / 2',
      inputs: [
        inp('C', 'carbon atoms C', ''),
        inp('H', 'hydrogen atoms H', ''),
        inp('N', 'nitrogen atoms N', '', initial: 0),
        inp('X', 'halogen atoms X (F, Cl, Br, I)', '', initial: 0),
      ],
      solve: (x) {
        final c = x['C']!, h = x['H']!, n = x['N']!, hal = x['X']!;
        for (final v in [c, h, n, hal]) {
          need(v >= 0 && v == v.roundToDouble(), 'Atom counts must be whole numbers, 0 or more');
        }
        final dou = (2 * c + 2 + n - h - hal) / 2;
        return ChemResult([
          out('Degrees of unsaturation', dou, ''),
        ], [
          'DoU = (2C + 2 + N − H − X) / 2',
          'DoU = (2 × ${f(c)} + 2 + ${f(n)} − ${f(h)} − ${f(hal)}) / 2 = ${f(dou)}',
          if (dou < 0 || dou != dou.roundToDouble()) 'A negative or fractional value means the formula is not a neutral closed-shell molecule',
        ], message: dou < 0 || dou != dou.roundToDouble() ? 'Check the formula: DoU should be a whole number of 0 or more' : null);
      },
    ),
  ],
);

final ChemSolver molecularFromEmpirical = ChemSolver(
  id: 'mol_from_emp',
  group: 'Organic',
  title: 'Molecular formula multiplier',
  summary: 'n = molar mass / empirical-formula mass. Multiply every subscript of the empirical formula by n.',
  modes: [
    ChemMode(
      id: 'n',
      label: 'Multiplier n',
      formula: 'n = M / M_empirical',
      inputs: [inp('M', 'molar mass of the compound', 'g/mol'), inp('Me', 'empirical formula mass', 'g/mol')],
      solve: (x) {
        positive(x['M']!, 'Molar mass');
        positive(x['Me']!, 'Empirical mass');
        final raw = x['M']! / x['Me']!;
        final n = raw.round() < 1 ? 1 : raw.round();
        return ChemResult([out('n (rounded)', n.toDouble(), ''), out('Unrounded ratio', raw, '')], [
          'n = M / M_emp = ${f(x['M']!)} / ${f(x['Me']!)} = ${f(raw)}',
          'Round to the nearest whole number: n = $n',
        ]);
      },
    ),
  ],
);

final List<ChemSolver> electroSolvers = [cellPotential, nernst, faradayLaw, gibbsCell];
final List<ChemSolver> nuclearSolvers = [radioactiveDecay, activity, bindingEnergy];
final List<ChemSolver> quantumSolvers = [photon, bohr, deBroglie];
final List<ChemSolver> organicSolvers = [unsaturation, molecularFromEmpirical];
