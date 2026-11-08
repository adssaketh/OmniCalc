// TABLE mode of the Casio engine (Phase 7d-2, manual p.76-78): a table of f(x), or of f(x) and g(x), for X from Start to End in
// steps of Step. Rows are limited to 30 (f only) or 20 (f and g); more is an `Insufficient MEM` error.

import 'config.dart';
import 'cval.dart';
import 'engine.dart';
import 'evaluator.dart';
import 'format.dart';

/// Defaults of the prompts (manual p.77).
const double kTableDefaultStart = 1;
const double kTableDefaultEnd = 5;
const double kTableDefaultStep = 1;

/// Maximum rows for the setup table format.
int tableMaxRows({required bool fg}) => fg ? 20 : 30;

/// One line of the table. A function value that could not be calculated (Math ERROR at that x) is null and shown as ERROR.
class CasioTableRow {
  const CasioTableRow(this.x, this.f, this.g, {this.fError, this.gError});

  final CVal x;
  final CVal? f;
  final CVal? g;
  final String? fError;
  final String? gError;
}

class CasioTable {
  const CasioTable._();

  static final RegExp _forbidden = RegExp(r'Pol\s*\(|Rec\s*\(|∫|d/dx|[Σ∑∏]|÷R');

  /// True when [text] may be used as a table function (Pol, Rec, ∫, d/dx, Σ, ∏ are not allowed).
  static bool allowed(String text) => !_forbidden.hasMatch(text);

  /// Generates the table. [g] is only used when [fg] is true. Throws Argument ERROR for End ≤ Start or a Step that is not
  /// positive, Syntax ERROR for a forbidden function, and Insufficient MEM for too many rows. The value of X changes to the
  /// last X of the table (manual p.78).
  static List<CasioTableRow> generate({
    required String f,
    String? g,
    required bool fg,
    required CVal start,
    required CVal end,
    required CVal step,
    required CasioConfig config,
    required CasioMemory memory,
  }) {
    final ftext = f.trim();
    final gtext = (g ?? '').trim();
    if (ftext.isEmpty) throw kSyntaxError;
    if (!allowed(ftext) || !allowed(gtext)) throw kSyntaxError;
    if (end.v <= start.v || step.v <= 0) throw kArgumentError;
    final span = (end.v - start.v) / step.v;
    final count = (span + 1e-9).floor() + 1;
    final useG = fg && gtext.isNotEmpty;
    if (count > tableMaxRows(fg: fg)) throw const CasioError(CasioErrorKind.insufficientMem);
    final cfg = config.copyWith(useCasio: true);
    final engine = CasioEngine(config: cfg, memory: memory);
    final ev = CasioEvaluator(cfg, memory);
    final rows = <CasioTableRow>[];
    CVal? lastX;
    for (var i = 0; i < count; i++) {
      final x = ev.addV(start, ev.mulV(CVal.int(i), step));
      lastX = x;
      memory.vars['X'] = x;
      CVal? fv;
      CVal? gv;
      String? fe;
      String? ge;
      try {
        fv = engine.evaluate(ftext, commit: false).value;
      } on CasioError catch (e) {
        fe = e.message;
      }
      if (useG) {
        try {
          gv = engine.evaluate(gtext, commit: false).value;
        } on CasioError catch (e) {
          ge = e.message;
        }
      }
      rows.add(CasioTableRow(x, fv, gv, fError: fe, gError: ge));
    }
    if (lastX != null) memory.vars['X'] = lastX;
    return rows;
  }

  /// Text of a cell: the value in the display format, or `ERROR`.
  static String cellText(CVal? v, String? error, CasioConfig cfg) {
    if (v == null) return error == null ? '' : 'ERROR';
    return CasioFormatter(cfg).first(v).display;
  }
}
