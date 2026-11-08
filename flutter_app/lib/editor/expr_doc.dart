import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;

import 'example_doc.dart';
import 'linear.dart';
import 'nodes.dart';

/// Deepest nesting of superscripts / subscripts (Part 2: "up to 3 levels").
const int kMaxNesting = 3;

/// Deepest nesting of fractions, roots and the other structures (the manual: too much nesting refuses further input).
const int kMaxStructDepth = 4;

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

  /// Like [fromLinear], but `∫(f,a,b)`, `Σ(f,a,b)`, `∏(f,a,b)` and `d/dx(f,x)` become the structures of the natural display
  /// (boxes filled in). For text from outside the editor: the guide's examples and the history.
  factory ExprDoc.fromExample(String s) {
    final nodes = nodesFromExample(s);
    return ExprDoc._(nodes, const [], nodes.length);
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

  /// The groups the caret is inside, outermost first (a structure and then its slot are two entries).
  List<GroupNode> get chain {
    final out = <GroupNode>[];
    var cur = root;
    for (final idx in path) {
      final g = cur[idx] as GroupNode;
      out.add(g);
      cur = g.children;
    }
    return out;
  }

  /// Superscripts / subscripts the caret is inside (limited to [kMaxNesting]).
  int get scriptDepth => chain.where((g) => g is SupNode || g is SubNode).length;

  /// Fractions, roots and other structures the caret is inside (limited to [kMaxStructDepth]).
  int get structDepth => chain.whereType<StructNode>().length;

  /// The caret is in a slot of a structure (numerator, radicand, ...).
  bool get inSlot => path.isNotEmpty && chain.last is SlotNode;

  /// The structure and slot index the caret is in, or null.
  (StructNode, int)? get slotOwner {
    if (!inSlot) return null;
    final c = chain;
    return (c[c.length - 2] as StructNode, path.last);
  }

  bool get hasStructure {
    bool walk(List<Node> l) => l.any((n) => n is StructNode || (n is GroupNode && walk(n.children)));
    return walk(root);
  }

  /// Path of the first empty slot (a placeholder) in reading order, or null when every slot is filled.
  List<int>? get firstPlaceholderPath {
    List<int>? walk(List<Node> list, List<int> prefix) {
      for (var i = 0; i < list.length; i++) {
        final n = list[i];
        if (n is StructNode) {
          for (var k = 0; k < n.slots.length; k++) {
            final slot = n.slots[k];
            if (slot.children.isEmpty) return [...prefix, i, k];
            final inner = walk(slot.children, [...prefix, i, k]);
            if (inner != null) return inner;
          }
        } else if (n is GroupNode) {
          final inner = walk(n.children, [...prefix, i]);
          if (inner != null) return inner;
        }
      }
      return null;
    }

    return walk(root, const []);
  }

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
        case SubNode(:final children, :final bare):
          b.write(bare ? ' base ${_spoken(children)} ' : ' subscript ${_spoken(children)} ');
        case SlotNode(:final children):
          b.write(_spoken(children));
        case FracNode(:final slots):
          b.write(' fraction ${_slotSpoken(slots[0])} over ${_slotSpoken(slots[1])} end fraction ');
        case MixedFracNode(:final slots):
          b.write(' ${_slotSpoken(slots[0])} and ${_slotSpoken(slots[1])} over ${_slotSpoken(slots[2])} end fraction ');
        case SqrtNode(:final slots):
          b.write(' square root of ${_slotSpoken(slots[0])} end root ');
        case RootNode(:final slots):
          b.write(' root ${_slotSpoken(slots[0])} of ${_slotSpoken(slots[1])} end root ');
        case AbsNode(:final slots):
          b.write(' absolute value of ${_slotSpoken(slots[0])} end absolute value ');
        case LogBaseNode(:final slots):
          b.write(' log base ${_slotSpoken(slots[0])} of ${_slotSpoken(slots[1])} ');
        case IntegralNode(:final slots):
          b.write(' integral of ${_slotSpoken(slots[0])} from ${_slotSpoken(slots[1])} to ${_slotSpoken(slots[2])} ');
        case DerivNode(:final slots):
          b.write(' derivative of ${_slotSpoken(slots[0])} at x equals ${_slotSpoken(slots[1])} ');
        case SigmaNode(:final slots):
          b.write(' sum of ${_slotSpoken(slots[0])} for x from ${_slotSpoken(slots[1])} to ${_slotSpoken(slots[2])} ');
        case ProdNode(:final slots):
          b.write(' product of ${_slotSpoken(slots[0])} for x from ${_slotSpoken(slots[1])} to ${_slotSpoken(slots[2])} ');
      }
    }
    return b.toString();
  }

  /// An empty slot is read as "empty" (it is a placeholder).
  static String _slotSpoken(SlotNode s) => s.children.isEmpty ? 'empty' : _spoken(s.children);

  // -- Editing ------------------------------------------------------------------------------------------------------
  void _touch({bool content = true}) {
    if (content) _linear = null;
    version = _versionCounter++;
  }

  /// Puts the caret at ([p], [o]) when that place exists. Returns whether it moved.
  bool setCaret(List<int> p, int o) {
    var cur = root;
    GroupNode? last;
    for (final idx in p) {
      if (idx < 0 || idx >= cur.length) return false;
      final n = cur[idx];
      if (n is! GroupNode) return false;
      last = n;
      cur = n.children;
    }
    // the list of a structure holds its slots; the caret stands inside a slot, never between slots
    if (last is StructNode) return false;
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

  /// Inserts one finished node at the caret; the caret ends up after it.
  void insertNode(Node n) {
    current.insert(offset, n);
    offset++;
    _touch();
  }

  /// Opens a superscript (or subscript) at the caret with the caret inside. False when already [kMaxNesting] deep.
  bool insertGroup({required bool sup}) {
    if (scriptDepth >= kMaxNesting) return false;
    final cur = current;
    final idx = offset;
    cur.insert(idx, sup ? SupNode() : SubNode());
    path.add(idx);
    offset = 0;
    _touch();
    return true;
  }

  /// Opens [node] at the caret with the caret in its slot [focus]. False when structures are already
  /// [kMaxStructDepth] deep.
  bool insertStruct(StructNode node, {int focus = 0}) {
    if (structDepth >= kMaxStructDepth) return false;
    final idx = offset;
    current.insert(idx, node);
    path
      ..add(idx)
      ..add(focus);
    offset = 0;
    _touch();
    return true;
  }

  /// End (exclusive) of what "INS then a function key" takes as the argument: everything to the right of the caret up to
  /// the first `(` or the first function name (letters followed by `(`), as the manual describes (Using Values and
  /// Expressions as Arguments).
  int get wrapEnd {
    final cur = current;
    var i = offset;
    while (i < cur.length) {
      final n = cur[i];
      if (n is CharNode) {
        if (n.ch == '(') break;
        // a run of letters that ends in `(` is a function name
        var j = i;
        while (j < cur.length && cur[j] is CharNode && _isLetterChar((cur[j] as CharNode).ch)) {
          j++;
        }
        if (j > i && j < cur.length && cur[j] is CharNode && (cur[j] as CharNode).ch == '(') break;
        if (j > i) {
          i = j;
          continue;
        }
      }
      i++;
    }
    return i;
  }

  static bool _isLetterChar(String c) {
    final u = c.codeUnitAt(0);
    return (u >= 0x41 && u <= 0x5A) || (u >= 0x61 && u <= 0x7A);
  }

  /// "INS" wrap: puts the value or expression to the right of the caret into slot [argSlot] of [node] and leaves the
  /// caret at the end of that slot. With nothing to the right it is the same as [insertStruct]. False when too deep.
  bool insertStructWrapping(StructNode node, {required int argSlot}) {
    if (structDepth >= kMaxStructDepth) return false;
    final cur = current;
    final end = wrapEnd;
    if (end <= offset) return insertStruct(node, focus: 0);
    final taken = cur.sublist(offset, end);
    cur.removeRange(offset, end);
    node.slots[argSlot].children.addAll(taken);
    final idx = offset;
    cur.insert(idx, node);
    path
      ..add(idx)
      ..add(argSlot);
    offset = taken.length;
    _touch();
    return true;
  }

  void _enterFirst(int idx) {
    final g = current[idx] as GroupNode;
    path.add(idx);
    if (g is StructNode) path.add(0);
    offset = 0;
  }

  void _enterLast(int idx) {
    final g = current[idx] as GroupNode;
    path.add(idx);
    if (g is StructNode) {
      path.add(g.slots.length - 1);
      offset = g.slots.last.children.length;
    } else {
      offset = g.children.length;
    }
  }

  /// Right arrow: step over a character, step into a group or structure, go on to the next slot at the end of a slot,
  /// or leave the group at its end. False at the very end.
  bool moveRight() {
    final cur = current;
    if (offset < cur.length) {
      final n = cur[offset];
      if (n is GroupNode) {
        _enterFirst(offset);
      } else {
        offset++;
      }
      _touch(content: false);
      return true;
    }
    final owner = slotOwner;
    if (owner != null && owner.$2 < owner.$1.slots.length - 1) {
      path.last = owner.$2 + 1;
      offset = 0;
      _touch(content: false);
      return true;
    }
    if (path.isNotEmpty) return exitGroup();
    return false;
  }

  /// Left arrow: step back over a character, into a group or structure from its end, to the previous slot at the start
  /// of a slot, or out of a group at its start.
  bool moveLeft() {
    final cur = current;
    if (offset > 0) {
      final n = cur[offset - 1];
      if (n is GroupNode) {
        _enterLast(offset - 1);
      } else {
        offset--;
      }
      _touch(content: false);
      return true;
    }
    final owner = slotOwner;
    if (owner != null) {
      if (owner.$2 > 0) {
        path.last = owner.$2 - 1;
        offset = owner.$1.slots[owner.$2 - 1].children.length;
      } else {
        path.removeLast();
        offset = path.removeLast();
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

  /// The exit key: leaves the group or structure the caret is in and lands just after it, wherever the caret was inside.
  bool exitGroup() {
    if (path.isEmpty) return false;
    if (inSlot) path.removeLast();
    offset = path.removeLast() + 1;
    _touch(content: false);
    return true;
  }

  /// Down arrow: from the numerator to the denominator of the nearest fraction around the caret (the manual's replay
  /// pad). False when there is no fraction to go down in.
  bool moveDown() => _moveVertical(down: true);

  /// Up arrow: from the denominator back to the numerator.
  bool moveUp() => _moveVertical(down: false);

  bool _moveVertical({required bool down}) {
    final c = chain;
    for (var k = c.length - 1; k >= 1; k--) {
      final owner = c[k - 1];
      final slot = c[k];
      if (owner is! StructNode || slot is! SlotNode) continue;
      // identity, not ==: two slots with the same text are equal as trees (the whole part and numerator of 1 1/2)
      final here = owner.slots.indexWhere((s) => identical(s, slot));
      final int? target = switch (owner) {
        FracNode() => down ? (here == 0 ? 1 : null) : (here == 1 ? 0 : null),
        MixedFracNode() => down ? (here == 1 ? 2 : null) : (here == 2 ? 1 : null),
        _ => null,
      };
      if (target == null) continue;
      // keep the caret where it is horizontally as far as the target allows: same offset when the caret is directly in
      // the slot, the start of the slot when it was deeper inside
      final direct = k == c.length - 1;
      final len = owner.slots[target].children.length;
      path.removeRange(k, path.length);
      path.add(target);
      offset = direct ? math.min(offset, len) : 0;
      _touch(content: false);
      return true;
    }
    return false;
  }

  /// Backspace. [tokens] are the multi-character names removed as one piece (`sin(`, `y=`...), tested in order.
  /// - after a character: removes it (or the token that ends there)
  /// - after an empty group or empty structure: removes it; after one with content: steps into it
  /// - at the start of a group: removes it when empty, otherwise steps out in front of it
  /// - at the start of a slot: goes to the end of the slot before it
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
        // `log₂(` / `log_b(` are the characters l o g, the lowered base and the parenthesis: one piece
        if (cut == 1 && n.ch == '(' && offset >= 5) {
          final base = cur[offset - 2];
          if (base is SubNode &&
              base.bare &&
              cur[offset - 3] == const CharNode('g') &&
              cur[offset - 4] == const CharNode('o') &&
              cur[offset - 5] == const CharNode('l')) {
            cut = 5;
          }
        }
        cur.removeRange(offset - cut, offset);
        offset -= cut;
      } else if (n is StructNode) {
        if (n.allEmpty) {
          cur.removeAt(offset - 1);
          offset--;
        } else {
          _enterLast(offset - 1);
          _touch(content: false);
          return;
        }
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
    final owner = slotOwner;
    if (owner != null) {
      final (struct, slotIdx) = owner;
      if (slotIdx > 0) {
        path.last = slotIdx - 1;
        offset = struct.slots[slotIdx - 1].children.length;
        _touch(content: false);
        return;
      }
      path.removeLast();
      final idx = path.removeLast();
      if (struct.allEmpty) current.removeAt(idx);
      offset = idx;
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
