import '../calc_error.dart';
import 'chem_format.dart';
import 'elements_lookup.dart';
import 'formula.dart';
import 'solver_types.dart';
import 'solver_util.dart';

// ---------------------------------------------------------------------------------------------------------------
// exact fractions
// ---------------------------------------------------------------------------------------------------------------

class _Q {
  _Q(BigInt n, [BigInt? d]) {
    var den = d ?? BigInt.one;
    var num = n;
    if (den.isNegative) {
      den = -den;
      num = -num;
    }
    final g = num.gcd(den);
    if (g > BigInt.one) {
      num = num ~/ g;
      den = den ~/ g;
    }
    this.num = num;
    this.den = den;
  }

  factory _Q.i(int v) => _Q(BigInt.from(v));

  late final BigInt num;
  late final BigInt den;

  bool get isZero => num == BigInt.zero;
  _Q operator +(_Q o) => _Q(num * o.den + o.num * den, den * o.den);
  _Q operator -(_Q o) => _Q(num * o.den - o.num * den, den * o.den);
  _Q operator *(_Q o) => _Q(num * o.num, den * o.den);
  _Q operator /(_Q o) => _Q(num * o.den, den * o.num);
  _Q operator -() => _Q(-num, den);
}

BigInt _lcm(BigInt a, BigInt b) => a * b ~/ a.gcd(b);

// ---------------------------------------------------------------------------------------------------------------
// balancing
// ---------------------------------------------------------------------------------------------------------------

class EqSpecies {
  const EqSpecies(this.source, this.formula, this.coefficient);

  final String source;
  final ChemFormula formula;
  final int coefficient;

  String get pretty => prettyFormula(source);
}

class BalancedEquation {
  const BalancedEquation(this.reactants, this.products, this.steps);

  final List<EqSpecies> reactants;
  final List<EqSpecies> products;
  final List<String> steps;

  static String _side(List<EqSpecies> s) =>
      s.map((e) => e.coefficient == 1 ? e.pretty : '${e.coefficient} ${e.pretty}').join(' + ');

  String get text => '${_side(reactants)} → ${_side(products)}';
}

final RegExp _arrow = RegExp(r'<=>|<->|⇌|⟶|→|->|=>|=');

List<String> _splitSpecies(String side) {
  final t = side.trim();
  if (t.isEmpty) return [];
  var parts = t.split(RegExp(r'\s+\+\s+'));
  if (parts.length == 1 && t.contains('+') && !t.contains('^') && !RegExp('[⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻]').hasMatch(t)) {
    parts = t.split('+');
  }
  return [for (final p in parts) p.trim()];
}

String _stripCoefficient(String s) => s.replaceFirst(RegExp(r'^\d+\s*(?=[A-Za-z(\[{])'), '');

/// Balances `Fe2O3 + CO -> Fe + CO2` (also with charges, e.g. `MnO4^- + Fe^2+ + H+ -> Mn^2+ + Fe^3+ + H2O`).
///
/// Species are separated by ` + ` with spaces (needed when a species carries a `+` charge); without any charge a plain `+`
/// works too. Coefficients typed in the input are ignored. The coefficients come from the exact integer null space of the
/// element-and-charge matrix.
BalancedEquation balanceEquation(String input) {
  final text = input.trim();
  if (text.isEmpty) throw const CalcError('Enter an equation, e.g. Fe2O3 + CO -> Fe + CO2');
  final m = _arrow.firstMatch(text);
  if (m == null) throw const CalcError('Put an arrow between the two sides: ->, → or =');
  final left = _splitSpecies(text.substring(0, m.start));
  final right = _splitSpecies(text.substring(m.end));
  if (left.isEmpty || right.isEmpty) throw const CalcError('Both sides need at least one species');
  if (_arrow.hasMatch(text.substring(m.end))) throw const CalcError('Use only one arrow');

  final sources = [...left, ...right].map(_stripCoefficient).toList();
  final formulas = [for (final s in sources) parseFormula(s)];
  final nL = left.length;
  final n = formulas.length;

  // rows: every element key, then charge
  final keys = <String>[];
  for (final f in formulas) {
    for (final p in f.parts) {
      if (!keys.contains(p.key)) keys.add(p.key);
    }
  }
  for (final k in keys) {
    final onLeft = formulas.take(nL).any((f) => f.parts.any((p) => p.key == k));
    final onRight = formulas.skip(nL).any((f) => f.parts.any((p) => p.key == k));
    if (!onLeft || !onRight) {
      final shown = k.replaceAll(RegExp(r'^\d+'), '');
      throw CalcError('$shown appears on only one side, so the equation cannot be balanced');
    }
  }
  final hasCharge = formulas.any((f) => f.charge != 0);
  final rows = <List<_Q>>[];
  for (final k in keys) {
    rows.add([
      for (var j = 0; j < n; j++)
        _Q.i((j < nL ? 1 : -1) * (formulas[j].parts.where((p) => p.key == k).fold(0, (s, p) => s + p.count))),
    ]);
  }
  if (hasCharge) {
    rows.add([for (var j = 0; j < n; j++) _Q.i((j < nL ? 1 : -1) * formulas[j].charge)]);
  }

  // reduced row echelon form
  final pivots = <int>[];
  var r = 0;
  for (var c = 0; c < n && r < rows.length; c++) {
    var sel = -1;
    for (var i = r; i < rows.length; i++) {
      if (!rows[i][c].isZero) {
        sel = i;
        break;
      }
    }
    if (sel < 0) continue;
    final tmp = rows[r];
    rows[r] = rows[sel];
    rows[sel] = tmp;
    final pv = rows[r][c];
    rows[r] = [for (final v in rows[r]) v / pv];
    for (var i = 0; i < rows.length; i++) {
      if (i == r || rows[i][c].isZero) continue;
      final factor = rows[i][c];
      rows[i] = [for (var j = 0; j < n; j++) rows[i][j] - factor * rows[r][j]];
    }
    pivots.add(c);
    r++;
  }
  final free = [for (var c = 0; c < n; c++) if (!pivots.contains(c)) c];
  if (free.isEmpty) {
    throw const CalcError('This equation cannot be balanced. Check the formulas and the charges');
  }
  if (free.length > 1) {
    throw const CalcError('More than one balance is possible (it is a mix of separate reactions). Split it or remove species');
  }
  final fc = free.first;
  final vec = List<_Q>.filled(n, _Q.i(0));
  vec[fc] = _Q.i(1);
  for (var i = 0; i < pivots.length; i++) {
    vec[pivots[i]] = -rows[i][fc];
  }
  var l = BigInt.one;
  for (final v in vec) {
    l = _lcm(l, v.den);
  }
  var ints = [for (final v in vec) (v.num * (l ~/ v.den))];
  if (ints.every((v) => v <= BigInt.zero)) ints = [for (final v in ints) -v];
  if (ints.any((v) => v <= BigInt.zero)) {
    throw const CalcError('No all-positive balance exists: a species may be on the wrong side');
  }
  var g = ints.first;
  for (final v in ints) {
    g = g.gcd(v);
  }
  ints = [for (final v in ints) v ~/ g];
  if (ints.any((v) => v > BigInt.from(100000))) {
    throw const CalcError('The coefficients are too large to be meaningful. Check the formulas');
  }
  final coef = [for (final v in ints) v.toInt()];

  EqSpecies sp(int j, String s) => EqSpecies(j < nL ? left[j] : right[j - nL], formulas[j], coef[j]);
  final reactants = [for (var j = 0; j < nL; j++) sp(j, sources[j])];
  final products = [for (var j = nL; j < n; j++) sp(j, sources[j])];

  final steps = <String>[
    'Unknown coefficients for ${formulas.map((f) => prettyFormula(f.source)).join(', ')}',
    'One equation per ${hasCharge ? 'element and for charge' : 'element'}: atoms on the left = atoms on the right',
  ];
  for (final k in keys) {
    int side(Iterable<int> idx) => idx.fold(0, (s, j) => s + coef[j] * formulas[j].parts.where((p) => p.key == k).fold(0, (a, p) => a + p.count));
    final lc = side(List.generate(nL, (j) => j));
    final rc = side(List.generate(n - nL, (j) => j + nL));
    steps.add('${k.replaceAll(RegExp(r'^\d+'), '')}: $lc = $rc');
  }
  if (hasCharge) {
    int ch(Iterable<int> idx) => idx.fold(0, (s, j) => s + coef[j] * formulas[j].charge);
    steps.add('Charge: ${ch(List.generate(nL, (j) => j))} = ${ch(List.generate(n - nL, (j) => j + nL))}');
  }
  return BalancedEquation(reactants, products, steps);
}

// ---------------------------------------------------------------------------------------------------------------
// limiting reagent and yield
// ---------------------------------------------------------------------------------------------------------------

/// Limiting reagent, leftover, theoretical and percent yield for a balanced equation.
///
/// [reactantGrams] has one amount per reactant, in the order of the equation. [productIndex] picks the product whose yield
/// is wanted. [actualGrams] (optional) gives the percent yield.
ChemResult limitingReagent(BalancedEquation eq, List<double> reactantGrams, {int productIndex = 0, double? actualGrams}) {
  if (reactantGrams.length != eq.reactants.length) throw const CalcError('Enter an amount for every reactant');
  if (productIndex < 0 || productIndex >= eq.products.length) throw const CalcError('Pick a product');
  for (final g in reactantGrams) {
    if (!(g > 0) || !g.isFinite) throw const CalcError('Amounts must be positive numbers');
  }
  final steps = <String>['Balanced: ${eq.text}'];
  final extents = <double>[];
  final molesList = <double>[];
  for (var i = 0; i < eq.reactants.length; i++) {
    final s = eq.reactants[i];
    final mm = s.formula.molarMass;
    final mol = reactantGrams[i] / mm;
    molesList.add(mol);
    final ext = mol / s.coefficient;
    extents.add(ext);
    steps.add('${s.pretty}: ${f(reactantGrams[i])} g / ${f(mm)} g/mol = ${f(mol)} mol; ÷ coefficient ${s.coefficient} = ${f(ext)}');
  }
  var minExt = extents.first;
  for (final e in extents) {
    if (e < minExt) minExt = e;
  }
  final limiting = <int>[
    for (var i = 0; i < extents.length; i++)
      if ((extents[i] - minExt).abs() <= 1e-12 * minExt.abs()) i,
  ];
  final prod = eq.products[productIndex];
  final theoMol = minExt * prod.coefficient;
  final theoG = theoMol * prod.formula.molarMass;
  final outs = <ChemOutput>[];
  steps.add('Limiting reagent: ${limiting.map((i) => eq.reactants[i].pretty).join(' and ')} (smallest moles ÷ coefficient = ${f(minExt)})');
  steps.add('Theoretical ${prod.pretty}: ${f(minExt)} × ${prod.coefficient} = ${f(theoMol)} mol × ${f(prod.formula.molarMass)} g/mol = ${f(theoG)} g');
  outs.add(out('Limiting reagent', 0, limiting.map((i) => eq.reactants[i].pretty).join(', ')));
  outs.add(out('Theoretical yield of ${prod.pretty}', theoG, 'g'));
  for (var i = 0; i < eq.reactants.length; i++) {
    if (limiting.contains(i)) continue;
    final s = eq.reactants[i];
    final left = molesList[i] - s.coefficient * minExt;
    final leftG = left * s.formula.molarMass;
    outs.add(out('${s.pretty} left over', leftG, 'g'));
    steps.add('${s.pretty} left over: ${f(molesList[i])} − ${s.coefficient} × ${f(minExt)} = ${f(left)} mol = ${f(leftG)} g');
  }
  if (actualGrams != null) {
    if (!(actualGrams >= 0) || !actualGrams.isFinite) throw const CalcError('Actual yield must be 0 or more');
    final pct = actualGrams / theoG * 100;
    outs.add(out('Percent yield', pct, '%'));
    steps.add('Percent yield = actual / theoretical × 100 = ${f(actualGrams)} / ${f(theoG)} × 100 = ${f(pct)} %');
  }
  return ChemResult(outs, steps);
}

// ---------------------------------------------------------------------------------------------------------------
// numeric stoichiometry solvers (shown in the same list as the other formulas)
// ---------------------------------------------------------------------------------------------------------------

final ChemSolver molesMassParticles = ChemSolver(
  id: 'mole_conversions',
  group: 'Stoichiometry',
  title: 'Moles, mass and particles',
  summary: 'Convert with the molar mass M (from the Formula tab) and Avogadro’s number.',
  modes: [
    ChemMode(
      id: 'g_to_mol',
      label: 'Grams → moles',
      formula: 'n = m / M',
      inputs: [inp('m', 'mass m', 'g'), inp('M', 'molar mass M', 'g/mol')],
      solve: (x) {
        positive(x['M']!, 'Molar mass');
        final n = molesFromGrams(x['m']!, x['M']!);
        return ChemResult([out('Moles n', n, 'mol'), out('Particles', particlesFromMoles(n), '')], [
          'n = m / M = ${f(x['m']!)} / ${f(x['M']!)} = ${f(n)} mol',
          'N = n × NA = ${f(n)} × ${f(avogadro)} = ${f(particlesFromMoles(n))}',
        ]);
      },
    ),
    ChemMode(
      id: 'mol_to_g',
      label: 'Moles → grams',
      formula: 'm = n · M',
      inputs: [inp('n', 'moles n', 'mol'), inp('M', 'molar mass M', 'g/mol')],
      solve: (x) {
        final g = gramsFromMoles(x['n']!, x['M']!);
        return ChemResult([out('Mass m', g, 'g'), out('Particles', particlesFromMoles(x['n']!), '')], [
          'm = n · M = ${f(x['n']!)} × ${f(x['M']!)} = ${f(g)} g',
          'N = n × NA = ${f(particlesFromMoles(x['n']!))}',
        ]);
      },
    ),
    ChemMode(
      id: 'particles',
      label: 'Particles → moles and grams',
      formula: 'n = N / NA,  m = n · M',
      inputs: [inp('N', 'number of particles N', ''), inp('M', 'molar mass M', 'g/mol')],
      solve: (x) {
        final n = molesFromParticles(x['N']!);
        final g = gramsFromMoles(n, x['M']!);
        return ChemResult([out('Moles n', n, 'mol'), out('Mass m', g, 'g')], [
          'n = N / NA = ${f(x['N']!)} / ${f(avogadro)} = ${f(n)} mol',
          'm = n · M = ${f(n)} × ${f(x['M']!)} = ${f(g)} g',
        ]);
      },
    ),
  ],
);

final ChemSolver percentYield = ChemSolver(
  id: 'percent_yield',
  group: 'Stoichiometry',
  title: 'Percent yield',
  summary: 'actual yield / theoretical yield × 100.',
  modes: [
    ChemMode(
      id: 'pct',
      label: 'Percent yield',
      formula: '% yield = actual / theoretical × 100',
      inputs: [inp('act', 'actual yield', 'g'), inp('theo', 'theoretical yield', 'g')],
      solve: (x) {
        positive(x['theo']!, 'Theoretical yield');
        final p = x['act']! / x['theo']! * 100;
        return one('Percent yield', p, '%', ['% yield = (${f(x['act']!)} / ${f(x['theo']!)}) × 100 = ${f(p)} %']);
      },
    ),
    ChemMode(
      id: 'actual',
      label: 'Actual yield from percent',
      formula: 'actual = % × theoretical / 100',
      inputs: [inp('pct', 'percent yield', '%'), inp('theo', 'theoretical yield', 'g')],
      solve: (x) {
        final a = x['pct']! * x['theo']! / 100;
        return one('Actual yield', a, 'g', ['actual = ${f(x['pct']!)} % × ${f(x['theo']!)} g / 100 = ${f(a)} g']);
      },
    ),
  ],
);

/// Degrees of unsaturation of a formula typed as text (C, H, N and the halogens count; O and S do not).
double degreesOfUnsaturation(ChemFormula formula) {
  int count(String sym) => formula.parts.where((p) => p.symbol == sym).fold(0, (s, p) => s + p.count);
  final c = count('C'), h = count('H'), n = count('N');
  final x = count('F') + count('Cl') + count('Br') + count('I');
  for (final p in formula.parts) {
    if (!const {'C', 'H', 'N', 'O', 'S', 'F', 'Cl', 'Br', 'I'}.contains(p.symbol)) {
      throw CalcError('Degrees of unsaturation are for organic formulas (C, H, N, O, S, halogens). Found ${p.symbol}');
    }
  }
  need(c > 0, 'An organic formula needs at least one carbon');
  return (2 * c + 2 + n - h - x) / 2;
}

/// Molecular formula from an empirical formula and the compound's molar mass: scales every subscript by round(M / M_emp).
String molecularFormulaText(String empirical, double molarMass) {
  final f0 = parseFormula(empirical);
  final k = molecularMultiplier(molarMass, f0.molarMass);
  final b = StringBuffer();
  for (final p in f0.parts) {
    b.write(p.label);
    final c = p.count * k;
    if (c > 1) b.write(toSubscript('$c'));
  }
  return b.toString();
}

/// For the UI: element names for a formula's parts, e.g. `Fe` → Iron.
String elementName(String symbol) => ChemElements.bySymbol(symbol)?.name ?? symbol;
