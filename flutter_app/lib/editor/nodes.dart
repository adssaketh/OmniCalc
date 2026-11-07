import 'package:flutter/foundation.dart';

/// Node model of the rich expression editor (Part 2 of the master prompt).
///
/// An expression is a list of nodes. A [CharNode] is one character of the text the engine reads; a [SupNode] is a
/// raised group (the exponent of `^`); a [SubNode] is a lowered group (`_`). The structured Part 9 nodes (fraction,
/// root, integral, ...) are added in Phase 8a on top of [GroupNode]; nothing here assumes there are only two kinds.
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
final class SubNode extends GroupNode {
  SubNode([super.children = const []]);

  @override
  String get jsonKey => 'sub';

  @override
  String toString() => 'Sub($children)';
}

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
    } else if (item is Map && item.length == 1) {
      final sup = item['sup'];
      final sub = item['sub'];
      if (sup != null) {
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
