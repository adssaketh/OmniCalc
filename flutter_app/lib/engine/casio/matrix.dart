// MATRIX and VECTOR modes of the Casio engine (Phase 7d-2, manual p.73-82). Matrices are at most 3×3 and live in MatA, MatB,
// MatC; vectors have 2 or 3 elements and live in VctA, VctB, VctC. Elements are calculator values, so exact results stay
// exact (fractions, √ and π forms) through every operation. The line itself is read by the Casio parser with its matrix /
// vector words switched on; scalar parts go to the ordinary evaluator.

import 'config.dart';
import 'cval.dart';
import 'evaluator.dart';
import 'exact.dart';
import 'format.dart';
import 'parser.dart';
import 'phone_percent.dart';

/// A value of MATRIX or VECTOR mode: a number, a matrix or a vector.
sealed class MatVal {
  const MatVal();
}

class MatScalar extends MatVal {
  const MatScalar(this.value);
  final CVal value;
}

class CMatrix extends MatVal {
  CMatrix(this.rows, this.cols, List<CVal> cells)
      : assert(cells.length == rows * cols),
        cells = List<CVal>.unmodifiable(cells);

  factory CMatrix.zero(int rows, int cols) => CMatrix(rows, cols, List<CVal>.filled(rows * cols, CVal.int(0)));

  final int rows;
  final int cols;

  /// Row-major.
  final List<CVal> cells;

  CVal at(int r, int c) => cells[r * cols + c];

  CMatrix withCell(int r, int c, CVal v) {
    final next = List<CVal>.of(cells);
    next[r * cols + c] = v;
    return CMatrix(rows, cols, next);
  }
}

class CVector extends MatVal {
  CVector(List<CVal> cells) : cells = List<CVal>.unmodifiable(cells);

  factory CVector.zero(int dim) => CVector(List<CVal>.filled(dim, CVal.int(0)));

  final List<CVal> cells;

  int get dim => cells.length;

  CVector withCell(int i, CVal v) {
    final next = List<CVal>.of(cells);
    next[i] = v;
    return CVector(next);
  }
}

const CasioError kDimensionError = CasioError(CasioErrorKind.dimension);

const List<String> kMatrixNames = <String>['MatA', 'MatB', 'MatC'];
const List<String> kVectorNames = <String>['VctA', 'VctB', 'VctC'];

/// MatA, MatB, MatC, MatAns and VctA, VctB, VctC, VctAns. A variable whose dimension was never set is null (using one is a
/// Dimension ERROR, manual p.93).
class MatVecStore {
  final Map<String, CMatrix?> mats = <String, CMatrix?>{for (final n in kMatrixNames) n: null};
  final Map<String, CVector?> vecs = <String, CVector?>{for (final n in kVectorNames) n: null};
  CMatrix? matAns;
  CVector? vctAns;

  /// Dim: new dimension, every element zero.
  void dimMatrix(String name, int rows, int cols) {
    if (!mats.containsKey(name) || rows < 1 || rows > 3 || cols < 1 || cols > 3) throw kArgumentError;
    mats[name] = CMatrix.zero(rows, cols);
  }

  void dimVector(String name, int dim) {
    if (!vecs.containsKey(name) || (dim != 2 && dim != 3)) throw kArgumentError;
    vecs[name] = CVector.zero(dim);
  }

  /// STO from MatAns / another matrix: copy to [name].
  void copyMatrix(CMatrix from, String name) {
    if (!mats.containsKey(name)) throw kArgumentError;
    mats[name] = from;
  }

  void copyVector(CVector from, String name) {
    if (!vecs.containsKey(name)) throw kArgumentError;
    vecs[name] = from;
  }

  CMatrix? matrix(String name) => name == 'MatAns' ? matAns : mats[name];
  CVector? vector(String name) => name == 'VctAns' ? vctAns : vecs[name];

  void clear() {
    for (final k in mats.keys.toList()) {
      mats[k] = null;
    }
    for (final k in vecs.keys.toList()) {
      vecs[k] = null;
    }
    matAns = null;
    vctAns = null;
  }
}

/// The result of one `=`.
class MatVecOutcome {
  const MatVecOutcome({this.scalar, this.matrix, this.vector});
  final CVal? scalar;
  final CMatrix? matrix;
  final CVector? vector;
}

class CasioMatVec {
  CasioMatVec(this.store, this.memory);

  final MatVecStore store;
  final CasioMemory memory;

  /// Evaluate [input] in MATRIX ([vectorMode] false) or VECTOR mode. [commit] false leaves MatAns / VctAns / Ans alone.
  MatVecOutcome evaluate(String input, CasioConfig cfg, {required bool vectorMode, bool commit = true}) {
    var expr = input.trim();
    if (expr.isEmpty) expr = '0';
    if (cfg.phonePercent) expr = PhonePercent.apply(expr);
    final ast = CasioParser.parse(expr, matvec: true);
    final mem = commit ? memory : memory.copy();
    final ev = CasioEvaluator(cfg, mem);
    final run = _Run(ev, store, vectorMode);
    final v = run.finish(ast);
    switch (v) {
      case MatScalar():
        if (commit) memory.setAns(v.value);
        return MatVecOutcome(scalar: v.value);
      case CMatrix():
        if (commit) store.matAns = v;
        return MatVecOutcome(matrix: v);
      case CVector():
        if (commit) store.vctAns = v;
        return MatVecOutcome(vector: v);
    }
  }

  /// Texts of the cells of a matrix or vector as they are shown (one decimal / fraction / surd form each).
  static List<String> cellTexts(MatVal v, CasioConfig cfg) {
    final fmt = CasioFormatter(cfg);
    final cells = switch (v) {
      CMatrix() => v.cells,
      CVector() => v.cells,
      MatScalar() => <CVal>[v.value],
    };
    return <String>[for (final c in cells) fmt.first(c).display];
  }
}

// ---------------------------------------------------------------------------------------------------------------------

class _Run {
  _Run(this.ev, this.store, this.vectorMode);

  final CasioEvaluator ev;
  final MatVecStore store;
  final bool vectorMode;

  MatVal finish(Node root) {
    if (root is NSeq) throw kSyntaxError;
    return eval(root);
  }

  // ----- helpers ------------------------------------------------------------------------------------------------------

  CVal _scalar(MatVal v) {
    if (v is MatScalar) return v.value;
    throw kSyntaxError;
  }

  bool _isZero(CVal v) => v.v == 0 || (v.ex == null && v.v.abs() < 1e-13);

  CVal _sum(Iterable<CVal> items) {
    var s = CVal.int(0);
    for (final v in items) {
      s = ev.addV(s, v);
    }
    return s;
  }

  CVal _abs(CVal v) => v.v < 0 ? ev.negV(v) : v;

  // ----- evaluation ---------------------------------------------------------------------------------------------------

  MatVal eval(Node n) {
    switch (n) {
      case NNum():
        return MatScalar(ev.eval(n));
      case NVal():
        return MatScalar(n.value);
      case NName():
        return _name(n);
      case NNeg():
        final a = eval(n.a);
        switch (a) {
          case MatScalar():
            return MatScalar(ev.negV(a.value));
          case CMatrix():
            return CMatrix(a.rows, a.cols, [for (final c in a.cells) ev.negV(c)]);
          case CVector():
            return CVector([for (final c in a.cells) ev.negV(c)]);
        }
      case NBin():
        return _bin(n);
      case NPow():
        return _pow(n);
      case NPost():
        final a = eval(n.a);
        return MatScalar(ev.eval(NPost(n.op, NVal(_scalar(a), n.a.pos), n.pos)));
      case NCall():
        return _call(n);
      case NDms():
      case NSto():
      case NSeq():
        throw kSyntaxError;
    }
  }

  MatVal _name(NName n) {
    final name = n.name;
    if (name.startsWith('Mat')) {
      if (vectorMode) throw kSyntaxError;
      final m = store.matrix(name);
      if (m == null) throw kDimensionError;
      return m;
    }
    if (name.startsWith('Vct')) {
      if (!vectorMode) throw kSyntaxError;
      final v = store.vector(name);
      if (v == null) throw kDimensionError;
      return v;
    }
    return MatScalar(ev.eval(n));
  }

  MatVal _bin(NBin n) {
    final a = eval(n.a);
    final b = eval(n.b);
    if (a is MatScalar && b is MatScalar) {
      return MatScalar(ev.eval(NBin(n.op, NVal(a.value, n.a.pos), NVal(b.value, n.b.pos), n.pos, implicit: n.implicit)));
    }
    switch (n.op) {
      case '+':
        return _addSub(a, b, sub: false);
      case '-':
        return _addSub(a, b, sub: true);
      case '*':
        return _mul(a, b);
      case '/':
        // matrix or vector ÷ number (unverified on a real device); a number ÷ a matrix is not defined
        if (b is MatScalar) {
          if (b.value.v == 0) throw kMathError;
          return _scale(a, (c) => ev.divV(c, b.value));
        }
        throw kMathError;
      case 'Dot':
        if (a is CVector && b is CVector) {
          if (a.dim != b.dim) throw kDimensionError;
          return MatScalar(_sum([for (var i = 0; i < a.dim; i++) ev.mulV(a.cells[i], b.cells[i])]));
        }
        throw kSyntaxError;
    }
    throw kSyntaxError;
  }

  MatVal _scale(MatVal a, CVal Function(CVal) f) {
    switch (a) {
      case CMatrix():
        return CMatrix(a.rows, a.cols, [for (final c in a.cells) f(c)]);
      case CVector():
        return CVector([for (final c in a.cells) f(c)]);
      case MatScalar():
        return MatScalar(f(a.value));
    }
  }

  MatVal _addSub(MatVal a, MatVal b, {required bool sub}) {
    CVal op(CVal x, CVal y) => sub ? ev.subV(x, y) : ev.addV(x, y);
    if (a is CMatrix && b is CMatrix) {
      if (a.rows != b.rows || a.cols != b.cols) throw kDimensionError;
      return CMatrix(a.rows, a.cols, [for (var i = 0; i < a.cells.length; i++) op(a.cells[i], b.cells[i])]);
    }
    if (a is CVector && b is CVector) {
      if (a.dim != b.dim) throw kDimensionError;
      return CVector([for (var i = 0; i < a.dim; i++) op(a.cells[i], b.cells[i])]);
    }
    // a number and a matrix / vector do not add (unverified: the unit's exact error)
    throw kDimensionError;
  }

  MatVal _mul(MatVal a, MatVal b) {
    if (a is MatScalar) return _scale(b, (c) => ev.mulV(a.value, c));
    if (b is MatScalar) return _scale(a, (c) => ev.mulV(c, b.value));
    if (a is CMatrix && b is CMatrix) {
      if (a.cols != b.rows) throw kDimensionError;
      final out = <CVal>[];
      for (var i = 0; i < a.rows; i++) {
        for (var j = 0; j < b.cols; j++) {
          out.add(_sum([for (var k = 0; k < a.cols; k++) ev.mulV(a.at(i, k), b.at(k, j))]));
        }
      }
      return CMatrix(a.rows, b.cols, out);
    }
    if (a is CVector && b is CVector) return cross(a, b);
    throw kSyntaxError;
  }

  /// Cross product. 2-dimensional vectors are taken as (x, y, 0), so the result has 3 elements (unverified on a real device).
  MatVal cross(CVector a, CVector b) {
    if (a.dim != b.dim) throw kDimensionError;
    CVal z() => CVal.int(0);
    final p = a.dim == 2 ? [a.cells[0], a.cells[1], z()] : a.cells;
    final q = b.dim == 2 ? [b.cells[0], b.cells[1], z()] : b.cells;
    CVal c(int i, int j) => ev.subV(ev.mulV(p[i], q[j]), ev.mulV(p[j], q[i]));
    return CVector([c(1, 2), c(2, 0), c(0, 1)]);
  }

  MatVal _pow(NPow n) {
    final a = eval(n.a);
    final b = eval(n.b);
    if (a is MatScalar && b is MatScalar) {
      return MatScalar(ev.eval(NPow(NVal(a.value, n.a.pos), NVal(b.value, n.b.pos), n.pos)));
    }
    if (a is CMatrix && b is MatScalar) {
      final k = b.value.v;
      if (k == 2) return _mul(a, a);
      if (k == 3) return _mul(_mul(a, a), a);
      if (k == -1) return inverse(a);
    }
    throw kSyntaxError;
  }

  MatVal _call(NCall n) {
    final name = n.name;
    final args = [for (final a in n.args) eval(a)];
    switch (name) {
      case 'det':
        return MatScalar(determinant(_matrixArg(args)));
      case 'trn':
        return transpose(_matrixArg(args));
      case 'ref':
        return echelon(_matrixArg(args), reduced: false);
      case 'rref':
        return echelon(_matrixArg(args), reduced: true);
      case 'abs':
        if (args.length != 1) throw kArgumentError;
        final a = args.first;
        switch (a) {
          case CMatrix():
            return CMatrix(a.rows, a.cols, [for (final c in a.cells) _abs(c)]);
          case CVector():
            return MatScalar(ev.sqrtV(_sum([for (final c in a.cells) ev.mulV(c, c)])));
          case MatScalar():
            break;
        }
    }
    return MatScalar(ev.eval(NCall(name, [for (var i = 0; i < args.length; i++) NVal(_scalar(args[i]), n.args[i].pos)], n.pos)));
  }

  CMatrix _matrixArg(List<MatVal> args) {
    if (args.length != 1) throw kArgumentError;
    final a = args.first;
    if (a is CMatrix) return a;
    throw kSyntaxError;
  }

  // ----- matrix operations --------------------------------------------------------------------------------------------

  CMatrix transpose(CMatrix m) =>
      CMatrix(m.cols, m.rows, [for (var j = 0; j < m.cols; j++) for (var i = 0; i < m.rows; i++) m.at(i, j)]);

  CVal determinant(CMatrix m) {
    if (m.rows != m.cols) throw kDimensionError;
    CVal t(int a, int b) => m.at(a, b);
    CVal m2(CVal a, CVal b, CVal c, CVal d) => ev.subV(ev.mulV(a, d), ev.mulV(b, c));
    switch (m.rows) {
      case 1:
        return t(0, 0);
      case 2:
        return m2(t(0, 0), t(0, 1), t(1, 0), t(1, 1));
      default:
        // expansion along the first row
        final c0 = ev.mulV(t(0, 0), m2(t(1, 1), t(1, 2), t(2, 1), t(2, 2)));
        final c1 = ev.mulV(t(0, 1), m2(t(1, 0), t(1, 2), t(2, 0), t(2, 2)));
        final c2 = ev.mulV(t(0, 2), m2(t(1, 0), t(1, 1), t(2, 0), t(2, 1)));
        return ev.addV(ev.subV(c0, c1), c2);
    }
  }

  CMatrix inverse(CMatrix m) {
    if (m.rows != m.cols) throw kDimensionError;
    final d = determinant(m);
    if (_isZero(d)) throw kMathError;
    final n = m.rows;
    if (n == 1) return CMatrix(1, 1, [ev.divV(CVal.int(1), m.at(0, 0))]);
    // adjugate / det, the cofactor of (i, j) taken from the remaining rows and columns
    CVal minor(int i, int j) {
      final rest = <CVal>[];
      for (var r = 0; r < n; r++) {
        for (var c = 0; c < n; c++) {
          if (r != i && c != j) rest.add(m.at(r, c));
        }
      }
      if (n == 2) return rest[0];
      return ev.subV(ev.mulV(rest[0], rest[3]), ev.mulV(rest[1], rest[2]));
    }

    final out = <CVal>[];
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        // element (i, j) of the inverse is the cofactor of (j, i) over det
        var cof = minor(j, i);
        if ((i + j).isOdd) cof = ev.negV(cof);
        out.add(ev.divV(cof, d));
      }
    }
    return CMatrix(n, n, out);
  }

  /// Ref (leading 1 in each row, zeros below) or Rref (also zeros above). Pivots are the first non-zero entry (unverified
  /// against the unit for a Ref whose result depends on the pivot choice).
  CMatrix echelon(CMatrix m, {required bool reduced}) {
    final rows = <List<CVal>>[
      for (var i = 0; i < m.rows; i++) [for (var j = 0; j < m.cols; j++) m.at(i, j)],
    ];
    var r = 0;
    for (var c = 0; c < m.cols && r < m.rows; c++) {
      var p = -1;
      for (var i = r; i < m.rows; i++) {
        if (!_isZero(rows[i][c])) {
          p = i;
          break;
        }
      }
      if (p < 0) continue;
      final tmp = rows[p];
      rows[p] = rows[r];
      rows[r] = tmp;
      final pv = rows[r][c];
      rows[r] = [for (final v in rows[r]) ev.divV(v, pv)];
      for (var i = 0; i < m.rows; i++) {
        if (i == r || (!reduced && i < r)) continue;
        final f = rows[i][c];
        if (_isZero(f)) continue;
        rows[i] = [for (var j = 0; j < m.cols; j++) ev.subV(rows[i][j], ev.mulV(f, rows[r][j]))];
      }
      r++;
    }
    return CMatrix(m.rows, m.cols, [
      for (final row in rows)
        for (final v in row) _isZero(v) ? CVal.int(0) : v,
    ]);
  }
}

/// Rendering helper for the UI: the exact value of an element as text (a fraction, √ form or decimal).
String matrixCellText(CVal v, CasioConfig cfg) => CasioFormatter(cfg).first(v).display;

/// Whether the element is an exact rational (used by tests).
bool isExactRational(CVal v) => v.ex != null && v.ex!.isRational;

/// Convenience for tests: the rational value of an element as `n/d`, or null.
String? ratText(CVal v) {
  final Ex? ex = v.ex;
  if (ex == null || !ex.isRational) return null;
  return ex.rational.toString();
}
