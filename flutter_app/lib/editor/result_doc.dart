import 'expr_doc.dart';
import 'nodes.dart';

/// Phase 8c (row C01): the document an answer line draws.
///
/// The engine writes a fraction result as text with the linear fraction mark: `7⌟6`, and `1⌟1⌟6` for a mixed fraction
/// (the form Linear Display shows). With Natural Display (MthIO-MathO) the real unit draws it stacked, so [stacked]
/// turns each such group into a [FracNode] or [MixedFracNode]. Everything else (signs, √, π, `R`, `;`) stays as text.
/// With [stacked] false, or when the text has no mark, this is [ExprDoc.plain] exactly as before.
ExprDoc resultDocFor(String text, {required bool stacked}) {
  if (!stacked || !text.contains('⌟')) return ExprDoc.plain(text);
  final nodes = <Node>[];
  var last = 0;
  for (final m in _fraction.allMatches(text)) {
    _addChars(nodes, text.substring(last, m.start));
    if (m.group(3) != null) {
      nodes.add(MixedFracNode([_slot(m.group(1)!), _slot(m.group(2)!), _slot(m.group(3)!)]));
    } else {
      nodes.add(FracNode([_slot(m.group(4)!), _slot(m.group(5)!)]));
    }
    last = m.end;
  }
  _addChars(nodes, text.substring(last));
  return ExprDoc.fromNodes(nodes);
}

// a⌟b⌟c (mixed) must be tried before a⌟b
final RegExp _fraction = RegExp(r'(\d+)⌟(\d+)⌟(\d+)|(\d+)⌟(\d+)');

SlotNode _slot(String digits) => SlotNode([for (final u in digits.codeUnits) CharNode(String.fromCharCode(u))]);

void _addChars(List<Node> out, String s) {
  for (final u in s.codeUnits) {
    out.add(CharNode(String.fromCharCode(u)));
  }
}
