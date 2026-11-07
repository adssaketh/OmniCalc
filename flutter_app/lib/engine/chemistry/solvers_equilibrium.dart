import 'dart:math' as math;

import 'chem_constants.dart';
import 'solver_types.dart';
import 'solver_util.dart';

final ChemSolver kcKp = ChemSolver(
  id: 'kc_kp',
  group: 'Equilibrium',
  title: 'Kc ↔ Kp',
  summary: 'Kp = Kc (RT)^Δn, with R = 0.082057 L·atm/(mol·K) and pressures in atm.',
  modes: [
    ChemMode(
      id: 'kp',
      label: 'Kp from Kc',
      formula: 'Kp = Kc · (RT)^Δn',
      inputs: [inp('Kc', 'Kc', ''), inp('T', 'temperature T', 'K'), inp('dn', 'Δn (gas moles products − reactants)', '')],
      solve: (x) {
        positive(x['T']!, 'Temperature');
        final rt = rLAtm * x['T']!;
        final kp = x['Kc']! * math.pow(rt, x['dn']!);
        return one('Kp', finite(kp), '', [
          'Kp = Kc · (RT)^Δn',
          'RT = ${f(rLAtm)} × ${f(x['T']!)} = ${f(rt)}',
          'Kp = ${f(x['Kc']!)} × ${f(rt)}^${f(x['dn']!)} = ${f(kp)}',
        ]);
      },
    ),
    ChemMode(
      id: 'kc',
      label: 'Kc from Kp',
      formula: 'Kc = Kp / (RT)^Δn',
      inputs: [inp('Kp', 'Kp', ''), inp('T', 'temperature T', 'K'), inp('dn', 'Δn (gas moles products − reactants)', '')],
      solve: (x) {
        positive(x['T']!, 'Temperature');
        final rt = rLAtm * x['T']!;
        final kc = x['Kp']! / math.pow(rt, x['dn']!);
        return one('Kc', finite(kc), '', [
          'Kc = Kp / (RT)^Δn',
          'RT = ${f(rLAtm)} × ${f(x['T']!)} = ${f(rt)}',
          'Kc = ${f(x['Kp']!)} / ${f(rt)}^${f(x['dn']!)} = ${f(kc)}',
        ]);
      },
    ),
  ],
);

/// Species of the generic reaction aA + bB ⇌ cC + dD used by the ICE and Q solvers.
class _Species {
  _Species(this.name, this.coef, this.conc, this.isProduct);
  final String name;
  final double coef;
  final double conc;
  final bool isProduct;
}

List<_Species> _species(Map<String, double> x) {
  final list = <_Species>[];
  void add(String name, String c, String conc, bool prod) {
    final coef = x[c]!;
    need(coef >= 0 && coef == coef.roundToDouble(), 'Coefficients must be whole numbers, 0 or more');
    need(x[conc]! >= 0, 'Concentrations cannot be negative');
    if (coef > 0) list.add(_Species(name, coef, x[conc]!, prod));
  }

  add('A', 'a', 'A0', false);
  add('B', 'b', 'B0', false);
  add('C', 'c', 'C0', true);
  add('D', 'd', 'D0', true);
  need(list.any((s) => !s.isProduct), 'Give at least one reactant (coefficient above 0)');
  need(list.any((s) => s.isProduct), 'Give at least one product (coefficient above 0)');
  return list;
}

double _lnQ(List<_Species> sp, double extent) {
  var s = 0.0;
  for (final k in sp) {
    final c = k.isProduct ? k.conc + k.coef * extent : k.conc - k.coef * extent;
    final term = k.coef * math.log(c); // log(0) = -Infinity
    s += k.isProduct ? term : -term;
  }
  return s;
}

/// Extent x of reaction that makes Q = K. Q rises monotonically with x, so bisection finds the single physical root.
double _solveExtent(List<_Species> sp, double k) {
  var hi = double.infinity;
  var lo = double.negativeInfinity;
  for (final s in sp) {
    if (!s.isProduct) {
      hi = math.min(hi, s.conc / s.coef);
    } else {
      lo = math.max(lo, -s.conc / s.coef);
    }
  }
  if (lo == double.negativeInfinity) lo = 0;
  final target = math.log(k);
  var a = lo, b = hi;
  for (var i = 0; i < 400; i++) {
    final mid = (a + b) / 2;
    if (mid == a || mid == b) break;
    final g = _lnQ(sp, mid) - target;
    if (g.isNaN) break;
    if (g < 0) {
      a = mid;
    } else {
      b = mid;
    }
  }
  return (a + b) / 2;
}

const List<ChemInput> _speciesInputs = [
  ChemInput('a', 'coefficient a (A)', '', initial: 1),
  ChemInput('A0', '[A]', 'mol/L'),
  ChemInput('b', 'coefficient b (B, 0 if none)', '', initial: 0),
  ChemInput('B0', '[B]', 'mol/L', initial: 0),
  ChemInput('c', 'coefficient c (C)', '', initial: 1),
  ChemInput('C0', '[C]', 'mol/L', initial: 0),
  ChemInput('d', 'coefficient d (D, 0 if none)', '', initial: 0),
  ChemInput('D0', '[D]', 'mol/L', initial: 0),
];

final ChemSolver ice = ChemSolver(
  id: 'ice',
  group: 'Equilibrium',
  title: 'ICE table and Q vs K',
  summary: 'aA + bB ⇌ cC + dD. Equilibrium concentrations from initial ones and K, or the direction from Q.',
  modes: [
    ChemMode(
      id: 'ice',
      label: 'Equilibrium concentrations (ICE)',
      formula: 'K = [C]^c [D]^d / ([A]^a [B]^b)',
      inputs: [..._speciesInputs, const ChemInput('K', 'equilibrium constant K', '')],
      solve: (x) {
        positive(x['K']!, 'K');
        final sp = _species(x);
        final k = x['K']!;
        final ext = _solveExtent(sp, k);
        final eq = <ChemOutput>[];
        final steps = <String>['Let x be the extent of reaction (each species changes by its coefficient × x).'];
        for (final s in sp) {
          final c = s.isProduct ? s.conc + s.coef * ext : s.conc - s.coef * ext;
          final sign = s.isProduct ? '+' : '−';
          final coefText = s.coef == 1 ? '' : f(s.coef);
          steps.add('[${s.name}]: initial ${f(s.conc)}, change $sign$coefText x, equilibrium ${f(c)} mol/L');
          eq.add(out('[${s.name}] at equilibrium', c, 'mol/L'));
        }
        final q0 = math.exp(_lnQ(sp, 0));
        steps.add('K = ${f(k)} gives x = ${f(ext)} mol/L (solved exactly, no approximation)');
        steps.add('Initial Q = ${f(q0)}${q0 < k ? ' < K, so the reaction goes forward' : (q0 > k ? ' > K, so the reaction goes in reverse' : ' = K, already at equilibrium')}');
        return ChemResult([...eq, out('Extent x', ext, 'mol/L')], steps);
      },
    ),
    ChemMode(
      id: 'q',
      label: 'Reaction quotient Q vs K',
      formula: 'Q = [C]^c [D]^d / ([A]^a [B]^b)',
      inputs: [..._speciesInputs, const ChemInput('K', 'equilibrium constant K', '')],
      solve: (x) {
        positive(x['K']!, 'K');
        final sp = _species(x);
        final lq = _lnQ(sp, 0);
        need(!lq.isNaN, 'Check the concentrations');
        final q = math.exp(lq);
        final k = x['K']!;
        final String msg;
        if (q.isInfinite) {
          msg = 'A reactant concentration is 0, so Q is infinite: the reaction shifts toward the reactants (reverse)';
        } else if ((q - k).abs() <= 1e-9 * math.max(q.abs(), k.abs())) {
          msg = 'Q = K: the system is at equilibrium';
        } else if (q < k) {
          msg = 'Q < K: the reaction shifts to the right (toward products)';
        } else {
          msg = 'Q > K: the reaction shifts to the left (toward reactants)';
        }
        return ChemResult([out('Q', q, ''), out('K', k, '')], [
          'Q = (products) / (reactants) with the concentrations given = ${f(q)}',
          'K = ${f(k)}',
          msg,
        ], message: msg);
      },
    ),
  ],
);

/// For tests: the extent of reaction for the solver's input map (coefficients a..d, concentrations A0..D0, and K).
double iceExtent(Map<String, double> values) => _solveExtent(_species(values), values['K']!);

final List<ChemSolver> equilibriumSolvers = [kcKp, ice];
