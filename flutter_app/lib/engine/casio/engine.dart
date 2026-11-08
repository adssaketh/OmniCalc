// Public face of the Casio engine (Phase 7b): text in, shown result out. Handles Calculation style, percent style, Ans
// continuation, the fall-back to the legacy evaluator for what Phase 7c has not rebuilt yet, FACT and error mapping.

import '../calc_error.dart';
import '../chemistry/calc_functions.dart';
import '../evaluator.dart';
import '../types.dart';
import 'calculus.dart';
import 'config.dart';
import 'recurring_input.dart';
import 'cval.dart';
import 'evaluator.dart';
import 'format.dart';
import 'parser.dart';
import 'phone_percent.dart';
import 'stack_check.dart';

/// What one `=` produced.
class CasioOutcome {
  const CasioOutcome({
    required this.forms,
    this.remainder,
    this.extra = const <String, String>{},
    this.disp = const <String>[],
    this.value,
    this.factorable = false,
    this.legacy = false,
  });

  /// All ways the result can be shown (S⇔D cycles through them); the first is the initial one.
  final List<CasioShown> forms;

  /// `÷R` remainder text, when the result is quotient and remainder.
  final String? remainder;

  /// `Pol` / `Rec` second outputs ("θ", "Y").
  final Map<String, String> extra;

  /// Intermediate results of a multi-statement line.
  final List<String> disp;

  final CVal? value;
  final bool factorable;

  /// Evaluated by the legacy evaluator (the function is not in the Casio engine yet, or the style is OmniCalc).
  final bool legacy;

  CasioShown get shown => forms.first;

  /// Text used as the result in history and as the expression after `=`.
  String get text => shown.display;
}

class CasioEngine {
  CasioEngine({this.config = const CasioConfig(), CasioMemory? memory}) : memory = memory ?? CasioMemory();

  CasioConfig config;
  final CasioMemory memory;

  /// Set by the caller that runs a long calculation (∫, d/dx, Σ, ∏, SOLVE) so that AC can interrupt it.
  CasioCancel? cancel;

  /// Functions Phase 7c rebuilds; until then they are calculated by the legacy evaluator.
  static final RegExp _legacyOnly = RegExp(
    r'\b(integrate|diff|sum|prod|y)\s*\(',
    caseSensitive: false,
  );

  /// The Casio linear syntax of Phase 7c (manual p.39-43): `∫(f(x),a,b,tol)`, `d/dx(f(x),a,tol)`, `Σ(f(x),a,b)`,
  /// `∏(f(x),a,b)`. These work in both calculation styles, with the Casio engine's numerics.
  static final RegExp _casioCalculus = RegExp(r'[∫Σ∑∏]|d/dx');

  static bool hasCasioCalculus(String expr) => _casioCalculus.hasMatch(expr);

  /// OmniCalc functions that are not on the calculator and keep their legacy meaning.
  static final RegExp _legacyWords = RegExp(r'\b(min|max|avg|mean|limit|mod)\b');

  static bool needsLegacy(String expr) =>
      _legacyOnly.hasMatch(expr) || _legacyWords.hasMatch(expr) || _hasCommaIntCall(expr);

  /// `int(f, a, b)` is the legacy integral; `Int(x)` / `int(x)` with one argument is the integer part.
  static bool _hasCommaIntCall(String expr) {
    for (final m in RegExp(r'\bint\s*\(').allMatches(expr)) {
      var depth = 1;
      for (var i = m.end; i < expr.length && depth > 0; i++) {
        final c = expr[i];
        if (c == '(') {
          depth++;
        } else if (c == ')') {
          depth--;
        } else if (c == ',' && depth == 1) {
          return true;
        }
      }
    }
    return false;
  }

  static final RegExp _opStart = RegExp(r'^\s*[+\-−×÷*/]');

  /// Evaluate [input]. [continuesAns] says that the text begins with the previous result (the user pressed an operator right
  /// after `=`): the previous result is then used at full precision as `Ans`, as on the unit.
  CasioOutcome evaluate(String input, {bool continuesAns = false, AngleMode? legacyAngle, bool commit = true}) {
    var expr = CasioRecurringInput.expand(ChemCalcFunctions.resolve(input)).trim();
    if ((!config.useCasio && !hasCasioCalculus(expr)) || needsLegacy(expr)) {
      return _legacy(expr, legacyAngle);
    }
    if (config.phonePercent) expr = PhonePercent.apply(expr);
    final at = memory.ansText;
    if (continuesAns && at != null && at.isNotEmpty && expr.startsWith(at)) {
      final rest = expr.substring(at.length);
      if (_opStart.hasMatch(rest)) expr = 'Ans$rest';
    }
    if (expr.isEmpty) {
      return CasioOutcome(forms: <CasioShown>[const CasioShown('0', '0')], value: CVal.zero);
    }
    final ast = CasioParser.parse(expr);
    if (CasioStackCheck.exceeds(ast)) throw const CasioError(CasioErrorKind.stack);
    // a preview must not touch Ans or the variables (Pol/Rec store X and Y)
    final mem = commit ? memory : memory.copy();
    final ev = CasioEvaluator(config, mem, cancel: cancel);
    final res = ev.run(ast);
    final fmt = CasioFormatter(config);
    final forms = fmt.forms(res.value);
    if (commit) {
      memory.setAns(res.value);
      memory.ansText = forms.first.expr;
    }
    final extra = <String, String>{for (final e in res.extra.entries) e.key: fmt.first(e.value).display};
    return CasioOutcome(
      forms: forms,
      remainder: res.remainder == null ? null : fmt.first(res.remainder!).display,
      extra: extra,
      disp: <String>[for (final d in res.disp) fmt.first(d).display],
      value: res.value,
      factorable: res.factorOf != null,
    );
  }

  CasioOutcome _legacy(String expr, AngleMode? angle) {
    final a = angle ?? (config.angle == CasioAngle.rad ? AngleMode.rad : AngleMode.deg);
    final v = MathEvaluator.evaluate(expr, a);
    final text = MathEvaluator.formatResult(v, config.legacyPrecision);
    return CasioOutcome(
      forms: <CasioShown>[CasioShown(text, text)],
      value: CVal.dec(v),
      legacy: true,
    );
  }

  /// Message for an exception from [evaluate]: the unit's own words, or the legacy message.
  static String messageOf(Object e) {
    if (e is CasioError) return e.message;
    if (e is CalcError) return e.message;
    return 'Math ERROR';
  }

  // ----- FACT ---------------------------------------------------------------------------------------------------------

  static const Map<String, String> _sup = <String, String>{
    '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
  };

  /// Prime factorization of the last result (manual p.30-31). Only a positive integer of at most 10 digits.
  String factorize() {
    final v = memory.ans;
    final ex = v.ex;
    if (ex == null || !ex.isRational || !ex.rational.isInteger || ex.rational.isNegative) throw kMathError;
    final big = ex.rational.n;
    if (big < BigInt.two || big >= BigInt.from(10).pow(10)) throw kMathError;
    var n = big.toInt();
    final parts = <String>[];
    final large = <String>[];
    for (var p = 2; p <= 999 && p * p <= n; p++) {
      if (n % p != 0) continue;
      var k = 0;
      while (n % p == 0) {
        n ~/= p;
        k++;
      }
      parts.add(_power(p, k));
    }
    if (n > 1) {
      // what is left has no factor below 1000: a prime, or a product of primes of 4+ digits
      var m = n;
      var found = false;
      for (var p = 1000; p * p <= m; p++) {
        if (m % p != 0) continue;
        var k = 0;
        while (m % p == 0) {
          m ~/= p;
          k++;
        }
        large.add(_power(p, k));
        found = true;
      }
      if (m > 1) large.add('$m');
      if (!found && large.length == 1 && n < 1000) {
        parts.add('$n');
        large.clear();
      }
    }
    final head = parts.join('×');
    if (large.isEmpty) return head;
    final tail = '(${large.join('×')})';
    return head.isEmpty ? tail : '$head×$tail';
  }

  static String _power(int p, int k) => k == 1 ? '$p' : '$p${'$k'.split('').map((c) => _sup[c]).join()}';
}
