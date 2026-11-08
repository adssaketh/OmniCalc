// VERIF mode of the Casio engine (Phase 7e, manual p.85-87): checks an equality or inequality and answers TRUE or FALSE
// (Ans becomes 1 or 0). One or several relational operators may be chained when they point the same way.
//
// Syntax ERROR cases (manual p.86): nothing on one side, a relational operator inside a fraction / function / parentheses,
// operators pointing in different directions (5≤6≥4), `≠` mixed with an ordering relation (4<6≠8), two operators in a row.

import 'cval.dart';
import 'engine.dart';

enum VerifOp {
  eq('=', 0),
  ne('≠', 0),
  lt('<', 1),
  le('≤', 1),
  gt('>', -1),
  ge('≥', -1);

  const VerifOp(this.symbol, this.direction);

  final String symbol;

  /// +1 for `<` `≤`, -1 for `>` `≥`, 0 for `=` and `≠`.
  final int direction;

  bool holds(double a, double b) {
    switch (this) {
      case VerifOp.eq:
        return a == b;
      case VerifOp.ne:
        return a != b;
      case VerifOp.lt:
        return a < b;
      case VerifOp.le:
        return a <= b;
      case VerifOp.gt:
        return a > b;
      case VerifOp.ge:
        return a >= b;
    }
  }
}

/// The relational operator characters and their alternative spellings.
const Map<String, VerifOp> kVerifSymbols = <String, VerifOp>{
  '=': VerifOp.eq,
  '≠': VerifOp.ne,
  '<': VerifOp.lt,
  '>': VerifOp.gt,
  '≤': VerifOp.le,
  '≦': VerifOp.le,
  '≥': VerifOp.ge,
  '≧': VerifOp.ge,
};

class VerifOutcome {
  const VerifOutcome(this.isTrue);

  final bool isTrue;

  String get text => isTrue ? 'TRUE' : 'FALSE';
}

class CasioVerif {
  const CasioVerif._();

  /// Splits [input] at its top-level relational operators. Throws Syntax ERROR for every form of the manual's list.
  static ({List<String> operands, List<VerifOp> ops}) split(String input) {
    final operands = <String>[];
    final ops = <VerifOp>[];
    var depth = 0;
    var start = 0;
    var lastWasOp = true; // an operator first (nothing on its left) is a Syntax ERROR as well
    var sawOperand = false;
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      if (ch == '(' || ch == '[' || ch == '{') {
        depth++;
        lastWasOp = false;
        continue;
      }
      if (ch == ')' || ch == ']' || ch == '}') {
        depth--;
        lastWasOp = false;
        continue;
      }
      final op = kVerifSymbols[ch];
      if (op == null) {
        if (ch.trim().isNotEmpty) lastWasOp = false;
        continue;
      }
      // a relational operator in parentheses, a fraction or a function argument
      if (depth != 0) throw CasioError(CasioErrorKind.syntax, i);
      final left = input.substring(start, i);
      if (left.trim().isEmpty) throw CasioError(CasioErrorKind.syntax, i); // nothing on the left / two operators in a row
      operands.add(left);
      ops.add(op);
      sawOperand = true;
      start = i + 1;
      lastWasOp = true;
    }
    final tail = input.substring(start);
    if (!sawOperand || tail.trim().isEmpty || (lastWasOp && tail.trim().isEmpty)) throw kSyntaxError;
    operands.add(tail);
    _checkDirections(ops);
    return (operands: operands, ops: ops);
  }

  static void _checkDirections(List<VerifOp> ops) {
    var dir = 0;
    var hasNe = false;
    var hasOrder = false;
    for (final o in ops) {
      if (o == VerifOp.ne) hasNe = true;
      if (o.direction != 0) {
        hasOrder = true;
        if (dir != 0 && dir != o.direction) throw kSyntaxError; // 5≤6≥4
        dir = o.direction;
      }
    }
    if (hasNe && hasOrder) throw kSyntaxError; // 4<6≠8
  }

  static final RegExp _forbidden = RegExp(r'÷R|Pol\s*\(|Rec\s*\(', caseSensitive: true);

  /// Evaluates [input] with [engine]; every operand is calculated by the Casio engine (exact values compare exactly, others at
  /// the unit's 15 digits). Ans is set to 1 (TRUE) or 0 (FALSE).
  static VerifOutcome verify(CasioEngine engine, String input) {
    final text = input.replaceAll(' ', '');
    if (_forbidden.hasMatch(text)) throw kSyntaxError;
    final parts = split(text);
    final values = <CVal>[];
    for (final operand in parts.operands) {
      final out = engine.evaluate(operand, commit: false);
      final v = out.value;
      if (v == null) throw kSyntaxError;
      values.add(v);
    }
    var ok = true;
    for (var i = 0; i < parts.ops.length; i++) {
      if (!parts.ops[i].holds(values[i].v, values[i + 1].v)) {
        ok = false;
        break;
      }
    }
    engine.memory.setAns(CVal.int(ok ? 1 : 0));
    engine.memory.ansText = ok ? '1' : '0';
    return VerifOutcome(ok);
  }
}
