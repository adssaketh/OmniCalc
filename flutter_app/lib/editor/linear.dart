import 'nodes.dart';

/// Conversion between the linear string the engine reads and the node tree of the editor.
///
/// The one rule that matters: `serializeNodes(parseLinear(s).nodes) == s` for EVERY string `s`. The engine therefore
/// receives exactly the text it received before the editor existed, and every old expression (history, deep links,
/// golden vectors) loads without changing a character. Trees typed with the editor serialize to the same dialect:
/// a superscript becomes `^x` when its content is a plain number or word, `^(...)` otherwise.

/// What [parseLinear] found: the nodes and where the caret belongs after a string was typed in full.
///
/// The caret sits inside the last group when that group is unfinished (empty, or with an unclosed parenthesis), so
/// the next digit goes into the exponent: `2^` then `3` makes `2^3` with the 3 raised. After a finished group such as
/// `x^2` the caret is after it.
class LinearParse {
  const LinearParse(this.nodes, this.path, this.offset);

  final List<Node> nodes;

  /// Index of the container to enter at each level, from the root (empty = caret in the root list).
  final List<int> path;

  /// Caret position inside the list that [path] leads to.
  final int offset;
}

bool _isDigitOrDot(int c) => (c >= 0x30 && c <= 0x39) || c == 0x2E;
bool _isLetter(int c) => (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);

bool _allMatch(String s, bool Function(int) test) {
  if (s.isEmpty) return false;
  for (final u in s.codeUnits) {
    if (!test(u)) return false;
  }
  return true;
}

/// Index just after the `)` that closes the `(` at [open], or -1 when it is never closed.
int _matchParen(String s, int open) {
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    final u = s.codeUnitAt(i);
    if (u == 0x28) {
      depth++;
    } else if (u == 0x29) {
      depth--;
      if (depth == 0) return i + 1;
    }
  }
  return -1;
}

int _letterRunEnd(String s, int from) {
  var i = from;
  while (i < s.length && _isLetter(s.codeUnitAt(i))) {
    i++;
  }
  return i;
}

/// End (exclusive) of the operand that follows `^` or `_` at [p]: a number, a word, a word with a call `sin(x)`, or a
/// parenthesised group. Nothing (returns [p]) when the next character starts none of these, e.g. `^-3` or `^!`.
int _operandEnd(String s, int p) {
  if (p >= s.length) return p;
  final c = s.codeUnitAt(p);
  if (c == 0x28) {
    final m = _matchParen(s, p);
    return m < 0 ? s.length : m;
  }
  if (_isDigitOrDot(c)) {
    var i = p;
    while (i < s.length && _isDigitOrDot(s.codeUnitAt(i))) {
      i++;
    }
    return i;
  }
  if (s.startsWith('log2(', p)) {
    final m = _matchParen(s, p + 4);
    return m < 0 ? s.length : m;
  }
  if (_isLetter(c)) {
    final e = _letterRunEnd(s, p);
    if (e < s.length && s.codeUnitAt(e) == 0x28) {
      final m = _matchParen(s, e);
      return m < 0 ? s.length : m;
    }
    return e;
  }
  return p;
}

bool _unbalanced(String s) {
  var depth = 0;
  for (final u in s.codeUnits) {
    if (u == 0x28) depth++;
    if (u == 0x29) depth--;
  }
  return depth > 0;
}

/// Parses [s] into nodes. Total: any string parses, none is rejected or changed.
LinearParse parseLinear(String s) {
  final nodes = <Node>[];
  final run = StringBuffer();
  void flush() {
    for (final u in run.toString().codeUnits) {
      nodes.add(CharNode(String.fromCharCode(u)));
    }
    run.clear();
  }

  LinearParse? lastInner;
  String lastContent = '';
  var lastIsGroupAtEnd = false;

  var i = 0;
  while (i < s.length) {
    final ch = s[i];
    if (ch == 'l' &&
        (s.startsWith('log2(', i) || s.startsWith('logb(', i)) &&
        (i == 0 || !_isLetter(s.codeUnitAt(i - 1)))) {
      // log base 2 / base b: the base is a lowered group that is written without `_`
      run.write('log');
      flush();
      nodes.add(SubNode([CharNode(s[i + 3])], true));
      i += 4;
      lastIsGroupAtEnd = false;
    } else if (ch == '^' || ch == '_') {
      flush();
      final end = _operandEnd(s, i + 1);
      lastContent = s.substring(i + 1, end);
      lastInner = parseLinear(lastContent);
      nodes.add(ch == '^' ? SupNode(lastInner.nodes) : SubNode(lastInner.nodes));
      i = end;
      lastIsGroupAtEnd = i == s.length;
    } else {
      run.write(ch);
      i++;
      lastIsGroupAtEnd = false;
    }
  }
  flush();

  if (lastIsGroupAtEnd && lastInner != null && (lastContent.isEmpty || _unbalanced(lastContent))) {
    return LinearParse(nodes, [nodes.length - 1, ...lastInner.path], lastInner.offset);
  }
  return LinearParse(nodes, const [], nodes.length);
}

/// The text of the operand of a group: bare when it is a number, a word or already one parenthesised unit.
String _operand(String c) {
  if (c.isEmpty) return '';
  if (_allMatch(c, _isDigitOrDot) || _allMatch(c, _isLetter)) return c;
  if (c.codeUnitAt(0) == 0x28) {
    final m = _matchParen(c, 0);
    return (m < 0 || m == c.length) ? c : '($c)';
  }
  if (c.startsWith('log2(')) {
    final m = _matchParen(c, 4);
    if (m < 0 || m == c.length) return c;
  }
  final e = _letterRunEnd(c, 0);
  if (e > 0 && e < c.length && c.codeUnitAt(e) == 0x28) {
    final m = _matchParen(c, e);
    if (m < 0 || m == c.length) return c;
  }
  return '($c)';
}

/// Number of `(` left open in [s] (0 when balanced or over-closed).
int _openCount(String s) {
  var depth = 0;
  for (final u in s.codeUnits) {
    if (u == 0x28) depth++;
    if (u == 0x29) depth--;
  }
  return depth > 0 ? depth : 0;
}

/// The operand text of a group that is followed by [next] in its list. A bare operand would run into the next
/// character when read back (`^2` then `3` reads as `^23`), and an unclosed `(` would swallow what follows, so in those
/// cases the operand is parenthesised or closed. Text that [parseLinear] produced never needs this, which is why
/// the round trip stays exact.
String _operandBefore(String content, Node? next) {
  var op = _operand(content);
  if (next == null) return op;
  final open = _openCount(content);
  if (open > 0) return op + ')' * open;
  if (next is CharNode && op == content && content.isNotEmpty) {
    final c = next.ch.codeUnitAt(0);
    final merges = (_allMatch(content, _isDigitOrDot) && _isDigitOrDot(c)) ||
        (_allMatch(content, _isLetter) && (_isLetter(c) || c == 0x28));
    if (merges) return '($content)';
  }
  return op;
}

/// A slot's text for the engine: what is typed in it, with any `(` left open closed so it cannot swallow what follows
/// the structure.
String _slotText(SlotNode slot) {
  final t = serializeNodes(slot.children);
  final open = _openCount(t);
  return open > 0 ? t + ')' * open : t;
}

/// The legacy-engine text of a structure (Phase 8a). The Casio engine of Phase 8b reads the tree itself; until then every
/// structure is written in the dialect the ported OmniCalc evaluator already understands, so results do not change:
/// fraction `((a)÷(b))`, mixed fraction `((w)+((n)÷(d)))`, `sqrt(x)`, `root(n,x)`, `abs(x)`, `logb(base,x)`.
String _structText(StructNode n) {
  final t = [for (final s in n.slots) _slotText(s)];
  return switch (n) {
    FracNode() => '((${t[0]})÷(${t[1]}))',
    MixedFracNode() => '((${t[0]})+((${t[1]})÷(${t[2]})))',
    SqrtNode() => 'sqrt(${t[0]})',
    RootNode() => 'root(${t[0]},${t[1]})',
    AbsNode() => 'abs(${t[0]})',
    LogBaseNode() => 'logb(${t[0]},${t[1]})',
    IntegralNode() => '∫(${t[0]},${t[1]},${t[2]})',
    DerivNode() => 'd/dx(${t[0]},${t[1]})',
    SigmaNode() => 'Σ(${t[0]},${t[1]},${t[2]})',
    ProdNode() => '∏(${t[0]},${t[1]},${t[2]})',
  };
}

/// A structure written next to something it would be multiplied by gets an explicit `×` (`2` then a fraction is
/// `2×((a)÷(b))`), so the legacy engine does not depend on implicit multiplication around `sqrt(`, `root(`, ...
bool _endsOperand(String written) {
  if (written.isEmpty) return false;
  final c = written.codeUnitAt(written.length - 1);
  return _isDigitOrDot(c) || _isLetter(c) || c == 0x29 || c == 0x21 || c == 0x25 || c == 0x3C0 /* π */;
}

bool _startsOperand(String ch) {
  final c = ch.codeUnitAt(0);
  return _isDigitOrDot(c) || _isLetter(c) || c == 0x28 || c == 0x3C0 || c == 0x221A /* √ */;
}

/// The engine string of [nodes] (see the library comment).
String serializeNodes(List<Node> nodes) {
  final b = StringBuffer();
  for (var i = 0; i < nodes.length; i++) {
    final next = i + 1 < nodes.length ? nodes[i + 1] : null;
    if (nodes[i] is StructNode && _endsOperand(b.toString())) b.write('×');
    switch (nodes[i]) {
      case CharNode(:final ch):
        b.write(ch);
      case SupNode(:final children):
        b
          ..write('^')
          ..write(_operandBefore(serializeNodes(children), next));
      case SubNode(:final children, :final bare):
        if (bare) {
          b.write(serializeNodes(children));
        } else {
          b
            ..write('_')
            ..write(_operandBefore(serializeNodes(children), next));
        }
      case SlotNode(:final children):
        b.write(serializeNodes(children));
      case StructNode():
        b.write(_structText(nodes[i] as StructNode));
        if (next is CharNode && _startsOperand(next.ch)) b.write('×');
    }
  }
  return b.toString();
}

const String _supChars = '⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻';
const String _subChars = '₀₁₂₃₄₅₆₇₈₉₊₋';
const String _plain = '0123456789+-';

/// Pasted text: runs of Unicode superscript (`x²`, `x⁻¹`) or subscript (`H₂O`) characters become `^` / `_` groups,
/// the dialect [parseLinear] reads. Anything else is left alone. Used for paste only, never for stored strings (those
/// must round-trip unchanged).
String normalizeUnicodeScripts(String s) {
  final b = StringBuffer();
  var i = 0;
  while (i < s.length) {
    final ch = s[i];
    final isSup = _supChars.contains(ch);
    final isSub = _subChars.contains(ch);
    if (!isSup && !isSub) {
      b.write(ch);
      i++;
      continue;
    }
    final table = isSup ? _supChars : _subChars;
    final mapped = StringBuffer();
    while (i < s.length && table.contains(s[i])) {
      mapped.write(_plain[table.indexOf(s[i])]);
      i++;
    }
    final m = mapped.toString();
    b
      ..write(isSup ? '^' : '_')
      ..write(_allMatch(m, _isDigitOrDot) ? m : '($m)');
  }
  return b.toString();
}
