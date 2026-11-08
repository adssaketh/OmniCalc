import 'linear.dart';
import 'nodes.dart';

/// The structures of the natural display written in the Casio linear syntax, as the guide's examples and the history use:
/// `∫(f,a,b)`, `Σ(f,a,b)`, `∏(f,a,b)` and `d/dx(f,x)`. [parseLinear] keeps these as plain characters (that is what the
/// engine reads); this reads them as the boxes the keys draw, so an example loads the way it looks on the display.
///
/// A head that does not close, or has the wrong number of parts, stays plain text. [serializeNodes] of the result is the
/// same string (apart from spaces round the commas, which are dropped).
List<Node> nodesFromExample(String s) {
  final out = <Node>[];
  final plain = StringBuffer();

  void flush() {
    if (plain.isEmpty) return;
    out.addAll(parseLinear(plain.toString()).nodes);
    plain.clear();
  }

  var i = 0;
  while (i < s.length) {
    final head = _heads.where((h) => s.startsWith(h.text, i)).firstOrNull;
    if (head != null) {
      final open = i + head.text.length - 1;
      final close = _closing(s, open);
      if (close > 0) {
        final parts = _splitTop(s.substring(open + 1, close));
        if (parts.length == head.parts) {
          flush();
          out.add(head.make([for (final p in parts) SlotNode(nodesFromExample(p.trim()))]));
          i = close + 1;
          continue;
        }
      }
    }
    plain.write(s[i]);
    i++;
  }
  flush();
  return out;
}

class _Head {
  const _Head(this.text, this.parts, this.make);

  final String text;
  final int parts;
  final Node Function(List<SlotNode>) make;
}

final List<_Head> _heads = [
  _Head('∫(', 3, IntegralNode.new),
  _Head('Σ(', 3, SigmaNode.new),
  _Head('∏(', 3, ProdNode.new),
  _Head('d/dx(', 2, DerivNode.new),
];

/// Index of the `)` that closes the `(` at [open], or -1.
int _closing(String s, int open) {
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    if (s[i] == '(') depth++;
    if (s[i] == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

/// [s] cut at the commas that are not inside brackets.
List<String> _splitTop(String s) {
  final parts = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == '(') depth++;
    if (c == ')') depth--;
    if (c == ',' && depth == 0) {
      parts.add(s.substring(start, i));
      start = i + 1;
    }
  }
  parts.add(s.substring(start));
  return parts;
}
