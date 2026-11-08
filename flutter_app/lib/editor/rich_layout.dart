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

/// Hollow placeholder box of an empty slot, in em of its row's size: width, height and how far its top is above the
/// baseline. The caret in an empty slot is the same box, filled (Part 9, video frame 3).
const double kPlaceholderWidthEm = 0.56;
const double kPlaceholderHeightEm = 0.78;
const double kPlaceholderTopEm = 0.74;

/// Big operators (∫ Σ ∏) are drawn as shapes, not as a font glyph, so every device gets the same size and the limit boxes
/// can be placed from the real edges of the sign. Height of the sign and the height of its centre above the baseline, in em
/// of the row's size; the centre is the centre of an empty body box, so the sign and the box beside it line up. [kBigOpGapEm]
/// is the clear space between the sign and a limit box above or below it.
const double kBigOpHeightEm = 1.0;
const double kBigOpCenterEm = 0.35;
const double kBigOpGapEm = 0.10;

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

/// Where one slot of a structure sits: its row, the distance from the structure's left edge, and how far its baseline is
/// above the structure's baseline (negative = below).
final class SlotPlace {
  const SlotPlace(this.row, this.dx, this.dy);

  final RowLayout row;
  final double dx;
  final double dy;
}

/// Draws what a structure adds around its slots (fraction bar, radical sign, bars, the word `log`). [ox] is the
/// structure's left edge, [baselineY] its baseline.
typedef StructDecoration = void Function(Canvas canvas, double ox, double baselineY);

/// A fraction, root, absolute value or log with a base: slots placed by hand plus a decoration.
final class StructPiece extends Piece {
  StructPiece(
    super.x,
    this.index, {
    required this.width,
    required this.ascent,
    required this.descent,
    required this.slots,
    required this.decorate,
  });

  /// Index of the structure's node in the row's node list.
  final int index;
  final double width;
  final double ascent;
  final double descent;
  final List<SlotPlace> slots;
  final StructDecoration decorate;
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
    this.emptyBox = false,
    this.boxColor,
    double? visAscent,
    double? visDescent,
  })  : visAscent = visAscent ?? ascent,
        visDescent = visDescent ?? descent;

  final List<Piece> pieces;
  final double width;

  /// Above and below the baseline, including raised and lowered groups.
  final double ascent;
  final double descent;

  /// What can be seen above and below the baseline: an empty slot is its hollow box, plain text is as tall as its digits
  /// and capitals (not the font's full line box); anything with groups or structures is its real [ascent] and [descent].
  /// Limit boxes are spaced from these, so the gap above a sign equals the gap below it.
  final double visAscent;
  final double visDescent;

  /// Font size of this row's own text.
  final double size;

  /// Number of nodes in the list.
  final int count;

  /// An empty slot: drawn as a hollow box (a placeholder).
  final bool emptyBox;
  final Color? boxColor;

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
        case StructPiece():
          if (offset == p.index) return p.x;
          if (offset == p.index + 1) return p.x + p.width;
      }
    }
    return 0;
  }

  /// The piece of the node at [index]: a group or a structure.
  Piece? groupAt(int index) {
    for (final p in pieces) {
      if (p is GroupPiece && p.index == index) return p;
      if (p is StructPiece && p.index == index) return p;
    }
    return null;
  }

  double get boxWidth => kPlaceholderWidthEm * size;
}

/// Lays out [nodes] with base font size [baseSize] at nesting [level] (0 = the root list).
RowLayout layoutRow(
  List<Node> nodes, {
  required double baseSize,
  required StyleForSize styleFor,
  required TextDirection textDirection,
  int level = 0,
  bool slot = false,
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
    } else if (n is StructNode) {
      final piece = _layoutStruct(
        n,
        x,
        i,
        size: size,
        baseSize: baseSize,
        level: level,
        styleFor: styleFor,
        textDirection: textDirection,
      );
      pieces.add(piece);
      x += piece.width;
      ascent = math.max(ascent, piece.ascent);
      descent = math.max(descent, piece.descent);
      any = true;
      i++;
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
    x = slot ? kPlaceholderWidthEm * size : (level == 0 ? 0 : kEmptyGroupEm * size);
  }

  // what is visible: the hollow box of an empty slot, the height of digits and capitals for plain text, otherwise the lot
  final plain = any && pieces.every((p) => p is RunPiece);
  final double visAscent;
  final double visDescent;
  if (!any) {
    visAscent = kPlaceholderTopEm * size;
    visDescent = (kPlaceholderHeightEm - kPlaceholderTopEm) * size;
  } else if (plain) {
    visAscent = math.min(ascent, 0.78 * size);
    visDescent = math.min(descent, 0.04 * size);
  } else {
    visAscent = ascent;
    visDescent = descent;
  }

  return RowLayout(
    pieces: pieces,
    width: x,
    ascent: ascent,
    descent: descent,
    size: size,
    count: nodes.length,
    emptyBox: slot && !any,
    boxColor: slot && !any ? styleFor(size).color : null,
    visAscent: visAscent,
    visDescent: visDescent,
  );
}

enum BigOp { integral, sigma, prod }

/// Width of each sign in em of its height.
double bigOpWidthEm(BigOp op) => switch (op) {
      BigOp.integral => 0.52,
      BigOp.sigma => 0.78,
      BigOp.prod => 0.84,
    };

/// Draws a big operator filling [box] (its exact ink area) in [color].
void paintBigOp(Canvas canvas, BigOp op, Rect box, Color color) {
  final w = box.width;
  final h = box.height;
  final fill = Paint()
    ..color = color
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;
  Offset p(double fx, double fy) => Offset(box.left + fx * w, box.top + fy * h);
  switch (op) {
    case BigOp.prod:
      // a bar across the top with two straight legs under it, the bar a little wider than the legs
      final bar = 0.13 * h;
      final leg = 0.15 * h;
      final inset = 0.12 * w;
      canvas.drawRect(Rect.fromLTWH(box.left, box.top, w, bar), fill);
      canvas.drawRect(Rect.fromLTWH(box.left + inset, box.top, leg, h), fill);
      canvas.drawRect(Rect.fromLTWH(box.right - inset - leg, box.top, leg, h), fill);
    case BigOp.sigma:
      // top bar, two diagonals meeting left of the middle, bottom bar; the bars turn a little towards the inside at the right
      final t = 0.11 * h;
      final path = Path()
        ..moveTo(box.left + 0.02 * w, box.top)
        ..lineTo(box.right, box.top)
        ..lineTo(box.right, box.top + 0.20 * h)
        ..lineTo(box.right - t * 0.9, box.top + 0.20 * h)
        ..lineTo(box.right - t * 0.9, box.top + t)
        ..lineTo(box.left + 0.20 * w, box.top + t)
        ..lineTo(p(0.60, 0.5).dx, p(0.60, 0.5).dy)
        ..lineTo(box.left + 0.20 * w, box.bottom - t)
        ..lineTo(box.right - t * 0.9, box.bottom - t)
        ..lineTo(box.right - t * 0.9, box.bottom - 0.20 * h)
        ..lineTo(box.right, box.bottom - 0.20 * h)
        ..lineTo(box.right, box.bottom)
        ..lineTo(box.left + 0.02 * w, box.bottom)
        ..lineTo(p(0.48, 0.5).dx, p(0.48, 0.5).dy)
        ..close();
      canvas.drawPath(path, fill);
    case BigOp.integral:
      // one long slanted S: a ball at each end, a thin stroke between them
      final sw = 0.075 * h;
      final r = 0.065 * h;
      final stroke = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;
      final start = p(0.16, 0.93);
      final end = p(0.84, 0.07);
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(p(0.40, 1.04).dx, p(0.40, 1.04).dy, p(0.50, 0.86).dx, p(0.50, 0.86).dy, p(0.50, 0.50).dx, p(0.50, 0.50).dy)
        ..cubicTo(p(0.50, 0.14).dx, p(0.50, 0.14).dy, p(0.60, -0.04).dx, p(0.60, -0.04).dy, end.dx, end.dy);
      canvas.drawPath(path, stroke);
      canvas.drawCircle(start, r, fill);
      canvas.drawCircle(end, r, fill);
  }
}

/// The radical sign and its overbar as one open path: a small tick, down to the bottom, up to the top, then across.
/// [x0] is the left edge, [top] and [bottom] are y values (canvas coordinates), [signWidth] the width of the sign and
/// [right] the end of the bar.
Path _radicalPath(double x0, double top, double bottom, double signWidth, double right, double size) {
  final h = bottom - top;
  return Path()
    ..moveTo(x0 + 0.03 * size, top + 0.58 * h)
    ..lineTo(x0 + 0.13 * size, top + 0.52 * h)
    ..lineTo(x0 + 0.30 * size, bottom)
    ..lineTo(x0 + signWidth, top)
    ..lineTo(right, top);
}

Paint _strokePaint(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

StructPiece _layoutStruct(
  StructNode n,
  double x,
  int index, {
  required double size,
  required double baseSize,
  required int level,
  required StyleForSize styleFor,
  required TextDirection textDirection,
}) {
  // slots of a structure keep the size of the row it stands in, except an index or a base, which are small like a script
  RowLayout slotRow(int k, {bool small = false}) => layoutRow(
        n.slots[k].children,
        baseSize: baseSize,
        styleFor: styleFor,
        textDirection: textDirection,
        level: small ? level + 1 : level,
        slot: true,
      );
  final color = styleFor(size).color ?? const Color(0xFF000000);
  final stroke = math.max(1.0, 0.06 * size);
  final axis = 0.30 * size;
  final gap = 0.10 * size;

  // numerator over denominator, left edge at [left]
  ({List<SlotPlace> slots, double width, double ascent, double descent, StructDecoration bar}) fraction(
    RowLayout num,
    RowLayout den,
    double left,
  ) {
    final pad = 0.10 * size;
    final w = math.max(num.width, den.width) + 2 * pad;
    final numBase = axis + gap + num.descent;
    final denBase = axis - gap - den.ascent;
    return (
      slots: [
        SlotPlace(num, left + (w - num.width) / 2, numBase),
        SlotPlace(den, left + (w - den.width) / 2, denBase),
      ],
      width: w,
      ascent: numBase + num.ascent,
      descent: den.descent - denBase,
      bar: (canvas, ox, baselineY) {
        final y = baselineY - axis;
        canvas.drawLine(Offset(ox + left, y), Offset(ox + left + w, y), _strokePaint(color, stroke));
      },
    );
  }

  switch (n) {
    case FracNode():
      final f = fraction(slotRow(0), slotRow(1), 0);
      return StructPiece(x, index,
          width: f.width, ascent: f.ascent, descent: f.descent, slots: f.slots, decorate: f.bar);
    case MixedFracNode():
      final whole = slotRow(0);
      final f = fraction(slotRow(1), slotRow(2), whole.width + 0.10 * size);
      return StructPiece(x, index,
          width: whole.width + 0.10 * size + f.width,
          ascent: math.max(whole.ascent, f.ascent),
          descent: math.max(whole.descent, f.descent),
          slots: [SlotPlace(whole, 0, 0), ...f.slots],
          decorate: f.bar);
    case SqrtNode():
      final r = slotRow(0);
      final sign = 0.62 * size;
      final top = r.ascent + 0.14 * size;
      final w = sign + r.width + 0.12 * size;
      return StructPiece(x, index,
          width: w,
          ascent: top + stroke / 2,
          descent: r.descent,
          slots: [SlotPlace(r, sign, 0)],
          decorate: (canvas, ox, baselineY) => canvas.drawPath(
                _radicalPath(ox, baselineY - top, baselineY + r.descent, sign, ox + w, size),
                _strokePaint(color, stroke),
              ));
    case RootNode():
      final idx = slotRow(0, small: true);
      final r = slotRow(1);
      final sign = 0.62 * size;
      final top = r.ascent + 0.14 * size;
      final radX = math.max(0.0, idx.width - 0.18 * size);
      final w = radX + sign + r.width + 0.12 * size;
      // the index sits above the tick of the sign, so it never collides with the content
      final idxBase = (top - r.descent) * 0.5 + 0.10 * size;
      return StructPiece(x, index,
          width: w,
          ascent: math.max(top + stroke / 2, idxBase + idx.ascent),
          descent: r.descent,
          slots: [SlotPlace(idx, 0, idxBase), SlotPlace(r, radX + sign, 0)],
          decorate: (canvas, ox, baselineY) => canvas.drawPath(
                _radicalPath(ox + radX, baselineY - top, baselineY + r.descent, sign, ox + w, size),
                _strokePaint(color, stroke),
              ));
    case AbsNode():
      final r = slotRow(0);
      final side = 0.28 * size;
      final top = r.ascent + 0.06 * size;
      final bottom = r.descent + 0.04 * size;
      final w = r.width + 2 * side;
      return StructPiece(x, index,
          width: w,
          ascent: top,
          descent: bottom,
          slots: [SlotPlace(r, side, 0)],
          decorate: (canvas, ox, baselineY) {
            final p = _strokePaint(color, stroke);
            canvas.drawLine(Offset(ox + 0.10 * size, baselineY - top), Offset(ox + 0.10 * size, baselineY + bottom), p);
            canvas.drawLine(
                Offset(ox + w - 0.10 * size, baselineY - top), Offset(ox + w - 0.10 * size, baselineY + bottom), p);
          });
    case IntegralNode() || SigmaNode() || ProdNode():
      final f = slotRow(0);
      final lo = slotRow(1, small: true);
      final hi = slotRow(2, small: true);
      final kind = n is IntegralNode ? BigOp.integral : (n is SigmaNode ? BigOp.sigma : BigOp.prod);
      final opH = kBigOpHeightEm * size;
      final opW = bigOpWidthEm(kind) * opH;
      // the sign spans [signBottom, signTop] above the baseline; the limit boxes keep one gap from it, measured to the edge
      // of what they show, so the box above and the box below are the same distance away
      final signTop = kBigOpCenterEm * size + opH / 2;
      final signBottom = kBigOpCenterEm * size - opH / 2;
      final gap = kBigOpGapEm * size;
      final hiBase = signTop + gap + hi.visDescent;
      final loBase = signBottom - gap - lo.visAscent;
      final symW = math.max(opW, math.max(lo.width, hi.width));
      final fDx = symW + 0.14 * size;
      return StructPiece(x, index,
          width: fDx + f.width,
          ascent: math.max(f.ascent, hiBase + hi.ascent),
          descent: math.max(f.descent, lo.descent - loBase),
          slots: [
            SlotPlace(f, fDx, 0),
            SlotPlace(lo, (symW - lo.width) / 2, loBase),
            SlotPlace(hi, (symW - hi.width) / 2, hiBase),
          ],
          decorate: (canvas, ox, baselineY) => paintBigOp(
                canvas,
                kind,
                Rect.fromLTWH(ox + (symW - opW) / 2, baselineY - signTop, opW, opH),
                color,
              ));
    case DerivNode():
      final f = slotRow(0);
      final at = slotRow(1, small: true);
      TextPainter text(String t, double sz) => TextPainter(
            text: TextSpan(text: t, style: styleFor(sz)),
            textDirection: textDirection,
            maxLines: 1,
          )..layout();
      final word = text('d/dx(', size);
      final close = text(')', size);
      final tag = text('x=', size * 0.7);
      final wb = word.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      final tb = tag.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      final drop = kSubDropEm * size;
      final closeDx = word.width + f.width;
      final tagDx = closeDx + close.width + 0.06 * size;
      final atDx = tagDx + tag.width;
      return StructPiece(x, index,
          width: atDx + at.width,
          ascent: math.max(wb, f.ascent),
          descent: math.max(word.height - wb, math.max(f.descent, math.max(at.descent, tag.height - tb) + drop)),
          slots: [SlotPlace(f, word.width, 0), SlotPlace(at, atDx, -drop)],
          decorate: (canvas, ox, baselineY) {
            word.paint(canvas, Offset(ox, baselineY - wb));
            close.paint(canvas, Offset(ox + closeDx, baselineY - wb));
            tag.paint(canvas, Offset(ox + tagDx, baselineY + drop - tb));
          });
    case LogBaseNode():
      final base = slotRow(0, small: true);
      final arg = slotRow(1);
      final word = TextPainter(
        text: TextSpan(text: 'log', style: styleFor(size)),
        textDirection: textDirection,
        maxLines: 1,
      )..layout();
      final wordBase = word.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      final drop = kSubDropEm * size;
      final baseDx = word.width;
      final argDx = baseDx + base.width + 0.12 * size;
      return StructPiece(x, index,
          width: argDx + arg.width,
          ascent: math.max(wordBase, math.max(arg.ascent, base.ascent - drop)),
          descent: math.max(word.height - wordBase, math.max(arg.descent, base.descent + drop)),
          slots: [SlotPlace(base, baseDx, -drop), SlotPlace(arg, argDx, 0)],
          decorate: (canvas, ox, baselineY) => word.paint(canvas, Offset(ox, baselineY - wordBase)));
  }
}

/// Paints [row] with its top-left corner at [origin].
void paintRow(Canvas canvas, RowLayout row, Offset origin) {
  final baselineY = origin.dy + row.ascent;
  _paintAt(canvas, row, origin.dx, baselineY);
}

void _paintAt(Canvas canvas, RowLayout row, double ox, double baselineY) {
  if (row.emptyBox) {
    final h = kPlaceholderHeightEm * row.size;
    final w = kPlaceholderWidthEm * row.size;
    final inset = math.max(1.0, 0.06 * row.size) / 2;
    canvas.drawRect(
      Rect.fromLTWH(ox + inset, baselineY - kPlaceholderTopEm * row.size + inset, w - 2 * inset, h - 2 * inset),
      _strokePaint(row.boxColor ?? const Color(0xFF000000), math.max(1.0, 0.06 * row.size)),
    );
  }
  for (final p in row.pieces) {
    switch (p) {
      case RunPiece():
        p.painter.paint(canvas, Offset(ox + p.x, baselineY - p.baseline));
      case GroupPiece():
        _paintAt(canvas, p.row, ox + p.x, baselineY - p.dy);
      case StructPiece():
        p.decorate(canvas, ox + p.x, baselineY);
        for (final s in p.slots) {
          _paintAt(canvas, s.row, ox + p.x + s.dx, baselineY - s.dy);
        }
    }
  }
}

/// Where the caret goes: x from the row's left edge, the baseline y from its top, and the font size of that row.
class CaretGeometry {
  const CaretGeometry(this.x, this.baselineY, this.size, {this.block = false});

  final double x;
  final double baselineY;
  final double size;

  /// The caret is in an empty slot: it is the placeholder box, filled.
  final bool block;

  /// The caret bar: a little taller than the text of its own row.
  Rect rect({double width = 2}) {
    if (block) {
      return Rect.fromLTWH(x, baselineY - kPlaceholderTopEm * size, kPlaceholderWidthEm * size, kPlaceholderHeightEm * size);
    }
    return Rect.fromLTWH(x - width / 2, baselineY - size * 0.82, width, size * 1.04);
  }
}

CaretGeometry caretGeometry(RowLayout row, List<int> path, int offset) {
  var current = row;
  var x = 0.0;
  var baselineY = row.ascent;
  var k = 0;
  while (k < path.length) {
    final piece = current.groupAt(path[k]);
    if (piece is GroupPiece) {
      x += piece.x;
      baselineY -= piece.dy;
      current = piece.row;
      k++;
    } else if (piece is StructPiece && k + 1 < path.length && path[k + 1] < piece.slots.length) {
      final place = piece.slots[path[k + 1]];
      x += piece.x + place.dx;
      baselineY -= place.dy;
      current = place.row;
      k += 2;
    } else {
      break;
    }
  }
  return CaretGeometry(x + current.xAtOffset(offset), baselineY, current.size, block: current.emptyBox && offset == 0);
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
    if (p is GroupPiece) {
      if (dx >= p.x && dx <= p.x + p.row.width) {
        final top = baselineY - p.dy - p.row.ascent;
        final bottom = baselineY - p.dy + p.row.descent;
        if (dy >= top && dy <= bottom) {
          return _hit(p.row, dx - p.x, dy, baselineY - p.dy, [...path, p.index]);
        }
      }
    } else if (p is StructPiece) {
      if (dx >= p.x && dx <= p.x + p.width && dy >= baselineY - p.ascent && dy <= baselineY + p.descent) {
        // the slot whose box holds the tap, otherwise the one whose centre is nearest
        var best = 0;
        var bestDist = double.infinity;
        for (var k = 0; k < p.slots.length; k++) {
          final s = p.slots[k];
          final left = p.x + s.dx;
          final top = baselineY - s.dy - s.row.ascent;
          final bottom = baselineY - s.dy + s.row.descent;
          final cx = left + s.row.width / 2;
          final cy = (top + bottom) / 2;
          final inside = dx >= left && dx <= left + s.row.width && dy >= top && dy <= bottom;
          final d = inside ? -1.0 : math.sqrt(math.pow(dx - cx, 2) + math.pow(dy - cy, 2)).toDouble();
          if (d < bestDist) {
            bestDist = d;
            best = k;
          }
        }
        final s = p.slots[best];
        return _hit(s.row, dx - p.x - s.dx, dy, baselineY - s.dy, [...path, p.index, best]);
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
