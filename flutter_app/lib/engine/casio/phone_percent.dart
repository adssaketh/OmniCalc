// OmniCalc's phone-style percent, copied from `MathEvaluator._applyPercent` (the TypeScript oracle's behaviour). The Casio
// engine keeps this as its one deliberate exception (Part 9, section 9.1): `100+10%` = 110, `100×10%` = 10, `200−10%` = 180,
// `50%` alone = 0.5. The legacy evaluator is not touched; this is a copy of a pure string function.

import '../calc_error.dart';

class PhonePercent {
  const PhonePercent._();

  static final RegExp _reTrailingPercent = RegExp(r'^(.*[^+\-−×÷*\/^(,\s])\s*([+\-−])\s*(\d+(?:\.\d+)?)%$');
  static final RegExp _rePercentOperand = RegExp(r'(\d+(?:\.\d+)?|π|\be)$');

  static String apply(String expr) {
    if (!expr.contains('%')) return expr;
    var current = expr.trim();

    final trailing = _reTrailingPercent.firstMatch(current);
    if (trailing != null) {
      final sign = trailing[2] == '+' ? '+' : '-';
      return apply('(${trailing[1]})×(1$sign${trailing[3]}÷100)');
    }

    for (var guard = 0; guard < 50; guard++) {
      final idx = current.indexOf('%');
      if (idx == -1) break;
      var start = idx;
      if (idx > 0 && current[idx - 1] == ')') {
        var depth = 0;
        for (var i = idx - 1; i >= 0; i--) {
          if (current[i] == ')') {
            depth++;
          } else if (current[i] == '(') {
            depth--;
            if (depth == 0) {
              start = i;
              break;
            }
          }
        }
        if (start == idx) throw const CalcError('Mismatched parentheses');
      } else {
        final m = _rePercentOperand.firstMatch(current.substring(0, idx));
        if (m == null) throw const CalcError('Invalid syntax: % needs a number before it');
        start = idx - m[0]!.length;
      }
      current = '${current.substring(0, start)}(${current.substring(start, idx)}÷100)${current.substring(idx + 1)}';
    }
    return current;
  }
}
