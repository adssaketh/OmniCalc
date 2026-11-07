import 'package:flutter/foundation.dart';

/// Node model of the rich expression editor (Part 2 of the master prompt).
///
/// An expression is a list of nodes. A [CharNode] is one character of the text the engine reads; a [SupNode] is a
/// raised group (the exponent of `^`); a [SubNode] is a lowered group (`_`). The structured Part 9 nodes (fraction,
/// root, ...) are the [StructNode]s added in Phase 8a on top of [GroupNode]; integrals, sums and the rest follow in 8c.
@immutable
sealed class Node {
  const Node();

  /// Compact JSON: see [nodesToJson].
  Object toJson();
}

/// One UTF-16 code unit of text. All characters the keypad produces are in the BMP.
final class CharNode extends Node {
  const CharNode(this.ch);

  final String ch;

  @override
  Object toJson() => ch;

  @override
  bool operator ==(Object other) => other is CharNode && other.ch == ch;

  @override
  int get hashCode => ch.hashCode;

  @override
  String toString() => 'Char($ch)';
}

/// A node that holds its own list of children (the caret can sit inside it).
sealed class GroupNode extends Node {
  GroupNode(List<Node> children) : children = List<Node>.of(children);

  /// Mutable on purpose: the editor changes the tree in place (see `ExprDoc`).
  final List<Node> children;

  /// Key used in the JSON form.
  String get jsonKey;

  @override
  Object toJson() => <String, Object?>{jsonKey: nodesToJson(children)};

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType && listEquals(children, (other as GroupNode).children);

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(children));
}

/// Raised group: the exponent of `^`.
final class SupNode extends GroupNode {
  SupNode([super.children = const []]);

  @override
  String get jsonKey => 'sup';

  @override
  String toString() => 'Sup($children)';
}

/// Lowered group: written `_` in the linear form.
///
/// A [bare] subscript is the base of `log₂` / `log_b`: it is drawn lowered but written WITHOUT the `_` (`log2(`,
/// `logb(`), because that is the text the engine reads. [parseLinear] makes one of every `log2(` and `logb(`.
final class SubNode extends GroupNode {
  SubNode([super.children = const [], this.bare = false]);

  final bool bare;

  @override
  String get jsonKey => bare ? 'bsub' : 'sub';

  @override
  bool operator ==(Object other) => other is SubNode && other.bare == bare && super == other;

  @override
  int get hashCode => Object.hash(super.hashCode, bare);

  @override
  String toString() => bare ? 'BareSub($children)' : 'Sub($children)';
}

/// A place the caret can stand inside a structure: the numerator of a fraction, the radicand of a root, ...
///
/// A slot never appears in an expression list; it is only a child of a [StructNode]. The caret path of something typed
/// in a numerator is `[indexOfFraction, 0, ...]`: the first step picks the structure, the second its slot.
final class SlotNode extends GroupNode {
  SlotNode([super.children = const []]);

  @override
  String get jsonKey => 'slot';

  @override
  String toString() => 'Slot($children)';
}

/// A natural-display structure (Part 9, section 9.2) whose [children] are its [SlotNode]s, in reading order.
/// An empty slot is a placeholder: it is drawn as a hollow box and calculating with it is a Syntax ERROR.
sealed class StructNode extends GroupNode {
  // ignore: use_super_parameters
  StructNode(List<SlotNode> slots) : super(slots);

  /// The slots, in the order the caret visits them.
  List<SlotNode> get slots => children.cast<SlotNode>();

  @override
  Object toJson() => <String, Object?>{
        jsonKey: [for (final s in slots) nodesToJson(s.children)],
      };

  /// Every slot empty: Backspace removes the whole structure.
  bool get allEmpty => slots.every((s) => s.children.isEmpty);
}

/// Stacked fraction: numerator, denominator.
final class FracNode extends StructNode {
  FracNode([List<SlotNode>? slots]) : super(slots ?? [SlotNode(), SlotNode()]);

  @override
  String get jsonKey => 'frac';

  @override
  String toString() => 'Frac($children)';
}

/// Mixed fraction: whole part, numerator, denominator.
final class MixedFracNode extends StructNode {
  MixedFracNode([List<SlotNode>? slots]) : super(slots ?? [SlotNode(), SlotNode(), SlotNode()]);

  @override
  String get jsonKey => 'mixed';

  @override
  String toString() => 'Mixed($children)';
}

/// Square root with an overbar: one slot.
final class SqrtNode extends StructNode {
  SqrtNode([List<SlotNode>? slots]) : super(slots ?? [SlotNode()]);

  @override
  String get jsonKey => 'sqrt';

  @override
  String toString() => 'Sqrt($children)';
}

/// n-th root: index, radicand.
final class RootNode extends StructNode {
  RootNode([List<SlotNode>? slots]) : super(slots ?? [SlotNode(), SlotNode()]);

  @override
  String get jsonKey => 'root';

  @override
  String toString() => 'Root($children)';
}

/// Absolute value bars: one slot.
final class AbsNode extends StructNode {
  AbsNode([List<SlotNode>? slots]) : super(slots ?? [SlotNode()]);

  @override
  String get jsonKey => 'abs';

  @override
  String toString() => 'Abs($children)';
}

/// log with a lowered base: base, argument (`log` + base + argument, as the key shows it).
final class LogBaseNode extends StructNode {
  LogBaseNode([List<SlotNode>? slots]) : super(slots ?? [SlotNode(), SlotNode()]);

  @override
  String get jsonKey => 'logb';

  @override
  String toString() => 'LogBase($children)';
}

/// Builds the structure called [key] around [slots] (null for a name this editor does not know).
StructNode? structFromKey(String key, List<SlotNode> slots) {
  switch (key) {
    case 'frac':
      return slots.length == 2 ? FracNode(slots) : null;
    case 'mixed':
      return slots.length == 3 ? MixedFracNode(slots) : null;
    case 'sqrt':
      return slots.length == 1 ? SqrtNode(slots) : null;
    case 'root':
      return slots.length == 2 ? RootNode(slots) : null;
    case 'abs':
      return slots.length == 1 ? AbsNode(slots) : null;
    case 'logb':
      return slots.length == 2 ? LogBaseNode(slots) : null;
  }
  return null;
}

const Set<String> _structKeys = {'frac', 'mixed', 'sqrt', 'root', 'abs', 'logb'};

/// Nodes as plain JSON: runs of characters become one string, a group becomes `{"sup": [...]}` or `{"sub": [...]}`.
/// `[ "2", {"sup": ["3", "+", "x"]}, "+1" ]` is `2` then a superscript `3+x`, then `+1`.
List<Object> nodesToJson(List<Node> nodes) {
  final out = <Object>[];
  final run = StringBuffer();
  void flush() {
    if (run.isNotEmpty) {
      out.add(run.toString());
      run.clear();
    }
  }

  for (final n in nodes) {
    if (n is CharNode) {
      run.write(n.ch);
    } else {
      flush();
      out.add(n.toJson());
    }
  }
  flush();
  return out;
}

/// Inverse of [nodesToJson]. Returns null when [raw] is not a tree this editor wrote (callers fall back to the linear
/// string, which is how entries from before the editor are loaded).
List<Node>? nodesFromJson(Object? raw, {int depth = 0}) {
  if (raw is! List || depth > 32) return null;
  final out = <Node>[];
  for (final item in raw) {
    if (item is String) {
      for (final unit in item.codeUnits) {
        out.add(CharNode(String.fromCharCode(unit)));
      }
    } else if (item is Map && item.length == 1 && _structKeys.contains(item.keys.first)) {
      final key = item.keys.first as String;
      final raw = item[key];
      if (raw is! List) return null;
      final slots = <SlotNode>[];
      for (final part in raw) {
        final inner = nodesFromJson(part, depth: depth + 1);
        if (inner == null) return null;
        slots.add(SlotNode(inner));
      }
      final node = structFromKey(key, slots);
      if (node == null) return null;
      out.add(node);
    } else if (item is Map && item.length == 1) {
      final sup = item['sup'];
      final sub = item['sub'];
      final bsub = item['bsub'];
      if (bsub != null) {
        final inner = nodesFromJson(bsub, depth: depth + 1);
        if (inner == null) return null;
        out.add(SubNode(inner, true));
      } else if (sup != null) {
        final inner = nodesFromJson(sup, depth: depth + 1);
        if (inner == null) return null;
        out.add(SupNode(inner));
      } else if (sub != null) {
        final inner = nodesFromJson(sub, depth: depth + 1);
        if (inner == null) return null;
        out.add(SubNode(inner));
      } else {
        return null;
      }
    } else {
      return null;
    }
  }
  return out;
}
