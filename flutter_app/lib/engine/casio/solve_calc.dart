// SOLVE (Newton's method, manual p.49-51) and CALC (manual p.47-49) of the Casio engine, Phase 7c.
//
// Both are sessions: the line is parsed once, the variables the unit prompts for are listed in order of appearance, the
// caller supplies a value for each, and the session runs. No Flutter here: the UI (a prompt sheet) drives these classes.

import 'dart:math' as math;

import 'config.dart';
import 'cval.dart';
import 'engine.dart';
import 'evaluator.dart';
import 'format.dart';
import 'parser.dart';

/// Variables (A B C D E F M X Y) in the order they first appear in [n].
List<String> casioVariablesIn(Node n) {
  final seen = <String>[];
  void walk(Node m) {
    switch (m) {
      case NName(:final name):
        if (kVariableNames.contains(name) && !seen.contains(name)) seen.add(name);
      case NNum() || NVal():
        break;
      case NNeg():
        walk(m.a);
      case NBin():
        walk(m.a);
        walk(m.b);
      case NPow():
        walk(m.a);
        walk(m.b);
      case NPost():
        walk(m.a);
      case NCall():
        for (final a in m.args) {
          walk(a);
        }
      case NSto():
        walk(m.a);
      case NSeq():
        for (final s in m.stmts) {
          walk(s);
        }
      case NDms():
        walk(m.d);
        if (m.m != null) walk(m.m!);
        if (m.s != null) walk(m.s!);
    }
  }

  walk(n);
  return seen;
}

bool _hasForbidden(Node root) {
  var found = false;
  void walk(Node m) {
    if (found) return;
    switch (m) {
      case NName() || NNum() || NVal():
        break;
      case NNeg():
        walk(m.a);
      case NBin():
        if (m.op == '÷R') found = true;
        walk(m.a);
        walk(m.b);
      case NPow():
        walk(m.a);
        walk(m.b);
      case NPost():
        walk(m.a);
      case NCall():
        if (kCalculusNames.contains(m.name) || m.name == 'pol' || m.name == 'rec') found = true;
        for (final a in m.args) {
          walk(a);
        }
      case NSto():
        walk(m.a);
      case NSeq():
        for (final s in m.stmts) {
          walk(s);
        }
      case NDms():
        walk(m.d);
        if (m.m != null) walk(m.m!);
        if (m.s != null) walk(m.s!);
    }
  }

  walk(root);
  return found;
}

/// Index of the character [ch] at parenthesis depth 0, or -1.
int _topLevel(String s, String ch, {bool last = false}) {
  var depth = 0;
  var at = -1;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == '(') {
      depth++;
    } else if (c == ')') {
      depth--;
    } else if (c == ch && depth == 0) {
      if (!last) return i;
      at = i;
    }
  }
  return at;
}

// ---------------------------------------------------------------------------------------------------------------------
// SOLVE
// ---------------------------------------------------------------------------------------------------------------------

sealed class SolveOutcome {
  const SolveOutcome();
}

/// A solution was found: [value] is the solution, [lMinusR] is (left side) − (right side) with that value (p.51).
final class SolveDone extends SolveOutcome {
  const SolveDone(this.value, this.lMinusR);
  final CVal value;
  final CVal lMinusR;
}

/// The preset number of iterations ran out: the unit shows `Continue: [=]` (`=` calls [CasioSolver.next], AC cancels).
final class SolveContinue extends SolveOutcome {
  const SolveContinue();
}

class CasioSolver {
  CasioSolver._(this._engine, this.equation, this.variable, this._lhs, this._rhs, this.prompts);

  /// Parses [text]: an expression (taken as `expr = 0`), `lhs=rhs`, or either followed by `,variable` (manual p.49).
  /// Throws `Variable ERROR` when there is no solution variable to solve for, `Syntax ERROR` for a form the unit refuses
  /// (∫, d/dx, Σ, ∏, Pol, Rec, ÷R are not allowed in an equation).
  factory CasioSolver(CasioEngine engine, String text) {
    var body = text.trim();
    String? explicit;
    final comma = _topLevel(body, ',', last: true);
    if (comma >= 0) {
      final tail = body.substring(comma + 1).trim();
      if (!kVariableNames.contains(tail)) throw kSyntaxError;
      explicit = tail;
      body = body.substring(0, comma).trim();
    }
    if (body.isEmpty) throw kSyntaxError;
    final eq = _topLevel(body, '=');
    if (eq >= 0 && _topLevel(body.substring(eq + 1), '=') >= 0) throw kSyntaxError;
    final lhsText = eq >= 0 ? body.substring(0, eq) : body;
    final rhsText = eq >= 0 ? body.substring(eq + 1) : '0';
    if (lhsText.trim().isEmpty || rhsText.trim().isEmpty) throw kSyntaxError;
    final lhs = CasioParser.parse(lhsText);
    final rhs = CasioParser.parse(rhsText);
    if (_hasForbidden(lhs) || _hasForbidden(rhs)) throw kSyntaxError;
    final vars = <String>[...casioVariablesIn(lhs)];
    for (final v in casioVariablesIn(rhs)) {
      if (!vars.contains(v)) vars.add(v);
    }
    final solveFor = explicit ?? 'X';
    if (!vars.contains(solveFor)) throw const CasioError(CasioErrorKind.variable);
    final prompts = <String>[for (final v in vars) if (v != solveFor) v];
    return CasioSolver._(engine, eq >= 0 ? body : '$body=0', solveFor, lhs, rhs, prompts);
  }

  final CasioEngine _engine;

  /// The equation as the solution screen shows it.
  final String equation;

  /// The variable solved for.
  final String variable;

  /// The other variables the unit prompts for, in order of appearance. The solution variable's initial value is asked last.
  final List<String> prompts;

  final Node _lhs;
  final Node _rhs;

  /// Preset number of Newton iterations before `Continue: [=]` appears (the manual does not give the number).
  static const int kIterationsPerRound = 30;

  /// After this many `Continue` rounds the unit gives up: `Can't Solve`.
  static const int kMaxRounds = 8;

  CasioMemory? _work;
  CasioEvaluator? _ev;
  double _x = 0;
  var _rounds = 0;

  /// The value a prompt starts with: the variable's current value (manual p.49).
  CVal current(String v) => _engine.memory.vars[v] ?? CVal.zero;

  double _g(double x) {
    _work!.vars[variable] = CVal.dec(x);
    final l = _ev!.eval(_lhs).v;
    final r = _ev!.eval(_rhs).v;
    return round15(l - r);
  }

  /// Runs SOLVE with the [values] entered at the prompts and the [initial] value of the solution variable.
  SolveOutcome start(Map<String, CVal> values, CVal initial) {
    final work = _engine.memory.copy();
    for (final e in values.entries) {
      work.vars[e.key] = e.value;
    }
    _work = work;
    _ev = CasioEvaluator(_engine.config, work, cancel: _engine.cancel);
    _x = initial.v;
    _rounds = 0;
    _assigned = values;
    return next();
  }

  Map<String, CVal> _assigned = const <String, CVal>{};

  /// One round of up to [kIterationsPerRound] Newton steps; call again after [SolveContinue] when the person presses `=`.
  SolveOutcome next() {
    if (_work == null) throw kSyntaxError;
    _rounds++;
    final cancel = _engine.cancel;
    var x = _x;
    for (var it = 0; it < kIterationsPerRound; it++) {
      cancel?.check();
      double gx;
      try {
        gx = _g(x);
      } on CasioError {
        if (_rounds == 1 && it == 0) rethrow;
        throw const CasioError(CasioErrorKind.cantSolve);
      }
      if (gx == 0) return _finish(x);
      final h = 1e-7 * math.max(1.0, x.abs());
      double d;
      try {
        d = (_g(x + h) - _g(x - h)) / (2 * h);
      } on CasioError {
        throw const CasioError(CasioErrorKind.cantSolve);
      }
      if (d == 0 || !d.isFinite) throw const CasioError(CasioErrorKind.cantSolve);
      final xn = x - gx / d;
      if (!xn.isFinite || xn.abs() >= 1e100) throw const CasioError(CasioErrorKind.cantSolve);
      final converged = (xn - x).abs() <= 1e-13 * math.max(1.0, xn.abs());
      x = xn;
      if (converged) return _finish(x);
    }
    _x = x;
    if (_rounds >= kMaxRounds) throw const CasioError(CasioErrorKind.cantSolve);
    return const SolveContinue();
  }

  SolveOutcome _finish(double x) {
    // the closer (left side) − (right side) is to zero the better the solution: try the neighbours in the 15th digit
    var best = round15(x);
    var bestG = _g(best).abs();
    for (var j = -4; j <= 4; j++) {
      final cand = round15(x + j * 1e-15 * math.max(x.abs(), 1e-300));
      final gv = _g(cand).abs();
      if (gv < bestG) {
        bestG = gv;
        best = cand;
      }
    }
    final result = CVal.dec(best);
    // (left side) − (right side): below the 15-digit resolution of the two sides it is shown as 0, as the video shows
    // `L−R=0` for (X²−6)/(X+3)=10 (unverified on a real device for other equations)
    _work!.vars[variable] = result;
    final l = _ev!.eval(_lhs).v;
    final r = _ev!.eval(_rhs).v;
    final diff = round15(l - r);
    final lr = CVal.dec(diff.abs() <= 1e-13 * math.max(l.abs(), r.abs()) ? 0 : diff);
    // the entered values and the solution stay in the variables, as on the unit
    for (final e in _assigned.entries) {
      _engine.memory.vars[e.key] = e.value;
    }
    _engine.memory.vars[variable] = result;
    return SolveDone(result, lr);
  }

  /// Text of a solution value as the solution screen shows it (always a decimal).
  String show(CVal v) => CasioFormatter(_engine.config).first(CVal.dec(v.v)).display;
}

// ---------------------------------------------------------------------------------------------------------------------
// CALC
// ---------------------------------------------------------------------------------------------------------------------

/// CALC: an expression with variables that is run again for each set of values (manual p.47-49).
class CasioCalc {
  CasioCalc._(this._engine, this.text, this.variables, this.target, this._expr);

  /// Parses [text]: an expression, a multi-statement, or `Var=expression` (the equals sign is ALPHA + CALC).
  factory CasioCalc(CasioEngine engine, String text) {
    final body = text.trim();
    if (body.isEmpty) throw kSyntaxError;
    String? target;
    var expr = body;
    final eq = _topLevel(body, '=');
    if (eq >= 0) {
      final left = body.substring(0, eq).trim();
      if (!kVariableNames.contains(left)) throw kSyntaxError;
      target = left;
      expr = body.substring(eq + 1).trim();
      if (expr.isEmpty || _topLevel(expr, '=') >= 0) throw kSyntaxError;
    }
    final ast = CasioParser.parse(expr);
    final vars = casioVariablesIn(ast);
    return CasioCalc._(engine, body, vars, target, expr);
  }

  final CasioEngine _engine;
  final String text;

  /// The variables the unit prompts for, in order of appearance (the one on the left of `=` is not asked).
  final List<String> variables;

  /// The variable on the left of `Var=expression`; the result is stored in it.
  final String? target;
  final String _expr;

  CVal current(String v) => _engine.memory.vars[v] ?? CVal.zero;

  /// Stores [values] in the variables and calculates. The result is the outcome of the expression; with a [target] it is
  /// also stored there.
  CasioOutcome run(Map<String, CVal> values) {
    for (final e in values.entries) {
      _engine.memory.vars[e.key] = e.value;
    }
    final out = _engine.evaluate(_expr);
    final t = target;
    final v = out.value;
    if (t != null && v != null) _engine.memory.vars[t] = v;
    return out;
  }
}
