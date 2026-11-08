import '../calc_error.dart';
import '../js_number.dart';
import 'element_types.dart';
import 'elements_lookup.dart';
import 'formula.dart';

/// Chemistry functions of the main calculator (Part 3.2): `molar("H2O")`, `atomic("Fe")`, `amass("Fe")`, `atomicsym(26)`.
///
/// [resolve] is the very first step of `MathEvaluator.evaluate`, before percent handling, sanitizing and the infix `nCr` /
/// `mod` regexes, so a formula such as `MnCr` inside the quotes can never be rewritten by them. Each call is replaced by
/// its number, so the results combine with ordinary arithmetic: `molar("H2O")*2`, `10/molar("NaCl")`.
class ChemCalcFunctions {
  ChemCalcFunctions._();

  static final RegExp _quick = RegExp(r'(molar|amass|atomicsym|atomic)\s*\(', caseSensitive: false);

  // name ( "text" )  with straight or curly double quotes, or single quotes
  static final RegExp _textCall = RegExp(
    r'''\b(molar|amass|atomicsym|atomic)\s*\(\s*(?:"([^"]*)"|“([^”]*)”|'([^']*)')\s*\)''',
    caseSensitive: false,
  );

  // name ( number )   (amass(26), atomic(26), atomicsym(26))
  static final RegExp _numCall = RegExp(
    r'\b(molar|amass|atomicsym|atomic)\s*\(\s*([0-9]+)\s*\)',
    caseSensitive: false,
  );

  /// Replaces every chemistry call in [expr] by its numeric value. Returns [expr] itself when there is none.
  static String resolve(String expr) {
    if (!_quick.hasMatch(expr)) return expr;
    var out = expr.replaceAllMapped(_textCall, (m) {
      final text = m[2] ?? m[3] ?? m[4] ?? '';
      return _literal(_call(m[1]!.toLowerCase(), text));
    });
    out = out.replaceAllMapped(_numCall, (m) {
      // molar(5) is not a formula: say so instead of a parser error
      if (m[1]!.toLowerCase() == 'molar') return m[0]!;
      return _literal(_call(m[1]!.toLowerCase(), m[2]!));
    });
    // anything left that still looks like a call has an argument we cannot read
    final left = _quick.firstMatch(out);
    if (left != null) {
      final name = left[1]!.toLowerCase();
      throw CalcError(switch (name) {
        'molar' => 'molar() needs a formula in quotes, e.g. molar("H2O")',
        'atomicsym' => 'atomicsym() needs an atomic number, e.g. atomicsym(26)',
        _ => '$name() needs an element in quotes, e.g. $name("Fe")',
      });
    }
    return out;
  }

  /// When the whole expression is `atomicsym(n)` the answer is text (the symbol). Returns null for anything else.
  static String? textResult(String expr) {
    final m = RegExp(r'^\s*atomicsym\s*\(\s*([0-9]+)\s*\)\s*$', caseSensitive: false).firstMatch(expr);
    if (m == null) return null;
    final z = int.parse(m[1]!);
    final el = ChemElements.byNumber(z);
    if (el == null) throw const CalcError('Atomic number must be 1 to 118');
    return el.symbol;
  }

  static String _literal(double v) => ' ${jsToString(v)} ';

  static double _call(String name, String arg) {
    switch (name) {
      case 'molar':
        return parseFormula(arg).molarMass;
      case 'amass':
        return _element(arg).mass;
      case 'atomic':
        return _element(arg).z.toDouble();
      default:
        throw const CalcError('atomicsym() gives text, so it cannot be used inside a calculation');
    }
  }

  static ChemElement _element(String arg) {
    final el = ChemElements.find(arg);
    if (el == null) throw CalcError('Unknown element "${arg.trim()}"');
    return el;
  }
}
