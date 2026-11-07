import 'package:flutter/foundation.dart' show listEquals;

import 'linear.dart';
import 'nodes.dart';

/// Deepest nesting of superscripts / subscripts (Part 2: "up to 3 levels").
const int kMaxNesting = 3;

int _versionCounter = 0;

/// An expression being edited: the node tree plus the caret.
///
/// The caret is `(path, offset)`: [path] lists, from the root, the index of the group to step into at each level
/// (empty means the root list), [offset] is the gap inside that list (0 = before its first node). The tree is changed
/// in place and [version] changes with every edit or caret move, so views know when to redraw.
class ExprDoc {
  ExprDoc._(this.root, List<int> path, this.offset) : path = List<int>.of(path) {
    version = _versionCounter++;
  }

  /// Characters only, caret at the end. Nothing is parsed: used for results and messages, which must show as they are.
  factory ExprDoc.plain(String s) =>
      ExprDoc._([for (final u in s.codeUnits) CharNode(String.fromCharCode(u))], const [], s.length);

  /// The tree of a linear string, caret where typing that string would have left it (see [LinearParse]).
  factory ExprDoc.fromLinear(String s) {
    final p = parseLinear(s);
    return ExprDoc._(p.nodes, p.path, p.offset);
  }

  factory ExprDoc.fromNodes(List<Node> nodes) => ExprDoc._(List<Node>.of(nodes), const [], nodes.length);

  /// A tree saved by [toJson]; null when [raw] is not one.
  static ExprDoc? fromJson(Object? raw) {
    final nodes = nodesFromJson(raw);
    return nodes == null ? null : ExprDoc.fromNodes(nodes);
  }

  final List<Node> root;
  final List<int> path;
  int offset;

  /// Changes whenever the tree or the caret changes; unique across documents.
  late int version;

  String? _linear;

  // -- Reading ------------------------------------------------------------------------------------------------------
  /// What the engine reads (cached until the next edit).
  String get linear => _linear ??= serializeNodes(root);

  List<Object> toJson() => nodesToJson(root);

  /// Number of groups the caret is inside (0 = root list).
  int get depth => path.length;

  bool get inGroup => path.isNotEmpty;

  /// The caret is at the very end of the root list: plain typing appends, exactly like the old text field.
  bool get atRootEnd => path.isEmpty && offset == root.length;

  bool get hasGroups => root.any((n) => n is GroupNode);

  List<Node> listAt(List<int> p) {
    var cur = root;
    for (final idx in p) {
      cur = (cur[idx] as GroupNode).children;
    }
    return cur;
  }

  List<Node> get current => listAt(path);

  /// The character just before the caret: '' at the start of a list, `\u0000` when a group is there.
  String get prevChar {
    if (offset == 0) return '';
    final n = current[offset - 1];
    return n is CharNode ? n.ch : '\u0000';
  }

  /// The text of the current list before the caret, back to the last non-character node (for token deletion and the
  /// duplicate-dot check).
  String get textBeforeCaret {
    final cur = current;
    final b = <String>[];
    for (var i = offset - 1; i >= 0; i--) {
      final n = cur[i];
      if (n is! CharNode) break;
      b.add(n.ch);
    }
    return b.reversed.join();
  }

  /// A spoken form for screen readers: "x squared", "x to the power of 3 plus 1", "H subscript 2 O".
  String get semanticsLabel => _spoken(root).replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _spoken(List<Node> nodes) {
    final b = StringBuffer();
    for (final n in nodes) {
      switch (n) {
        case CharNode(:final ch):
          b.write(ch);
        case SupNode(:final children):
          final inner = serializeNodes(children);
          b.write(inner == '2' ? ' squared ' : ' to the power of ${_spoken(children)} ');
        case SubNode(:final children):
          b.write(' subscript ${_spoken(children)} ');
      }
    }
    return b.toString();
  }

  // -- Editing ------------------------------------------------------------------------------------------------------
  void _touch({bool content = true}) {
    if (content) _linear = null;
    version = _versionCounter++;
  }

  /// Puts the caret at ([p], [o]) when that place exists. Returns whether it moved.
  bool setCaret(List<int> p, int o) {
    var cur = root;
    for (final idx in p) {
      if (idx < 0 || idx >= cur.length) return false;
      final n = cur[idx];
      if (n is! GroupNode) return false;
      cur = n.children;
    }
    if (o < 0 || o > cur.length) return false;
    if (listEquals(p, path) && o == offset) return false;
    path
      ..clear()
      ..addAll(p);
    offset = o;
    _touch(content: false);
    return true;
  }

  /// Inserts plain characters at the caret.
  void insertChars(String s) {
    if (s.isEmpty) return;
    final cur = current;
    final nodes = [for (final u in s.codeUnits) CharNode(String.fromCharCode(u))];
    cur.insertAll(offset, nodes);
    offset += nodes.length;
    _touch();
  }

  /// Inserts the tree of a linear string at the caret (`sin(`, `^2`, `10^(`, `×`). When that text leaves a group
  /// unfinished the caret goes inside it, as with typing.
  void insertLinear(String s) {
    if (s.isEmpty) return;
    final p = parseLinear(s);
    final cur = current;
    final base = offset;
    cur.insertAll(base, p.nodes);
    if (p.path.isEmpty) {
      offset = base + p.nodes.length;
    } else {
      path
        ..add(base + p.path.first)
        ..addAll(p.path.skip(1));
      offset = p.offset;
    }
    _touch();
  }

  /// Opens a superscript (or subscript) at the caret with the caret inside. False when already [kMaxNesting] deep.
  bool insertGroup({required bool sup}) {
    if (depth >= kMaxNesting) return false;
    final cur = current;
    final idx = offset;
    cur.insert(idx, sup ? SupNode() : SubNode());
    path.add(idx);
    offset = 0;
    _touch();
    return true;
  }

  /// Right arrow: step over a character, step into a group, or leave the group at its end. False at the very end.
  bool moveRight() {
    final cur = current;
    if (offset < cur.length) {
      final n = cur[offset];
      if (n is GroupNode) {
        path.add(offset);
        offset = 0;
      } else {
        offset++;
      }
      _touch(content: false);
      return true;
    }
    if (path.isNotEmpty) return exitGroup();
    return false;
  }

  /// Left arrow: step back over a character, into a group from its end, or out of a group at its start.
  bool moveLeft() {
    final cur = current;
    if (offset > 0) {
      final n = cur[offset - 1];
      if (n is GroupNode) {
        path.add(offset - 1);
        offset = n.children.length;
      } else {
        offset--;
      }
      _touch(content: false);
      return true;
    }
    if (path.isNotEmpty) {
      offset = path.removeLast();
      _touch(content: false);
      return true;
    }
    return false;
  }

  /// The exit key: leaves the group the caret is in and lands just after it, wherever the caret was inside.
  bool exitGroup() {
    if (path.isEmpty) return false;
    offset = path.removeLast() + 1;
    _touch(content: false);
    return true;
  }

  /// Backspace. [tokens] are the multi-character names removed as one piece (`sin(`, `y=`...), tested in order.
  /// - after a character: removes it (or the token that ends there)
  /// - after an empty group: removes the group; after a group with content: steps into it
  /// - at the start of a group: removes it when empty, otherwise steps out in front of it
  void backspace(List<String> tokens) {
    final cur = current;
    if (offset > 0) {
      final n = cur[offset - 1];
      if (n is CharNode) {
        final before = textBeforeCaret;
        var cut = 1;
        for (final t in tokens) {
          if (before.endsWith(t)) {
            cut = t.length;
            break;
          }
        }
        cur.removeRange(offset - cut, offset);
        offset -= cut;
      } else if (n is GroupNode) {
        if (n.children.isEmpty) {
          cur.removeAt(offset - 1);
          offset--;
        } else {
          path.add(offset - 1);
          offset = n.children.length;
          _touch(content: false);
          return;
        }
      }
      _touch();
      return;
    }
    if (path.isNotEmpty) {
      final idx = path.removeLast();
      final parent = current;
      if (cur.isEmpty) parent.removeAt(idx);
      offset = idx;
      _touch();
    }
  }

  /// Everything off the list, caret in the root.
  void clearAll() {
    root.clear();
    path.clear();
    offset = 0;
    _touch();
  }

  // -- Hit testing helpers ------------------------------------------------------------------------------------------
  /// Number of nodes in the list at [p].
  int lengthAt(List<int> p) => listAt(p).length;
}
