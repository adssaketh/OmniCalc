// Line-by-line port of src/engine/evaluator.ts (the oracle). Do not "clean this up": the quirks are
// part of the visible behaviour (sanitize order, phone-style percent, regex tokenizer, numerical step
// sizes, error strings). Every deliberate oddity below is a faithful copy of the TypeScript.

import 'dart:math' as math;

import 'calc_error.dart';
import 'chemistry/calc_functions.dart';
import 'js_number.dart';
import 'types.dart';

class MathEvaluator {
  MathEvaluator._();

  /// The equation saved with `y = ...` (written in x). `y(4)` then gives its value at x = 4.
  static String? _yDefinition;

  static void setYDefinition(String? def) {
    _yDefinition = def;
  }

  static String? getYDefinition() => _yDefinition;

  // -------------------------------------------------------------------------------------------
  // sanitize (order matters)
  // -------------------------------------------------------------------------------------------

  static final RegExp _reSgn = RegExp(r'\bsgn\s*\(', caseSensitive: false);
  static final RegExp _reSqrtShort = RegExp(r'√([0-9.a-zA-Zπe]+)');
  static final RegExp _reCbrtShort = RegExp(r'³√([0-9.a-zA-Zπe]+)');

  static final List<(RegExp, String)> _constantRules = <(RegExp, String)>[
    (RegExp(r'\bhbar\b|ħ'), ' 1.054571817e-34 '),
    (RegExp(r'\bh\b'), ' 6.62607015e-34 '),
    (RegExp(r'\bc\b'), ' 299792458 '),
    (RegExp(r'\bG\b'), ' 6.67430e-11 '),
    (RegExp(r'\bqe\b|\bq_e\b'), ' 1.602176634e-19 '),
    (RegExp(r'\bme\b|\bm_e\b'), ' 9.1093837e-31 '),
    (RegExp(r'\bmp\b|\bm_p\b'), ' 1.67262192e-27 '),
    (RegExp(r'\bkB\b|\bk_B\b'), ' 1.380649e-23 '),
    (RegExp(r'\bNA\b|\bN_A\b'), ' 6.02214076e23 '),
    (RegExp(r'\beps0\b|ε₀|ε0'), ' 8.8541878128e-12 '),
    (RegExp(r'\bmu0\b|μ₀|μ0'), ' 1.256637062e-6 '),
    (RegExp(r'\bke\b'), ' 8.9875517923e9 '),
    (RegExp(r'\bmn\b|\bm_n\b'), ' 1.67492749804e-27 '),
    (RegExp(r'\bR\b'), ' 8.314462618 '),
    (RegExp(r'\bsigma\b|σ'), ' 5.670374419e-8 '),
    (RegExp(r'\batm\b'), ' 101325 '),
    (RegExp(r'\bau\b'), ' 1.495978707e11 '),
    (RegExp(r'\bg\b'), ' 9.80665 '),
    (RegExp(r'\be\b'), ' E '),
  ];

  static String _sanitizeExpression(String expr) {
    var s = expr;
    s = s.replaceAll(_reSgn, 'sign(');
    s = s.replaceAll('×', '*');
    s = s.replaceAll('÷', '/');
    s = s.replaceAll('−', '-');
    s = s.replaceAll('√(', 'sqrt(');
    s = s.replaceAllMapped(_reSqrtShort, (m) => 'sqrt(${m[1]})');
    s = s.replaceAll('³√(', 'cbrt(');
    s = s.replaceAllMapped(_reCbrtShort, (m) => 'cbrt(${m[1]})');
    s = s.replaceAll('π', ' PI ');
    for (final (re, rep) in _constantRules) {
      s = s.replaceAll(re, rep);
    }
    s = s.replaceAll('φ', ' PHI ');
    return s.trim();
  }

  // -------------------------------------------------------------------------------------------
  // percent, phone style
  // -------------------------------------------------------------------------------------------

  static final RegExp _reTrailingPercent =
      RegExp(r'^(.*[^+\-−×÷*\/^(,\s])\s*([+\-−])\s*(\d+(?:\.\d+)?)%$');
  static final RegExp _rePercentOperand = RegExp(r'(\d+(?:\.\d+)?|π|\be)$');

  /// Percent, the way phone calculators do it:
  ///   50%          -> 0.5          200×15%  -> 30
  ///   200+10%      -> 220          200−10%  -> 180
  static String _applyPercent(String expr) {
    if (!expr.contains('%')) return expr;
    var current = expr.trim();

    // Trailing "+ N%" or "− N%": N percent of the whole left-hand side
    final trailing = _reTrailingPercent.firstMatch(current);
    if (trailing != null) {
      final sign = trailing[2] == '+' ? '+' : '-';
      return _applyPercent('(${trailing[1]})×(1$sign${trailing[3]}÷100)');
    }

    // Any other "x%" means x / 100. A bracketed group is divided as a whole.
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

  // -------------------------------------------------------------------------------------------
  // tokenizer
  // -------------------------------------------------------------------------------------------

  static final RegExp _reNumOrConst = RegExp(r'^(\d+(\.\d+)?([eE][+-]?\d+)?|PI|E|PHI)$');
  static final RegExp _reFunc = RegExp(
      r'^(sin|cos|tan|asin|acos|atan|sinh|cosh|tanh|asinh|acosh|atanh|sec|csc|cot|sech|csch|coth|ln|log|log2|exp|sqrt|cbrt|abs|round|floor|ceil|sign)$',
      caseSensitive: false);
  static final RegExp _reToken = RegExp(
      r'\d+(\.\d+)?([eE][+-]?\d+)?|exp|PI|E|PHI|asinh|acosh|atanh|sech|csch|coth|sinh|cosh|tanh|asin|acos|atan|sec|csc|cot|sin|cos|tan|log2|log|ln|exp|cbrt|sqrt|round|floor|ceil|sign|abs|\+|-|\*|\/|\^|%|!|\(|\)',
      caseSensitive: false);
  static final RegExp _reNumberToken = RegExp(r'^\d+(\.\d+)?([eE][+-]?\d+)?$', caseSensitive: false);

  static bool _isFunc(String t) => _reFunc.hasMatch(t);

  // Preprocess implicit multiplications like "2(3)" -> "2*(3)", "5sin(30)" -> "5*sin(30)"
  static List<String> _addImplicitMultiplication(List<String> tokens) {
    final output = <String>[];
    bool isNumOrConst(String t) => _reNumOrConst.hasMatch(t);
    bool isCloseParen(String t) => t == ')';
    bool isOpenParen(String t) => t == '(';

    for (var i = 0; i < tokens.length; i++) {
      final curr = tokens[i];
      output.add(curr);

      if (i < tokens.length - 1) {
        final next = tokens[i + 1];
        if ((isNumOrConst(curr) && (isOpenParen(next) || _isFunc(next) || isNumOrConst(next))) ||
            (isCloseParen(curr) && (isOpenParen(next) || isNumOrConst(next) || _isFunc(next))) ||
            (curr == '!' && (isOpenParen(next) || isNumOrConst(next) || _isFunc(next)))) {
          output.add('*');
        }
      }
    }
    return output;
  }

  static List<String> _tokenize(String expr) {
    final raw = _sanitizeExpression(expr);
    final matches = _reToken.allMatches(raw).map((m) => m[0]!).toList();
    if (matches.isEmpty) return <String>[];
    return _addImplicitMultiplication(matches);
  }

  // -------------------------------------------------------------------------------------------
  // discrete helpers
  // -------------------------------------------------------------------------------------------

  static double factorial(double n) {
    if (n < 0 || !jsIsInteger(n)) throw const CalcError('Factorial requires non-negative integer');
    if (n == 0 || n == 1) return 1;
    if (n > 170) return double.infinity; // JS number overflow
    double res = 1;
    for (double i = 2; i <= n; i++) {
      res *= i;
    }
    return res;
  }

  static double permutations(double n, double r) {
    if (n < 0 || r < 0 || !jsIsInteger(n) || !jsIsInteger(r) || r > n) {
      throw const CalcError('nPr requires integers with 0 <= r <= n');
    }
    double res = 1;
    for (double i = 0; i < r; i++) {
      res *= n - i;
    }
    return res;
  }

  static double combinations(double n, double r) {
    if (n < 0 || r < 0 || !jsIsInteger(n) || !jsIsInteger(r) || r > n) {
      throw const CalcError('nCr requires integers with 0 <= r <= n');
    }
    if (r == 0 || r == n) return 1;
    final k = math.min(r, n - r);
    double res = 1;
    for (double i = 1; i <= k; i++) {
      res = (res * (n - k + i)) / i;
    }
    return jsRound(res);
  }

  static double gcd(double a, double b) {
    var x = jsRound(a).abs();
    var y = jsRound(b).abs();
    while (y != 0) {
      final t = y;
      y = jsMod(x, y);
      x = t;
    }
    return x;
  }

  static double lcm(double a, double b) {
    final x = jsRound(a);
    final y = jsRound(b);
    if (x == 0 || y == 0) return 0;
    return (x * y).abs() / gcd(x, y);
  }

  // -------------------------------------------------------------------------------------------
  // calculus kernels (numerical; step sizes and tolerances are part of the visible results)
  // -------------------------------------------------------------------------------------------

  // Numerical derivative d/dx f(x) evaluated at xVal using 5-point stencil
  static double numericalDerivative(String funcExpr, double xVal, [AngleMode angleMode = AngleMode.rad]) {
    // 1e-3 keeps round-off small (diff(x^2, 3) gives 6, not 6.00000000005); near zero the step shrinks
    // so points like x = 0.002 stay inside the domain of ln(x), sqrt(x) ...
    double h = 1e-3 * math.max(1.0, xVal.abs());
    if (xVal != 0 && xVal.abs() < 4 * h) h = math.max(xVal.abs() / 4, 1e-6);
    double f(double x) => evaluateFunction(funcExpr, x, angleMode);

    final fPlus2h = f(xVal + 2 * h);
    final fPlusH = f(xVal + h);
    final fMinusH = f(xVal - h);
    final fMinus2h = f(xVal - 2 * h);

    if (fPlusH.isNaN || fMinusH.isNaN) {
      // Fallback to one-sided forward difference
      final fCurr = f(xVal);
      final fFwd = f(xVal + h);
      return (fFwd - fCurr) / h;
    }

    return (-fPlus2h + 8 * fPlusH - 8 * fMinusH + fMinus2h) / (12 * h);
  }

  // Definite numerical integration using composite Simpson's 1/3 rule (N = 1000)
  static double numericalIntegration(String funcExpr, double a, double b, [AngleMode angleMode = AngleMode.rad]) {
    if (a == b) return 0;
    final isReversed = a > b;
    final start = isReversed ? b : a;
    final end = isReversed ? a : b;

    const n = 1000; // Must be even
    final h = (end - start) / n;
    double f(double x) => evaluateFunction(funcExpr, x, angleMode);

    double sum = f(start) + f(end);
    for (var i = 1; i < n; i++) {
      final x = start + i * h;
      final fx = f(x);
      if (fx.isNaN) throw CalcError('Integration error at x = ${jsToString(x)}');
      sum += (i % 2 == 1 ? 4 : 2) * fx;
    }

    final result = (h / 3) * sum;
    return isReversed ? -result : result;
  }

  // Limit of f(x) as x -> a (two-sided). Looks at both sides at two distances: for a real limit the two
  // sides close in on each other and the average settles; a jump or a pole keeps them apart.
  static double numericalLimit(String funcExpr, double a, [AngleMode angleMode = AngleMode.rad]) {
    double f(double x) => evaluateFunction(funcExpr, x, angleMode);
    List<double> sides(double h) => <double>[f(a - h), f(a + h)];

    final s1 = sides(2e-3);
    final s2 = sides(1e-3);
    final l1 = s1[0], r1 = s1[1], l2 = s2[0], r2 = s2[1];
    if (![l1, r1, l2, r2].every((v) => v.isFinite)) {
      throw const CalcError('Limit does not exist (function is undefined near this point)');
    }

    final g1 = (l1 + r1) / 2;
    final g2 = (l2 + r2) / 2;
    final scale = math.max(1.0, g2.abs());
    final closing = (l2 - r2).abs() <= 0.75 * (l1 - r1).abs() + 1e-9 * scale;
    final settled = (g2 - g1).abs() <= 1e-3 * scale;

    if (closing && settled) {
      return (4 * g2 - g1) / 3; // Richardson extrapolation removes the O(h^2) error
    }

    // Not settling: both sides may run off to the same infinity (like 1/x^2 at 0)
    final sb = sides(1e-7);
    final lb = sb[0], rb = sb[1];
    if (lb.isFinite && rb.isFinite && lb.abs() > 1e5 && rb.abs() > 1e5 && jsSign(lb) == jsSign(rb)) {
      throw CalcError(lb > 0 ? 'Limit is +∞ (grows without bound)' : 'Limit is −∞ (falls without bound)');
    }
    throw const CalcError('Limit does not exist (left and right values differ)');
  }

  // Finite series summation sum(f(x), a, b)
  static double numericalSummation(String funcExpr, double a, double b, [AngleMode angleMode = AngleMode.rad]) {
    final start = jsRound(a);
    final end = jsRound(b);
    if (start > end) return 0;
    if (end - start > 100000) throw const CalcError('Summation range exceeds safety limit of 100,000 steps');

    double sum = 0;
    for (double k = start; k <= end; k++) {
      final val = evaluateFunction(funcExpr, k, angleMode);
      if (val.isNaN) throw CalcError('Summation evaluation failed at x = ${jsToString(k)}');
      sum += val;
    }
    return sum;
  }

  // Finite series product prod(f(x), a, b)
  static double numericalProduct(String funcExpr, double a, double b, [AngleMode angleMode = AngleMode.rad]) {
    final start = jsRound(a);
    final end = jsRound(b);
    if (start > end) return 1;
    if (end - start > 50000) throw const CalcError('Product range exceeds safety limit of 50,000 steps');

    double prod = 1;
    for (double k = start; k <= end; k++) {
      final val = evaluateFunction(funcExpr, k, angleMode);
      if (val.isNaN) throw CalcError('Product evaluation failed at x = ${jsToString(k)}');
      prod *= val;
    }
    return prod;
  }

  // -------------------------------------------------------------------------------------------
  // multi-argument function pre-pass
  // -------------------------------------------------------------------------------------------

  static final RegExp _reNcr = RegExp(r'([0-9.a-zA-Zπe)]+)\s*nCr\s*([0-9.a-zA-Zπe(]+)', caseSensitive: false);
  static final RegExp _reNpr = RegExp(r'([0-9.a-zA-Zπe)]+)\s*nPr\s*([0-9.a-zA-Zπe(]+)', caseSensitive: false);
  static final RegExp _reMod = RegExp(r'([0-9.a-zA-Zπe)]+)\s*mod\s*([0-9.a-zA-Zπe(]+)', caseSensitive: false);
  static final RegExp _reRand = RegExp(r'rand\(\)', caseSensitive: false);

  static const List<String> _funcNames = <String>[
    'diff',
    'integrate',
    'int',
    'sum',
    'prod',
    'nCr',
    'nPr',
    'gcd',
    'lcm',
    'mod',
    'root',
    'logb',
    'randInt',
    'y',
    'limit',
    'min',
    'max',
    'mean',
    'avg',
  ];

  static final List<RegExp> _funcRegexes =
      _funcNames.map((name) => RegExp('\\b$name\\s*\\(', caseSensitive: false)).toList();

  static final math.Random _random = math.Random();

  // Pre-process multi-argument calculus and discrete functions
  static String _preprocessMultiArgFunctions(String expr, AngleMode angleMode) {
    var current = expr;

    // Convert infix "10 nCr 3" -> "nCr(10, 3)", "5 nPr 2" -> "nPr(5, 2)", "17 mod 5" -> "mod(17, 5)"
    current = current
        .replaceAllMapped(_reNcr, (m) => 'nCr(${m[1]}, ${m[2]})')
        .replaceAllMapped(_reNpr, (m) => 'nPr(${m[1]}, ${m[2]})')
        .replaceAllMapped(_reMod, (m) => 'mod(${m[1]}, ${m[2]})')
        .replaceAllMapped(_reRand, (m) => jsToString(_random.nextDouble()));

    var safety = 0;
    while (safety++ < 30) {
      // Find the first multi-arg function
      var foundIndex = -1;
      var matchedFunc = '';

      for (var n = 0; n < _funcNames.length; n++) {
        final match = _funcRegexes[n].firstMatch(current);
        if (match != null && (foundIndex == -1 || match.start < foundIndex)) {
          foundIndex = match.start;
          matchedFunc = _funcNames[n].toLowerCase();
        }
      }

      if (foundIndex == -1) break;

      // Find matching closing parenthesis
      final openParenIdx = current.indexOf('(', foundIndex);
      var depth = 0;
      var closeParenIdx = -1;

      for (var i = openParenIdx; i < current.length; i++) {
        if (current[i] == '(') {
          depth++;
        } else if (current[i] == ')') {
          depth--;
          if (depth == 0) {
            closeParenIdx = i;
            break;
          }
        }
      }

      if (closeParenIdx == -1) break; // Incomplete expression, continue

      final argsStr = current.substring(openParenIdx + 1, closeParenIdx);

      // Split arguments by top-level commas
      final args = <String>[];
      var currentArg = StringBuffer();
      var parenDepth = 0;

      for (var i = 0; i < argsStr.length; i++) {
        final char = argsStr[i];
        if (char == '(') {
          parenDepth++;
        } else if (char == ')') {
          parenDepth--;
        }

        if (char == ',' && parenDepth == 0) {
          args.add(currentArg.toString().trim());
          currentArg = StringBuffer();
        } else {
          currentArg.write(char);
        }
      }
      if (currentArg.toString().trim().isNotEmpty) args.add(currentArg.toString().trim());

      double result = 0;
      final fName = matchedFunc;

      if (fName == 'diff') {
        if (args.length < 2) throw const CalcError('diff requires: diff(function, x_value)');
        final fExpr = args[0];
        final xVal = evaluate(args[1], angleMode);
        result = numericalDerivative(fExpr, xVal, angleMode);
      } else if (fName == 'integrate' || fName == 'int') {
        if (args.length < 3) {
          throw const CalcError('integrate requires: integrate(function, lower_limit, upper_limit)');
        }
        final fExpr = args[0];
        final aVal = evaluate(args[1], angleMode);
        final bVal = evaluate(args[2], angleMode);
        result = numericalIntegration(fExpr, aVal, bVal, angleMode);
      } else if (fName == 'sum') {
        if (args.length < 3) throw const CalcError('sum requires: sum(function, start, end)');
        final fExpr = args[0];
        final aVal = evaluate(args[1], angleMode);
        final bVal = evaluate(args[2], angleMode);
        result = numericalSummation(fExpr, aVal, bVal, angleMode);
      } else if (fName == 'prod') {
        if (args.length < 3) throw const CalcError('prod requires: prod(function, start, end)');
        final fExpr = args[0];
        final aVal = evaluate(args[1], angleMode);
        final bVal = evaluate(args[2], angleMode);
        result = numericalProduct(fExpr, aVal, bVal, angleMode);
      } else if (fName == 'ncr') {
        if (args.length < 2) throw const CalcError('nCr requires: nCr(n, r)');
        final n = evaluate(args[0], angleMode);
        final r = evaluate(args[1], angleMode);
        result = combinations(n, r);
      } else if (fName == 'npr') {
        if (args.length < 2) throw const CalcError('nPr requires: nPr(n, r)');
        final n = evaluate(args[0], angleMode);
        final r = evaluate(args[1], angleMode);
        result = permutations(n, r);
      } else if (fName == 'gcd') {
        if (args.length < 2) throw const CalcError('gcd requires: gcd(a, b)');
        final a = evaluate(args[0], angleMode);
        final b = evaluate(args[1], angleMode);
        result = gcd(a, b);
      } else if (fName == 'lcm') {
        if (args.length < 2) throw const CalcError('lcm requires: lcm(a, b)');
        final a = evaluate(args[0], angleMode);
        final b = evaluate(args[1], angleMode);
        result = lcm(a, b);
      } else if (fName == 'mod') {
        if (args.length < 2) throw const CalcError('mod requires: mod(a, b)');
        final a = evaluate(args[0], angleMode);
        final b = evaluate(args[1], angleMode);
        result = jsMod(jsMod(a, b) + b, b);
      } else if (fName == 'root') {
        if (args.length < 2) throw const CalcError('root requires: root(degree, x)');
        final deg = evaluate(args[0], angleMode);
        final val = evaluate(args[1], angleMode);
        if (deg == 0) throw const CalcError('0th root is undefined');
        result = jsPow(val, 1 / deg);
      } else if (fName == 'logb') {
        if (args.length < 2) throw const CalcError('logb requires: logb(base, x)');
        final base = evaluate(args[0], angleMode);
        final val = evaluate(args[1], angleMode);
        result = _log(val) / _log(base);
      } else if (fName == 'y') {
        if (_yDefinition == null || _yDefinition!.isEmpty) {
          throw const CalcError('No equation saved yet. Write one first, like y=x^2−5x+6, then press =');
        }
        if (args.isEmpty) throw const CalcError('y needs an x value: y(4)');
        final xVal = evaluate(args[0], angleMode);
        result = evaluateFunction(_yDefinition!, xVal, angleMode);
        if (result.isNaN) throw CalcError('y is not defined at x = ${jsToString(xVal)}');
      } else if (fName == 'limit') {
        if (args.length < 3) throw const CalcError('limit requires: limit(function, x, approach_value)');
        // args[1] is the variable name (kept so the call reads naturally); args[2] is the point x approaches
        final aVal = evaluate(args[2], angleMode);
        result = numericalLimit(args[0], aVal, angleMode);
      } else if (fName == 'min' || fName == 'max' || fName == 'mean' || fName == 'avg') {
        if (args.isEmpty) throw CalcError('$fName needs at least one value');
        final vals = args.map((a) => evaluate(a, angleMode)).toList();
        if (fName == 'min') {
          result = jsMin(vals);
        } else if (fName == 'max') {
          result = jsMax(vals);
        } else {
          result = vals.fold<double>(0, (sum, v) => sum + v) / vals.length;
        }
      } else if (fName == 'randint') {
        if (args.length < 2) throw const CalcError('randInt requires: randInt(min, max)');
        final min = jsRound(evaluate(args[0], angleMode));
        final max = jsRound(evaluate(args[1], angleMode));
        result = (_random.nextDouble() * (max - min + 1)).floorToDouble() + min;
      }

      final formattedVal = result.abs() < 1e-12 ? '0' : jsToString(result);
      current = current.substring(0, foundIndex) + formattedVal + current.substring(closeParenIdx + 1);
    }

    return current;
  }

  static double _log(double x) => x.isNaN ? x : (x < 0 ? double.nan : (x == 0 ? double.negativeInfinity : math.log(x)));

  // -------------------------------------------------------------------------------------------
  // Shunting-yard to RPN
  // -------------------------------------------------------------------------------------------

  static const Map<String, int> _precedence = <String, int>{
    '+': 1,
    '-': 1,
    '*': 2,
    '/': 2,
    '%': 2,
    '^': 4,
    'u-': 5, // unary minus
    '!': 6,
  };

  static bool _isRightAssociative(String op) => op == '^' || op == 'u-';

  static List<Object> _toRPN(List<String> tokens, AngleMode angleMode) {
    final output = <Object>[];
    final opStack = <String>[];

    String? prevToken;

    for (var i = 0; i < tokens.length; i++) {
      var token = tokens[i];

      // Handle constants
      if (token == 'PI') {
        output.add(math.pi);
        prevToken = token;
        continue;
      }
      if (token == 'E') {
        output.add(math.e);
        prevToken = token;
        continue;
      }
      if (token == 'PHI') {
        output.add(1.618033988749895);
        prevToken = token;
        continue;
      }

      // Handle numbers (including scientific notation like 6.626e-34)
      if (_reNumberToken.hasMatch(token)) {
        final value = jsParseFloat(token);
        if (value.isNaN) throw CalcError('Invalid number: $token');
        output.add(value);
        prevToken = token;
        continue;
      }

      // Handle unary minus
      if (token == '-' && (prevToken == null || prevToken == '(' || '+-*/^%'.contains(prevToken))) {
        token = 'u-';
      }

      // Handle functions
      if (_isFunc(token)) {
        opStack.add(token.toLowerCase());
        prevToken = token;
        continue;
      }

      // Handle factorial postfix
      if (token == '!') {
        output.add('!');
        prevToken = token;
        continue;
      }

      // Handle operators
      if (_precedence.containsKey(token)) {
        while (opStack.isNotEmpty &&
            opStack.last != '(' &&
            (_isFunc(opStack.last) ||
                _precedence[opStack.last]! > _precedence[token]! ||
                (_precedence[opStack.last]! == _precedence[token]! && !_isRightAssociative(token)))) {
          output.add(opStack.removeLast());
        }
        opStack.add(token);
        prevToken = token;
        continue;
      }

      if (token == '(') {
        opStack.add('(');
        prevToken = token;
        continue;
      }

      if (token == ')') {
        while (opStack.isNotEmpty && opStack.last != '(') {
          output.add(opStack.removeLast());
        }
        if (opStack.isEmpty) {
          throw const CalcError('Mismatched parentheses');
        }
        opStack.removeLast(); // remove '('

        if (opStack.isNotEmpty && _isFunc(opStack.last)) {
          output.add(opStack.removeLast());
        }
        prevToken = token;
        continue;
      }

      throw CalcError('Unexpected token: $token');
    }

    while (opStack.isNotEmpty) {
      final top = opStack.removeLast();
      if (top == '(' || top == ')') {
        throw const CalcError('Mismatched parentheses');
      }
      output.add(top);
    }

    return output;
  }

  // -------------------------------------------------------------------------------------------
  // RPN evaluation
  // -------------------------------------------------------------------------------------------

  static double _evaluateRPN(List<Object> rpn, AngleMode angleMode) {
    final stack = <double>[];

    double toRad(double val) => angleMode == AngleMode.deg ? (val * math.pi) / 180 : val;
    double toAngle(double radVal) => angleMode == AngleMode.deg ? (radVal * 180) / math.pi : radVal;

    for (final token in rpn) {
      if (token is double) {
        stack.add(token);
      } else if (token == 'u-') {
        if (stack.isEmpty) throw const CalcError('Invalid syntax');
        final a = stack.removeLast();
        stack.add(-a);
      } else if (token == '!') {
        if (stack.isEmpty) throw const CalcError('Invalid syntax');
        final a = stack.removeLast();
        stack.add(factorial(a));
      } else if (const <String>['+', '-', '*', '/', '^', '%'].contains(token)) {
        if (stack.length < 2) throw const CalcError('Invalid syntax');
        final b = stack.removeLast();
        final a = stack.removeLast();
        double res = 0;
        switch (token as String) {
          case '+':
            res = a + b;
          case '-':
            res = a - b;
          case '*':
            res = a * b;
          case '/':
            if (b == 0) throw const CalcError('Division by zero');
            res = a / b;
          case '^':
            res = jsPow(a, b);
          case '%':
            res = jsMod(a, b);
        }
        stack.add(res);
      } else {
        // Unary functions
        if (stack.isEmpty) throw const CalcError('Invalid function call');
        final a = stack.removeLast();
        double res = 0;
        switch (token as String) {
          case 'sin':
            res = math.sin(toRad(a));
            if (res.abs() < 1e-14) res = 0;
          case 'cos':
            res = math.cos(toRad(a));
            if (res.abs() < 1e-14) res = 0;
          case 'tan':
            {
            final rad = toRad(a);
            final cosVal = math.cos(rad);
            if (cosVal.abs() < 1e-14) throw const CalcError('Undefined (tan 90°)');
            res = math.tan(rad);
            if (res.abs() < 1e-14) res = 0;
            }
          case 'sec':
            {
            final cosVal = math.cos(toRad(a));
            if (cosVal.abs() < 1e-14) throw const CalcError('Undefined (sec 90°)');
            res = 1 / cosVal;
            }
          case 'csc':
            {
            final sinVal = math.sin(toRad(a));
            if (sinVal.abs() < 1e-14) throw const CalcError('Undefined (csc 0°)');
            res = 1 / sinVal;
            }
          case 'cot':
            {
            final tanVal = math.tan(toRad(a));
            if (tanVal.abs() < 1e-14) throw const CalcError('Undefined (cot 0°)');
            res = 1 / tanVal;
            }
          case 'asin':
            if (a < -1 || a > 1) throw const CalcError('Domain error (asin)');
            res = toAngle(math.asin(a));
          case 'acos':
            if (a < -1 || a > 1) throw const CalcError('Domain error (acos)');
            res = toAngle(math.acos(a));
          case 'atan':
            res = toAngle(math.atan(a));
          case 'sinh':
            res = jsSinh(a);
          case 'cosh':
            res = jsCosh(a);
          case 'tanh':
            res = jsTanh(a);
          case 'asinh':
            res = jsAsinh(a);
          case 'acosh':
            if (a < 1) throw const CalcError('Domain error: acosh(x) requires x >= 1');
            res = jsAcosh(a);
          case 'atanh':
            if (a.abs() >= 1) throw const CalcError('Domain error: atanh(x) requires -1 < x < 1');
            res = jsAtanh(a);
          case 'sech':
            res = 1 / jsCosh(a);
          case 'csch':
            if (a == 0) throw const CalcError('Division by zero in csch(0)');
            res = 1 / jsSinh(a);
          case 'coth':
            if (a == 0) throw const CalcError('Division by zero in coth(0)');
            res = 1 / jsTanh(a);
          case 'ln':
            if (a <= 0) throw const CalcError('Domain error (ln <= 0)');
            res = math.log(a);
          case 'log':
            if (a <= 0) throw const CalcError('Domain error (log <= 0)');
            res = jsLog10(a);
          case 'log2':
            if (a <= 0) throw const CalcError('Domain error (log2 <= 0)');
            res = jsLog2(a);
          case 'exp':
            res = math.exp(a);
          case 'sqrt':
            if (a < 0) throw const CalcError('Domain error (sqrt negative)');
            res = math.sqrt(a);
          case 'cbrt':
            res = jsCbrt(a);
          case 'abs':
            res = a.abs();
          case 'round':
            res = jsRound(a);
          case 'floor':
            res = a.floorToDouble();
          case 'ceil':
            res = a.ceilToDouble();
          case 'sign':
            res = jsSign(a);
          default:
            throw CalcError('Unknown function: $token');
        }
        stack.add(res);
      }
    }

    if (stack.length != 1) {
      throw const CalcError('Evaluation error');
    }

    return stack[0];
  }

  // -------------------------------------------------------------------------------------------
  // public API
  // -------------------------------------------------------------------------------------------

  /// Public evaluation method with multi-argument calculus preprocessor.
  static double evaluate(String expr, [AngleMode angleMode = AngleMode.deg]) {
    // Phase 6 (Part 3.2): molar("H2O"), amass("Fe"), atomic("Fe") become numbers first, before percent, sanitize and
    // the infix nCr / mod regexes, so a formula in the quotes is never rewritten. Not in the TS oracle.
    final clean = _applyPercent(ChemCalcFunctions.resolve(expr).trim());
    if (clean.isEmpty) return 0;

    // 1. Process multi-argument calculus and discrete functions (diff, integrate, sum, prod, nCr, nPr, gcd, lcm, mod, root)
    final preprocessed = _preprocessMultiArgFunctions(clean, angleMode);

    // 2. Tokenize and evaluate standard expression
    final tokens = _tokenize(preprocessed);
    if (tokens.isEmpty) return 0;
    final rpn = _toRPN(tokens, angleMode);
    return _evaluateRPN(rpn, angleMode);
  }

  /// Format numerical result cleanly avoiding floating point glitches (like 0.1 + 0.2).
  static String formatResult(double val, [int precision = -1]) {
    if (!val.isFinite) {
      if (val.isNaN) return 'Error';
      return val > 0 ? 'Infinity' : '-Infinity';
    }

    // Fix precision if specific precision requested
    if (precision > 0) {
      return jsToString(jsParseFloat(jsToFixed(val, precision)));
    }

    // Auto cleanup floating point drift
    final rounded = jsParseFloat(jsToPrecision(val, 12));
    if (rounded.abs() < 1e-12 && rounded.abs() > 0) {
      return jsToExponential(rounded, 4);
    }
    if (rounded.abs() >= 1e14) {
      return jsToExponential(rounded, 6);
    }
    return jsToString(rounded);
  }

  static final RegExp _reXVariable = RegExp(r'(^|[^a-zA-Z_])x(?![a-zA-Z0-9_])', caseSensitive: false);

  /// Evaluate for graphing f(x) or calculus kernels.
  static double evaluateFunction(String expr, double xVal, [AngleMode angleMode = AngleMode.rad]) {
    try {
      // Replace independent variable x safely without breaking function names e.g. "exp", "floor"
      final formattedX = '(${jsToString(xVal)})';
      // (lookahead, so "x*x" and "2x" both work; a digit before x means implicit multiplication)
      final replaced = expr.replaceAllMapped(_reXVariable, (m) => '${m[1]}$formattedX');
      return evaluate(replaced, angleMode);
    } catch (_) {
      return double.nan;
    }
  }
}
