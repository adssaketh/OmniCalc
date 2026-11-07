// CMPLX mode of the Casio engine (Phase 7d, manual p.56-57): complex arithmetic with exact parts, the `∠` polar entry,
// `Abs`, `arg`, `Conjg`, and the `▸r∠θ` / `▸a+bi` commands that override the complex format of SETUP.
//
// The real calculator is reused for everything that has real arguments (every function, every exact √ / π / fraction
// form): the AST is evaluated here, and a node whose children are all real is handed to `CasioEvaluator` with the already
// calculated children substituted as `NVal`s. Only + − × ÷, powers, `i`, `∠`, Abs, arg, Conjg and √ know about the
// imaginary part.

import 'dart:math' as math;

import 'calculus.dart';
import 'config.dart';
import 'cval.dart';
import 'evaluator.dart';
import 'format.dart';
import 'parser.dart';
import 'phone_percent.dart';

/// A complex number whose two parts are ordinary calculator values (15 digits, with their exact forms).
class CComplex {
  CComplex(CVal re, [CVal? im])
      : re = _exactZero(re),
        im = _exactZero(im ?? CVal.int(0));

  static CVal _exactZero(CVal v) => v.v == 0 && v.ex == null ? CVal.int(0) : v;

  final CVal re;
  final CVal im;

  bool get isReal => im.v == 0;
  bool get isZero => re.v == 0 && im.v == 0;

  @override
  String toString() => 'CComplex($re, $im)';
}

/// One way of showing a complex result (S⇔D cycles through them).
class ComplexShown {
  const ComplexShown(this.text, this.lines, this.expr);

  /// What the screen shows in Natural Display, for example `√2+√2i` or `2∠45`.
  final String text;

  /// Linear Display: `a` and `bi` (or `r` and `∠θ`) on separate lines (manual p.56 note).
  final List<String> lines;

  /// Text the engine can read back (used when the result is typed on into the next calculation).
  final String expr;
}

class ComplexOutcome {
  const ComplexOutcome({required this.value, required this.forms, required this.polar});

  final CComplex value;
  final List<ComplexShown> forms;

  /// The result was shown in polar form (SETUP r∠θ or the `▸r∠θ` command).
  final bool polar;

  ComplexShown get shown => forms.first;
  String get text => shown.text;
}

/// Evaluates CMPLX-mode lines. Holds the complex `Ans` and the complex variables (the real ones stay in [memory]).
class CasioComplexEngine {
  CasioComplexEngine(this.memory);

  final CasioMemory memory;

  /// The last result, kept as a complex number (its real part is also in [memory] when it has no imaginary part).
  CComplex? ans;

  /// Variables that hold a complex value; a variable that holds a real one lives in [memory].
  final Map<String, CComplex> vars = <String, CComplex>{};

  static final RegExp _command = RegExp(r'^(.*?)\s*(▸r∠θ|▸a\+bi)\s*$', dotAll: true);

  /// Evaluate [input]. [commit] false (a live preview) leaves Ans and the variables alone.
  ComplexOutcome evaluate(String input, CasioConfig cfg, {bool commit = true, CasioCancel? cancel}) {
    var expr = input.trim();
    bool? polarCommand;
    final m = _command.firstMatch(expr);
    if (m != null) {
      expr = m.group(1)!.trim();
      polarCommand = m.group(2) == '▸r∠θ';
    }
    if (expr.isEmpty) expr = '0';
    if (cfg.phonePercent) expr = PhonePercent.apply(expr);
    final ast = CasioParser.parse(expr, complex: true);
    final mem = commit ? memory : memory.copy();
    final vs = commit ? vars : <String, CComplex>{...vars};
    final ev = CasioEvaluator(cfg, mem, cancel: cancel);
    final run = _Run(ev, mem, vs, ans);
    final z = run.finish(ast);
    final polar = polarCommand ?? (cfg.complexFormat == CasioComplexFormat.polar);
    final outcome = _outcome(z, cfg, ev, polar);
    if (commit) {
      ans = z;
      memory.setAns(z.isReal ? z.re : CVal.zero);
    }
    return outcome;
  }

  /// A real value (a variable, a coefficient) from text in CMPLX syntax; a complex result is a Math ERROR.
  CVal evaluateReal(String input, CasioConfig cfg) {
    final z = evaluate(input, cfg, commit: false);
    if (!z.value.isReal) throw kMathError;
    return z.value.re;
  }

  /// Shows an existing complex value the way a result is shown (used by EQN and the UI).
  ComplexOutcome show(CComplex z, CasioConfig cfg, {bool? polar}) =>
      _outcome(z, cfg, CasioEvaluator(cfg, memory.copy()), polar ?? cfg.complexFormat == CasioComplexFormat.polar);

  // ----- showing ----------------------------------------------------------------------------------------------------

  ComplexOutcome _outcome(CComplex z, CasioConfig cfg, CasioEvaluator ev, bool polar) {
    final fmt = CasioFormatter(cfg);
    final exactForm = _show(z, cfg, ev, polar, (v) => fmt.first(v));
    final decimalForm = _show(z, cfg, ev, polar, (v) {
      final s = fmt.decimalText(v.v);
      return CasioShown(cfg.commaDecimal ? s.$1.replaceAll('.', ',') : s.$1, s.$2);
    });
    final forms = <ComplexShown>[exactForm];
    if (decimalForm.text != exactForm.text) forms.add(decimalForm);
    return ComplexOutcome(value: z, forms: forms, polar: polar);
  }

  ComplexShown _show(CComplex z, CasioConfig cfg, CasioEvaluator ev, bool polar, CasioShown Function(CVal) f) {
    if (z.isZero) return const ComplexShown('0', <String>['0'], '0');
    if (polar) {
      final r = _abs(ev, z);
      final t = _arg(ev, z);
      final rs = f(r);
      final ts = f(t);
      return ComplexShown('${rs.display}∠${ts.display}', <String>[rs.display, '∠${ts.display}'], '${rs.expr}∠${ts.expr}');
    }
    final lines = <String>[];
    var expr = '';
    var text = '';
    if (z.re.v != 0) {
      final s = f(z.re);
      text = s.display;
      expr = s.expr;
      lines.add(s.display);
    }
    if (z.im.v != 0) {
      final neg = z.im.v < 0;
      final mag = neg ? CVal(-z.im.v, z.im.ex == null ? null : -z.im.ex!) : z.im;
      final unit = mag.v == 1;
      var body = unit ? '' : f(mag).display;
      var bodyExpr = unit ? '' : f(mag).expr;
      if (!unit && RegExp(r'[+\-−]').hasMatch(body)) body = '($body)';
      if (!unit && !bodyExpr.startsWith('(') && RegExp(r'[+\-−×÷]').hasMatch(bodyExpr)) bodyExpr = '($bodyExpr)';
      final sign = neg ? '-' : (text.isEmpty ? '' : '+');
      text = '$text$sign${body}i';
      expr = '$expr${neg ? '-' : (expr.isEmpty ? '' : '+')}${bodyExpr}i';
      lines.add('${neg ? '-' : ''}${body}i');
    }
    return ComplexShown(text, lines, expr);
  }

  static CVal _abs(CasioEvaluator ev, CComplex z) {
    if (z.isReal) return z.re.v < 0 ? ev.negV(z.re) : z.re;
    return ev.sqrtV(ev.addV(ev.mulV(z.re, z.re), ev.mulV(z.im, z.im)));
  }

  static CVal _arg(CasioEvaluator ev, CComplex z) {
    final im = z.im.v == 0 ? 0.0 : z.im.v;
    if (z.re.v == 0 && im == 0) return CVal.zero;
    return ev.angleResultV(math.atan2(im, z.re.v));
  }
}

/// One evaluation: the AST walk.
class _Run {
  _Run(this.ev, this.mem, this.vars, this.ans);

  final CasioEvaluator ev;
  final CasioMemory mem;
  final Map<String, CComplex> vars;
  final CComplex? ans;

  static final CComplex _zero = CComplex(CVal.zero);

  CComplex finish(Node root) {
    final z = _run(root);
    return CComplex(z.re, z.im.v == 0 ? CVal.zero : z.im);
  }

  CComplex _run(Node n) {
    if (n is NSeq) {
      var last = _zero;
      for (final s in n.stmts) {
        last = eval(s);
      }
      return last;
    }
    return eval(n);
  }

  CVal _real(CComplex z) {
    if (!z.isReal) throw kMathError;
    return z.re;
  }

  CComplex eval(Node n) {
    switch (n) {
      case NNum():
        return CComplex(ev.eval(n));
      case NVal():
        return CComplex(n.value);
      case NName():
        if (n.name == 'i') return CComplex(CVal.zero, CVal.int(1));
        if (n.name == 'Ans') return ans ?? CComplex(mem.ans);
        final cv = vars[n.name];
        if (cv != null) return cv;
        return CComplex(ev.eval(n));
      case NNeg():
        final a = eval(n.a);
        return CComplex(ev.negV(a.re), ev.negV(a.im));
      case NBin():
        return _bin(n);
      case NPow():
        return _pow(eval(n.a), eval(n.b));
      case NPost():
        return CComplex(ev.eval(NPost(n.op, NVal(_real(eval(n.a)), n.a.pos), n.pos)));
      case NCall():
        return _call(n);
      case NSto():
        final v = eval(n.a);
        if (v.isReal) {
          vars.remove(n.name);
          mem.vars[n.name] = v.re;
        } else {
          vars[n.name] = v;
          mem.vars[n.name] = CVal.zero; // COMP cannot hold a complex value
        }
        return v;
      case NSeq():
        return _run(n);
      case NDms():
        return CComplex(ev.eval(NDms(
          NVal(_real(eval(n.d)), n.d.pos),
          n.m == null ? null : NVal(_real(eval(n.m!)), n.m!.pos),
          n.s == null ? null : NVal(_real(eval(n.s!)), n.s!.pos),
          n.pos,
        )));
    }
  }

  // ----- operators ------------------------------------------------------------------------------------------------

  CComplex _bin(NBin n) {
    switch (n.op) {
      case '+':
        return _add(eval(n.a), eval(n.b));
      case '-':
        return _sub(eval(n.a), eval(n.b));
      case '*':
        if (n.b is NCall && (n.b as NCall).name == 'conv' && n.implicit) {
          return CComplex(ev.eval(NBin(n.op, NVal(_real(eval(n.a)), n.a.pos), n.b, n.pos, implicit: true)));
        }
        return _mul(eval(n.a), eval(n.b));
      case '/':
        return _div(eval(n.a), eval(n.b));
      case '∠':
        return _polarEntry(eval(n.a), eval(n.b));
    }
    return CComplex(ev.eval(NBin(
      n.op,
      NVal(_real(eval(n.a)), n.a.pos),
      NVal(_real(eval(n.b)), n.b.pos),
      n.pos,
      implicit: n.implicit,
    )));
  }

  CComplex _add(CComplex a, CComplex b) => CComplex(ev.addV(a.re, b.re), ev.addV(a.im, b.im));

  CComplex _sub(CComplex a, CComplex b) => CComplex(ev.subV(a.re, b.re), ev.subV(a.im, b.im));

  CComplex _mul(CComplex a, CComplex b) {
    if (a.isReal && b.isReal) return CComplex(ev.mulV(a.re, b.re));
    if (b.isReal) return CComplex(ev.mulV(a.re, b.re), ev.mulV(a.im, b.re));
    if (a.isReal) return CComplex(ev.mulV(a.re, b.re), ev.mulV(a.re, b.im));
    final re = ev.subV(ev.mulV(a.re, b.re), ev.mulV(a.im, b.im));
    final im = ev.addV(ev.mulV(a.re, b.im), ev.mulV(a.im, b.re));
    return CComplex(re, im);
  }

  CComplex _div(CComplex a, CComplex b) {
    if (b.isReal) {
      return CComplex(ev.divV(a.re, b.re), a.isReal ? CVal.zero : ev.divV(a.im, b.re));
    }
    // (a+bi)/(c+di) = ((ac+bd) + (bc-ad)i) / (c²+d²)
    final den = ev.addV(ev.mulV(b.re, b.re), ev.mulV(b.im, b.im));
    final re = ev.divV(ev.addV(ev.mulV(a.re, b.re), ev.mulV(a.im, b.im)), den);
    final im = ev.divV(ev.subV(ev.mulV(a.im, b.re), ev.mulV(a.re, b.im)), den);
    return CComplex(re, im);
  }

  /// `r∠θ` = r(cos θ + i sin θ), θ in the current angle unit (manual p.56). Exact for the angles the unit knows exactly.
  CComplex _polarEntry(CComplex r, CComplex t) {
    final rr = _real(r);
    final tt = _real(t);
    final c = ev.trigV('cos', tt);
    final s = ev.trigV('sin', tt);
    return CComplex(ev.mulV(rr, c), ev.mulV(rr, s));
  }

  CComplex _pow(CComplex a, CComplex b) {
    final e = _real(b);
    final r = e.ex != null && e.ex!.isRational ? e.ex!.rational : null;
    final integer = r != null && r.isInteger;
    if (a.isReal) {
      // the real evaluator keeps the exact forms and its domain rules; only a negative base with a fractional exponent
      // leaves the real numbers here
      if (a.re.v >= 0 || integer) return CComplex(ev.eval(NPow(NVal(a.re, 0), NVal(e, 0), 0)));
      return _principalPow(a, e);
    }
    if (integer && r.n.abs() <= BigInt.from(64)) {
      final k = r.n.toInt();
      var result = CComplex(CVal.int(1));
      for (var i = 0; i < k.abs(); i++) {
        result = _mul(result, a);
      }
      if (k < 0) result = _div(CComplex(CVal.int(1)), result);
      return result;
    }
    return _principalPow(a, e);
  }

  /// z^y by the principal value: |z|^y (cos yθ + i sin yθ), a decimal result.
  CComplex _principalPow(CComplex a, CVal e) {
    final m = math.sqrt(a.re.v * a.re.v + a.im.v * a.im.v);
    if (m == 0) {
      if (e.v > 0) return _zero;
      throw kMathError;
    }
    final theta = math.atan2(a.im.v == 0 ? 0.0 : a.im.v, a.re.v);
    final lr = math.log(m) * e.v;
    if (lr >= 230.2585092) throw kMathError;
    final mag = math.exp(lr);
    final ang = theta * e.v;
    double clean(double v) => v.abs() < 1e-14 * (mag == 0 ? 1 : mag) ? 0 : v;
    return CComplex(ev.decV(clean(mag * math.cos(ang))), ev.decV(clean(mag * math.sin(ang))));
  }

  // ----- functions ------------------------------------------------------------------------------------------------

  CComplex _call(NCall c) {
    switch (c.name) {
      case 'abs':
        return CComplex(CasioComplexEngine._abs(ev, _arg1(c)));
      case 'arg':
        final z = _arg1(c);
        if (z.isZero) throw kMathError;
        return CComplex(CasioComplexEngine._arg(ev, z));
      case 'conjg':
        final z = _arg1(c);
        return CComplex(z.re, z.isReal ? CVal.zero : ev.negV(z.im));
      case 'sqrt':
        return _sqrt(_arg1(c));
    }
    // ∫ d/dx Σ ∏ are COMP-only (manual p.40)
    if (kCalculusNames.contains(c.name)) throw kSyntaxError;
    final args = <Node>[for (final a in c.args) NVal(_real(eval(a)), a.pos)];
    return CComplex(ev.eval(NCall(c.name, args, c.pos)));
  }

  CComplex _arg1(NCall c) {
    if (c.args.length != 1) throw kSyntaxError;
    return eval(c.args[0]);
  }

  CComplex _sqrt(CComplex z) {
    if (z.isReal) {
      if (z.re.v >= 0) return CComplex(ev.sqrtV(z.re));
      return CComplex(CVal.zero, ev.sqrtV(ev.negV(z.re)));
    }
    final r = CasioComplexEngine._abs(ev, z);
    CVal half(CVal x) {
      final v = ev.divV(x, CVal.int(2));
      if (v.v < 0) {
        if (v.v > -1e-12) return CVal.zero;
        throw kMathError;
      }
      return v;
    }

    final re = ev.sqrtV(half(ev.addV(r, z.re)));
    var im = ev.sqrtV(half(ev.subV(r, z.re)));
    if (z.im.v < 0) im = ev.negV(im);
    return CComplex(re, im);
  }
}
