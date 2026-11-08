// INEQ mode of the Casio engine (Phase 7e, manual p.82-84): quadratic and cubic inequalities with the four relations
// `<`, `>`, `≤`, `≥`. The real roots (exact where EQN gives them exact) cut the number line into pieces; each piece and each
// root is kept or dropped, and neighbouring kept pieces are joined into one interval.
//
// Special results (manual p.84): `All Real Numbers` and `No-Solution`.

import 'cval.dart';
import 'eqn.dart';

enum IneqType {
  quadratic('aX²+bX+c', 3),
  cubic('aX³+bX²+cX+d', 4);

  const IneqType(this.title, this.cols);

  final String title;

  /// Cells of the Coefficient Editor (one row).
  final int cols;
}

enum IneqRel {
  lt('<', true),
  gt('>', true),
  le('≤', false),
  ge('≥', false);

  const IneqRel(this.symbol, this.strict);

  final String symbol;
  final bool strict;

  /// The sign the polynomial must have inside a piece.
  bool get wantsNegative => this == IneqRel.lt || this == IneqRel.le;
}

/// One interval of the solution. A null bound is infinity; [lo] == [hi] with both closed is a single point.
class IneqPart {
  const IneqPart({this.lo, this.loClosed = false, this.hi, this.hiClosed = false});

  final CVal? lo;
  final bool loClosed;
  final CVal? hi;
  final bool hiClosed;

  bool get isPoint => lo != null && hi != null && loClosed && hiClosed && lo!.v == hi!.v;

  /// The text of the part with [fmt] showing the bounds: `−3<X<1`, `X≤−3`, `1≤X`, `X=0`.
  String text(String Function(CVal) fmt) {
    if (isPoint) return 'X=${fmt(lo!)}';
    final l = loClosed ? '≤' : '<';
    final h = hiClosed ? '≤' : '<';
    if (lo == null && hi == null) return 'All Real Numbers';
    if (lo == null) return 'X$h${fmt(hi!)}';
    if (hi == null) return '${fmt(lo!)}${l}X';
    return '${fmt(lo!)}${l}X$h${fmt(hi!)}';
  }
}

/// One named endpoint of the solution (`A=`, `B=`, `C=` in the manual's Linear Display, p.82-84).
class IneqEndpoint {
  const IneqEndpoint(this.name, this.value);

  final String name;
  final CVal value;
}

/// The header line of the solution screen (`A<X<B`, `X≤A,B≤X`, `X=A,B≤X`, `A<X<B,C<X`) and the endpoints it names, left to
/// right on the number line (manual p.82-84). MathO shows the header above the solution, Linear Display shows it above one
/// `name = value` line per endpoint.
class IneqLayout {
  const IneqLayout(this.header, this.endpoints);

  final String header;
  final List<IneqEndpoint> endpoints;
}

class IneqResult {
  const IneqResult(this.parts, {this.allReal = false});

  /// Empty when there is no solution.
  final List<IneqPart> parts;
  final bool allReal;

  bool get none => !allReal && parts.isEmpty;

  /// The lines of the solution screen.
  List<String> lines(String Function(CVal) fmt) {
    if (allReal) return const <String>['All Real Numbers'];
    if (parts.isEmpty) return const <String>['No-Solution'];
    return <String>[for (final p in parts) p.text(fmt)];
  }

  /// The header and the named endpoints, or null for the special results (`All Real Numbers`, `No-Solution`), which look the
  /// same in both displays. Endpoints are named A, B, C in order along the number line; a root that is left out of the
  /// solution but touches two parts (`(x−1)²>0`) keeps one name: `X<A,A<X` (unverified on a real device).
  IneqLayout? layout() {
    if (allReal || parts.isEmpty) return null;
    final endpoints = <IneqEndpoint>[];
    String nameOf(CVal v) {
      for (final e in endpoints) {
        if (e.value.v == v.v) return e.name;
      }
      final name = String.fromCharCode(0x41 + endpoints.length);
      endpoints.add(IneqEndpoint(name, v));
      return name;
    }

    // parts come in increasing order and each part is read left to right, so names are handed out A, B, C…
    final header = <String>[for (final p in parts) p.text(nameOf)].join(',');
    return IneqLayout(header, endpoints);
  }
}

class CasioIneq {
  const CasioIneq._();

  /// Solves `poly REL 0` for the coefficients [coef] (highest power first). a = 0 is a Math ERROR, as in EQN.
  static IneqResult solve(IneqType type, IneqRel rel, List<CVal> coef) {
    if (coef.length != type.cols) throw kArgumentError;
    if (coef[0].v == 0) throw kMathError;
    final roots = _realRoots(type, coef);
    double p(double x) {
      var r = 0.0;
      for (final c in coef) {
        r = r * x + c.v;
      }
      return r;
    }

    // test points: left of the first root, between neighbours, right of the last root
    final samples = <double>[];
    if (roots.isEmpty) {
      samples.add(0);
    } else {
      samples.add(roots.first.v - 1 - roots.first.v.abs());
      for (var i = 0; i + 1 < roots.length; i++) {
        samples.add((roots[i].v + roots[i + 1].v) / 2);
      }
      samples.add(roots.last.v + 1 + roots.last.v.abs());
    }
    bool keep(double x) => rel.wantsNegative ? p(x) < 0 : p(x) > 0;

    // elements of the number line in order: piece 0, root 0, piece 1, root 1, …, piece n
    final n = roots.length;
    final included = <bool>[];
    for (var i = 0; i <= n; i++) {
      included.add(keep(samples[i]));
      if (i < n) included.add(!rel.strict); // a root makes the polynomial 0
    }
    if (included.every((e) => e)) return const IneqResult(<IneqPart>[], allReal: true);
    if (included.every((e) => !e)) return const IneqResult(<IneqPart>[]);

    final parts = <IneqPart>[];
    var i = 0;
    while (i < included.length) {
      if (!included[i]) {
        i++;
        continue;
      }
      var j = i;
      while (j + 1 < included.length && included[j + 1]) {
        j++;
      }
      parts.add(_run(roots, i, j));
      i = j + 1;
    }
    return IneqResult(parts);
  }

  /// The run of kept elements i..j (even index = piece k = i/2, odd index = root (i-1)/2).
  static IneqPart _run(List<CVal> roots, int i, int j) {
    CVal? lo;
    var loClosed = false;
    if (i.isEven) {
      // a piece: starts at root i/2 - 1 (open) or at -infinity
      final k = i ~/ 2;
      lo = k == 0 ? null : roots[k - 1];
    } else {
      lo = roots[(i - 1) ~/ 2];
      loClosed = true;
    }
    CVal? hi;
    var hiClosed = false;
    if (j.isEven) {
      final k = j ~/ 2;
      hi = k == roots.length ? null : roots[k];
    } else {
      hi = roots[(j - 1) ~/ 2];
      hiClosed = true;
    }
    return IneqPart(lo: lo, loClosed: loClosed, hi: hi, hiClosed: hiClosed);
  }

  /// The distinct real roots in increasing order.
  static List<CVal> _realRoots(IneqType type, List<CVal> coef) {
    final lines = CasioEqn.solve(type == IneqType.quadratic ? EqnType.quadratic : EqnType.cubic, coef);
    final out = <CVal>[];
    for (final l in lines) {
      if (!RegExp(r'^X\d?=$').hasMatch(l.label)) continue; // skip the X-Value / Y-Value lines of a quadratic
      if (!l.value.isReal) continue;
      out.add(l.value.re);
    }
    out.sort((a, b) => a.v.compareTo(b.v));
    final distinct = <CVal>[];
    for (final r in out) {
      if (distinct.isNotEmpty && _same(distinct.last.v, r.v)) continue;
      distinct.add(r);
    }
    return distinct;
  }

  static bool _same(double a, double b) => (a - b).abs() <= 1e-9 * (a.abs() > b.abs() ? a.abs() : b.abs()) || (a - b).abs() < 1e-12;
}
