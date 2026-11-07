import '../js_number.dart';

/// Number formatting shared by the chemistry screens and solvers (same style as the Physics Lab: plain numbers in the
/// middle range, `toExponential` at the ends). Never locale dependent.
String chemNum(double v, [int sig = 6]) {
  if (v.isNaN) return 'NaN';
  if (v.isInfinite) return v > 0 ? 'Infinity' : '-Infinity';
  if (v == 0) return '0';
  final a = v.abs();
  if (a >= 1e6 || a < 1e-3) {
    final s = jsToExponential(v, sig - 1);
    // 6.022140e+23 -> 6.02214e+23 (drop trailing zeros of the mantissa)
    final i = s.indexOf('e');
    var m = s.substring(0, i);
    if (m.contains('.')) {
      m = m.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return '$m${s.substring(i)}';
  }
  return jsToString(jsParseFloat(jsToPrecision(v, sig)));
}

const String _subDigits = '₀₁₂₃₄₅₆₇₈₉';
const String _supDigits = '⁰¹²³⁴⁵⁶⁷⁸⁹';

String toSubscript(String digits) => digits.split('').map((c) {
      final d = int.tryParse(c);
      return d == null ? c : _subDigits[d];
    }).join();

String toSuperscript(String text) => text.split('').map((c) {
      final d = int.tryParse(c);
      if (d != null) return _supDigits[d];
      if (c == '+') return '⁺';
      if (c == '-') return '⁻';
      return c;
    }).join();
