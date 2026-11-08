import '../calc_error.dart';
import 'chem_format.dart';
import 'elements_lookup.dart';

/// Avogadro constant, mol^-1 (exact since the 2019 SI redefinition).
const double avogadro = 6.02214076e23;

/// One line of a formula's breakdown.
class FormulaPart {
  const FormulaPart(this.key, this.symbol, this.massNumber, this.count, this.atomicMass);

  /// Map key: `Fe`, or `14C` for an isotope written with a mass number.
  final String key;
  final String symbol;

  /// Mass number when the formula wrote an isotope (`¹⁴C`), else null.
  final int? massNumber;
  final int count;

  /// g/mol used for one atom (the table's standard weight, or the mass number for an isotope).
  final double atomicMass;

  double get mass => atomicMass * count;
  String get label => massNumber == null ? symbol : '${toSuperscript('$massNumber')}$symbol';
}

/// A parsed chemical formula (Part 3.2).
class ChemFormula {
  ChemFormula._(this.parts, this.charge, this.source);

  final List<FormulaPart> parts;
  final int charge;
  final String source;

  /// g/mol. The mass of electrons gained or lost by a charged species is ignored (it is far below the table's precision).
  double get molarMass => parts.fold(0.0, (s, p) => s + p.mass);

  /// True when an isotope was given: its mass is approximated by the mass number (the table has no isotope masses).
  bool get hasIsotopes => parts.any((p) => p.massNumber != null);

  int get atomCount => parts.fold(0, (s, p) => s + p.count);

  /// Mass percent of each part, in the order of [parts].
  List<double> get massPercents {
    final m = molarMass;
    return [for (final p in parts) p.mass / m * 100];
  }

  /// `H₂SO₄`, `Fe³⁺`, `SO₄²⁻`. Hydrates are written as one flat formula, so `CuSO₄·5H₂O` shows as `CuH₁₀SO₉`-style counts
  /// in [parts]; use [source] for what was typed.
  String get display {
    final b = StringBuffer();
    for (final p in parts) {
      b.write(p.label);
      if (p.count > 1) b.write(toSubscript('${p.count}'));
    }
    if (charge != 0) {
      final n = charge.abs();
      b.write(toSuperscript('${n == 1 ? '' : n}${charge > 0 ? '+' : '-'}'));
    }
    return b.toString();
  }
}

const String _subs = '₀₁₂₃₄₅₆₇₈₉';
const String _sups = '⁰¹²³⁴⁵⁶⁷⁸⁹';

String _digitsFrom(String s, String table) {
  final b = StringBuffer();
  for (final c in s.split('')) {
    final i = table.indexOf(c);
    b.write(i >= 0 ? '$i' : c);
  }
  return b.toString();
}

/// Parses `Ca(OH)2`, `Al₂(SO₄)₃`, `[Fe(CN)6]4-`, `CuSO₄·5H₂O`, `CuSO4.5H2O`, `Fe³⁺`, `Fe+3`, `SO4^2-`, `¹⁴C`.
///
/// Charge forms: Unicode superscripts (`Fe³⁺`), `^` (`SO4^2-`, `Fe^3+`), sign first (`Fe+3`, `O-2`), a bare trailing sign
/// (`Na+`), a space (`SO4 2-`), or digits plus sign right after a closing bracket (`[Fe(CN)6]4-`). `Fe3+` is read as
/// three Fe atoms with charge +1, because a digit after a symbol is a subscript everywhere else.
ChemFormula parseFormula(String input) {
  var s = input.trim();
  if (s.isEmpty) throw const CalcError('Enter a formula');
  final source = s;

  // Unicode superscript run at the end = charge. Digits at the very start = isotope of the first element.
  int charge = 0;
  final supEnd = RegExp('[$_sups⁺⁻]+\$').firstMatch(s);
  if (supEnd != null && supEnd.start > 0) {
    charge = _chargeFrom(_digitsFrom(supEnd[0]!, _sups).replaceAll('⁺', '+').replaceAll('⁻', '-'));
    s = s.substring(0, supEnd.start);
  } else {
    final asciiCharge = _extractAsciiCharge(s);
    if (asciiCharge != null) {
      charge = asciiCharge.$2;
      s = asciiCharge.$1;
    }
  }

  s = _digitsFrom(s, _subs);
  // Hydrate dots: · • ∙ * and a plain '.'
  s = s.replaceAll(RegExp('[·•∙*.]'), '·').replaceAll(RegExp(r'\s+'), '');
  if (s.isEmpty) throw const CalcError('Enter a formula');

  final counts = <String, int>{};
  final meta = <String, (String, int?)>{};
  for (final raw in s.split('·')) {
    if (raw.isEmpty) throw const CalcError('Invalid formula near "·"');
    final lead = RegExp(r'^\d+').firstMatch(raw);
    final coeff = lead == null ? 1 : int.parse(lead[0]!);
    if (coeff == 0) throw const CalcError('A coefficient of 0 is not allowed');
    final body = lead == null ? raw : raw.substring(lead[0]!.length);
    if (body.isEmpty) throw CalcError('Invalid formula near "$raw"');
    final p = _Parser(body);
    final group = p.parseSequence(topLevel: true);
    if (!p.atEnd) throw CalcError('Invalid formula near "${p.rest}"');
    group.forEach((k, v) => counts[k] = (counts[k] ?? 0) + v * coeff);
    meta.addAll(p.meta);
  }

  final parts = <FormulaPart>[];
  counts.forEach((key, n) {
    final (sym, iso) = meta[key]!;
    final el = ChemElements.bySymbol(sym)!;
    parts.add(FormulaPart(key, sym, iso, n, iso == null ? el.mass : iso.toDouble()));
  });
  return ChemFormula._(parts, charge, source);
}

int _chargeFrom(String t) {
  // forms: "2+", "+2", "+", "-", "3-"
  final m = RegExp(r'^(\d*)([+-])(\d*)$').firstMatch(t);
  if (m == null) throw CalcError('Invalid charge "$t"');
  final n1 = m[1]!, n2 = m[3]!;
  final n = (n1.isNotEmpty ? int.parse(n1) : (n2.isNotEmpty ? int.parse(n2) : 1));
  return m[2] == '+' ? n : -n;
}

(String, int)? _extractAsciiCharge(String s) {
  // ^2-  ^-2  ^+  ^3+
  var m = RegExp(r'\^(\d*[+-]\d*|[+-])$').firstMatch(s);
  if (m != null && m.start > 0) return (s.substring(0, m.start), _chargeFrom(m[1]!));
  // space then charge: "SO4 2-"
  m = RegExp(r'\s+(\d*[+-])$').firstMatch(s);
  if (m != null && m.start > 0) return (s.substring(0, m.start), _chargeFrom(m[1]!));
  // digits + sign right after a closing bracket: "[Fe(CN)6]4-"
  m = RegExp(r'(?<=[\])}])(\d+[+-])$').firstMatch(s);
  if (m != null && m.start > 0) return (s.substring(0, m.start), _chargeFrom(m[1]!));
  // sign first: "Fe+3", "O-2"
  m = RegExp(r'(?<=[A-Za-z)\]}\d])([+-]\d+)$').firstMatch(s);
  if (m != null && m.start > 0) {
    // "Fe+3": the character before the sign must end an element or bracket, not a subscript digit
    return (s.substring(0, m.start), _chargeFrom(m[1]!));
  }
  // bare trailing sign: "Na+", "Cl-"
  m = RegExp(r'([+-])$').firstMatch(s);
  if (m != null && m.start > 0) return (s.substring(0, m.start), _chargeFrom(m[1]!));
  return null;
}

class _Parser {
  _Parser(this.s);

  final String s;
  int i = 0;
  final Map<String, (String, int?)> meta = {};

  bool get atEnd => i >= s.length;
  String get rest => s.substring(i);

  static const _open = '([{';
  static const _close = ')]}';

  Map<String, int> parseSequence({bool topLevel = false, String? closer}) {
    final out = <String, int>{};
    while (!atEnd) {
      final c = s[i];
      if (_close.contains(c)) {
        if (topLevel) throw const CalcError('Unbalanced brackets in formula');
        break;
      }
      if (_open.contains(c)) {
        final want = _close[_open.indexOf(c)];
        i++;
        final inner = parseSequence(closer: want);
        if (atEnd || s[i] != want) throw const CalcError('Unbalanced brackets in formula');
        i++;
        final mult = _readCount();
        inner.forEach((k, v) => out[k] = (out[k] ?? 0) + v * mult);
        continue;
      }
      final isotope = _readIsotope();
      final sym = _readSymbol();
      final count = _readCount();
      final key = isotope == null ? sym : '$isotope$sym';
      meta[key] = (sym, isotope);
      out[key] = (out[key] ?? 0) + count;
    }
    return out;
  }

  int? _readIsotope() {
    // ¹⁴C (superscript digits) or ^14C
    final sup = RegExp('^[$_sups]+').firstMatch(rest);
    if (sup != null) {
      i += sup[0]!.length;
      return int.parse(_digitsFrom(sup[0]!, _sups));
    }
    final caret = RegExp(r'^\^(\d+)(?=[A-Z])').firstMatch(rest);
    if (caret != null) {
      i += caret[0]!.length;
      return int.parse(caret[1]!);
    }
    return null;
  }

  String _readSymbol() {
    if (atEnd || !RegExp('[A-Z]').hasMatch(s[i])) {
      throw CalcError('Invalid formula near "${rest.isEmpty ? s : rest}"');
    }
    var sym = s[i];
    if (i + 1 < s.length && RegExp('[a-z]').hasMatch(s[i + 1])) sym += s[i + 1];
    if (ChemElements.bySymbol(sym) == null) {
      throw CalcError('Unknown element "$sym" in formula');
    }
    i += sym.length;
    return sym;
  }

  int _readCount() {
    final m = RegExp(r'^\d+').firstMatch(rest);
    if (m == null) return 1;
    i += m[0]!.length;
    final n = int.parse(m[0]!);
    if (n == 0) throw const CalcError('A subscript of 0 is not allowed');
    return n;
  }
}

/// Moles from grams: n = m / M.
double molesFromGrams(double grams, double molarMass) => grams / molarMass;

/// Grams from moles: m = n * M.
double gramsFromMoles(double moles, double molarMass) => moles * molarMass;

/// Particles from moles: N = n * NA.
double particlesFromMoles(double moles) => moles * avogadro;

/// Moles from particles: n = N / NA.
double molesFromParticles(double particles) => particles / avogadro;

/// Result of [empiricalFormula].
class EmpiricalResult {
  const EmpiricalResult(this.moles, this.ratios, this.multiplier, this.counts, this.empiricalMass);

  /// Moles of each input element (amount / atomic mass).
  final List<double> moles;

  /// Moles divided by the smallest one.
  final List<double> ratios;

  /// Smallest whole-number multiplier that made every ratio (almost) a whole number.
  final int multiplier;

  /// Whole-number subscripts in input order.
  final List<int> counts;
  final double empiricalMass;
}

/// Empirical formula from percent or mass data: [symbols] and the matching [amounts] (percent or grams: only the ratio
/// matters). Ratios within 0.1 of a whole number are rounded, trying multipliers 1..10.
EmpiricalResult empiricalFormula(List<String> symbols, List<double> amounts) {
  if (symbols.length != amounts.length || symbols.isEmpty) {
    throw const CalcError('Give an amount for every element');
  }
  final masses = <double>[];
  for (final sym in symbols) {
    final el = ChemElements.find(sym);
    if (el == null) throw CalcError('Unknown element "$sym"');
    masses.add(el.mass);
  }
  for (final a in amounts) {
    if (!(a > 0) || !a.isFinite) throw const CalcError('Amounts must be positive numbers');
  }
  final moles = [for (var k = 0; k < amounts.length; k++) amounts[k] / masses[k]];
  final least = moles.reduce((a, b) => a < b ? a : b);
  final ratios = [for (final m in moles) m / least];
  for (var mult = 1; mult <= 10; mult++) {
    final scaled = [for (final r in ratios) r * mult];
    if (scaled.every((v) => (v - v.roundToDouble()).abs() <= 0.1)) {
      final counts = [for (final v in scaled) v.round()];
      var mass = 0.0;
      for (var k = 0; k < counts.length; k++) {
        mass += counts[k] * masses[k];
      }
      return EmpiricalResult(moles, ratios, mult, counts, mass);
    }
  }
  throw const CalcError('No whole-number ratio found. Check the data');
}

/// Molecular formula multiplier: round(molar mass / empirical mass), at least 1.
int molecularMultiplier(double molarMass, double empiricalMass) {
  final n = (molarMass / empiricalMass).round();
  return n < 1 ? 1 : n;
}

/// Typeset version of what the user typed: digits after a symbol or bracket become subscripts, a charge becomes
/// superscripts, hydrate dots become `·`. Text that already has Unicode scripts is left alone. Never throws.
String prettyFormula(String input) {
  var s = input.trim();
  var charge = '';
  final asciiCharge = _extractAsciiCharge(s);
  if (asciiCharge != null && !RegExp('[$_sups⁺⁻]').hasMatch(s)) {
    s = asciiCharge.$1;
    final c = asciiCharge.$2;
    final n = c.abs();
    charge = toSuperscript('${n == 1 ? '' : n}${c > 0 ? '+' : '-'}');
  }
  s = s.replaceAll(RegExp('[•∙*]'), '·');
  s = s.replaceAllMapped(RegExp(r'(?<=[A-Za-z0-9)\]}])\.(?=\d)'), (_) => '·');
  s = s.replaceAllMapped(RegExp(r'(?<=[A-Za-z)\]}])(\d+)'), (m) => toSubscript(m[1]!));
  return '$s$charge';
}
