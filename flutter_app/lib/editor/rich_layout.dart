import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'nodes.dart';

/// Size of a group's text relative to the base size, by nesting level (Part 2: about 0.62x for the first level, each
/// further level smaller, never below about 0.45x).
double levelScale(int level) {
  if (level <= 0) return 1;
  return math.max(0.45, 0.62 * math.pow(0.8, level - 1).toDouble());
}

/// How far a superscript is raised and a subscript lowered, in em of the text it is attached to.
const double kSupRaiseEm = 0.38;
const double kSubDropEm = 0.25;

/// Width of an empty group, in em of its own size, so the caret has somewhere to stand.
const double kEmptyGroupEm = 0.35;

/// Style of the text at a given font size (the display's `appText(...)` with the size filled in).
typedef StyleForSize = TextStyle Function(double size);

/// A piece of a laid-out row: a run of characters, or a group with its own row.
sealed class Piece {
  Piece(this.x);

  /// Distance from the row's left edge.
  final double x;
}

final class RunPiece extends Piece {
  RunPiece(super.x, this.painter, this.start, this.count, this.baseline);

  final TextPainter painter;

  /// Index of the first node of the run in the row's node list, and how many nodes it covers.
  final int start;
  final int count;

  /// Distance from the painter's top to its alphabetic baseline.
  final double baseline;
}

final class GroupPiece extends Piece {
  GroupPiece(super.x, this.index, this.row, this.dy);

  /// Index of the group's node in the row's node list.
  final int index;
  final RowLayout row;

  /// How far the group's baseline is above the row's baseline (negative = below).
  final double dy;
}

/// One list of nodes laid out on a single baseline.
class RowLayout {
  RowLayout({
    required this.pieces,
    required this.width,
    required this.ascent,
    required this.descent,
    required this.size,
    required this.count,
  });

  final List<Piece> pieces;
  final double width;

  /// Above and below the baseline, including raised and lowered groups.
  final double ascent;
  final double descent;

  /// Font size of this row's own text.
  final double size;

  /// Number of nodes in the list.
  final int count;

  double get height => ascent + descent;

  /// x of the gap [offset] (0 = before the first node).
  double xAtOffset(int offset) {
    for (final p in pieces) {
      switch (p) {
        case RunPiece():
          if (offset >= p.start && offset <= p.start + p.count) {
            return p.x + p.painter.getOffsetForCaret(TextPosition(offset: offset - p.start), Rect.zero).dx;
          }
        case GroupPiece():
          if (offset == p.index) return p.x;
          if (offset == p.index + 1) return p.x + p.row.width;
      }
    }
    return 0;
  }

  GroupPiece? groupAt(int index) {
    for (final p in pieces) {
      if (p is GroupPiece && p.index == index) return p;
    }
    return null;
  }
}

/// Lays out [nodes] with base font size [baseSize] at nesting [level] (0 = the root list).
RowLayout layoutRow(
  List<Node> nodes, {
  required double baseSize,
  required StyleForSize styleFor,
  required TextDirection textDirection,
  int level = 0,
}) {
  final size = baseSize * levelScale(level);
  final pieces = <Piece>[];
  var x = 0.0;
  var ascent = 0.0;
  var descent = 0.0;
  var any = false;

  var i = 0;
  while (i < nodes.length) {
    final n = nodes[i];
    if (n is CharNode) {
      final b = StringBuffer();
      var j = i;
      while (j < nodes.length && nodes[j] is CharNode) {
        b.write((nodes[j] as CharNode).ch);
        j++;
      }
      final painter = TextPainter(
        text: TextSpan(text: b.toString(), style: styleFor(size)),
        textDirection: textDirection,
        maxLines: 1,
      )..layout();
      final baseline = painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      pieces.add(RunPiece(x, painter, i, j - i, baseline));
      x += painter.width;
      ascent = math.max(ascent, baseline);
      descent = math.max(descent, painter.height - baseline);
      any = true;
      i = j;
    } else {
      final g = n as GroupNode;
      final child = layoutRow(
        g.children,
        baseSize: baseSize,
        styleFor: styleFor,
        textDirection: textDirection,
        level: level + 1,
      );
      final dy = g is SupNode ? kSupRaiseEm * size : -kSubDropEm * size;
      pieces.add(GroupPiece(x, i, child, dy));
      x += child.width;
      ascent = math.max(ascent, child.ascent + dy);
      descent = math.max(descent, child.descent - dy);
      any = true;
      i++;
    }
  }

  if (!any) {
    // an empty list still has a line height (and the caret needs a place to stand)
    final painter = TextPainter(
      text: TextSpan(text: '0', style: styleFor(size)),
      textDirection: textDirection,
      maxLines: 1,
    )..layout();
    final baseline = painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    ascent = baseline;
    descent = painter.height - baseline;
    x = level == 0 ? 0 : kEmptyGroupEm * size;
  }

  return RowLayout(pieces: pieces, width: x, ascent: ascent, descent: descent, size: size, count: nodes.length);
}

/// Paints [row] with its top-left corner at [origin].
void paintRow(Canvas canvas, RowLayout row, Offset origin) {
  final baselineY = origin.dy + row.ascent;
  _paintAt(canvas, row, origin.dx, baselineY);
}

void _paintAt(Canvas canvas, RowLayout row, double ox, double baselineY) {
  for (final p in row.pieces) {
    switch (p) {
      case RunPiece():
        p.painter.paint(canvas, Offset(ox + p.x, baselineY - p.baseline));
      case GroupPiece():
        _paintAt(canvas, p.row, ox + p.x, baselineY - p.dy);
    }
  }
}

/// Where the caret goes: x from the row's left edge, the baseline y from its top, and the font size of that row.
class CaretGeometry {
  const CaretGeometry(this.x, this.baselineY, this.size);

  final double x;
  final double baselineY;
  final double size;

  /// The caret bar: a little taller than the text of its own row.
  Rect rect({double width = 2}) =>
      Rect.fromLTWH(x - width / 2, baselineY - size * 0.82, width, size * 1.04);
}

CaretGeometry caretGeometry(RowLayout row, List<int> path, int offset) {
  var current = row;
  var x = 0.0;
  var baselineY = row.ascent;
  for (final idx in path) {
    final g = current.groupAt(idx);
    if (g == null) break;
    x += g.x;
    baselineY -= g.dy;
    current = g.row;
  }
  return CaretGeometry(x + current.xAtOffset(offset), baselineY, current.size);
}

/// Result of a tap: the caret position it means.
class CaretHit {
  const CaretHit(this.path, this.offset);

  final List<int> path;
  final int offset;
}

/// The caret position for a tap at ([dx], [dy]) measured from the row's top-left corner: inside a group when the tap
/// lands on it, otherwise the nearest gap of the row it landed in.
CaretHit hitTest(RowLayout row, double dx, double dy) => _hit(row, dx, dy, row.ascent, const []);

CaretHit _hit(RowLayout row, double dx, double dy, double baselineY, List<int> path) {
  for (final p in row.pieces) {
    if (p is! GroupPiece) continue;
    if (dx >= p.x && dx <= p.x + p.row.width) {
      final top = baselineY - p.dy - p.row.ascent;
      final bottom = baselineY - p.dy + p.row.descent;
      if (dy >= top && dy <= bottom) {
        return _hit(p.row, dx - p.x, dy, baselineY - p.dy, [...path, p.index]);
      }
    }
  }
  var best = 0;
  var bestDist = double.infinity;
  for (var o = 0; o <= row.count; o++) {
    final d = (row.xAtOffset(o) - dx).abs();
    if (d < bestDist) {
      bestDist = d;
      best = o;
    }
  }
  return CaretHit(path, best);
}
