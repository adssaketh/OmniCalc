// Stack ERROR (manual p.93): "the calculation you are performing has caused the capacity of the numeric stack or the command
// stack to be exceeded". Splitting the calculation into parts is the action the guide gives.
//
// The guide does not say how many levels the stacks have. The figures below (10 numeric levels, 24 command levels) are the
// ones older Casio guides print for this family; they are NOT in this guide and are unverified on a real device. The
// depth is measured on the parsed tree the way a left-to-right evaluator holds it: while the right operand of an operator is
// worked out, the left operand waits on the numeric stack and the operator on the command stack.

import 'parser.dart';

const int kNumericStackLevels = 10;
const int kCommandStackLevels = 24;

class CasioStackCheck {
  const CasioStackCheck._();

  /// Peak numeric stack depth of [n].
  static int numeric(Node n) {
    switch (n) {
      case NNum() || NName() || NVal():
        return 1;
      case NNeg(:final a) || NPost(:final a) || NSto(:final a):
        return numeric(a);
      case NBin(:final a, :final b) || NPow(:final a, :final b):
        final l = numeric(a);
        final r = 1 + numeric(b);
        return l > r ? l : r;
      case NCall(:final args):
        return _seq(args, numeric, 1);
      case NSeq(:final stmts):
        var m = 0;
        for (final s in stmts) {
          final v = numeric(s);
          if (v > m) m = v;
        }
        return m;
      case NDms(:final d, :final m, :final s):
        return _seq(<Node>[d, if (m != null) m, if (s != null) s], numeric, 1);
    }
  }

  /// Peak command stack depth of [n].
  static int command(Node n) {
    switch (n) {
      case NNum() || NName() || NVal():
        return 0;
      case NNeg(:final a):
        return 1 + command(a);
      case NPost(:final a) || NSto(:final a):
        return command(a);
      case NBin(:final a, :final b) || NPow(:final a, :final b):
        final l = command(a);
        final r = 1 + command(b);
        return l > r ? l : r;
      case NCall(:final args):
        var m = 0;
        for (final a in args) {
          final v = command(a);
          if (v > m) m = v;
        }
        return 1 + m;
      case NSeq(:final stmts):
        var m = 0;
        for (final s in stmts) {
          final v = command(s);
          if (v > m) m = v;
        }
        return m;
      case NDms(:final d, :final m, :final s):
        var best = command(d);
        if (m != null && command(m) > best) best = command(m);
        if (s != null && command(s) > best) best = command(s);
        return best;
    }
  }

  static int _seq(List<Node> items, int Function(Node) depth, int base) {
    var m = 0;
    for (var i = 0; i < items.length; i++) {
      final v = i + depth(items[i]);
      if (v > m) m = v;
    }
    return m < base ? base : m;
  }

  /// True when [ast] needs more stack than the unit has.
  static bool exceeds(Node ast) => numeric(ast) > kNumericStackLevels || command(ast) > kCommandStackLevels;
}
