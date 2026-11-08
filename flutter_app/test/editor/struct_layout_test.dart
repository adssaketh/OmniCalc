import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/editor/nodes.dart';
import 'package:omnicalc/editor/rich_layout.dart';

// Phase 8a: layout, caret geometry and taps for the structures. flutter_test draws all text with the Ahem font: every
// glyph is 1 em wide, `ascentEm` above the baseline and `descentEm` below (read from the engine, as in rich_layout_test).
TextStyle style(double s) => TextStyle(fontSize: s, color: const Color(0xFF000000));

final double ascentEm = (TextPainter(text: TextSpan(text: 'x', style: style(100)), textDirection: TextDirection.ltr)
          ..layout())
        .computeDistanceToActualBaseline(TextBaseline.alphabetic) /
    100;
final double descentEm = 1 - ascentEm;

List<Node> chars(String s) => [for (final u in s.codeUnits) CharNode(String.fromCharCode(u))];
SlotNode slot(String s) => SlotNode(chars(s));

RowLayout lay(List<Node> nodes, {double size = 100}) =>
    layoutRow(nodes, baseSize: size, styleFor: style, textDirection: TextDirection.ltr);

void main() {
  group('fraction', () {
    final row = lay([FracNode([slot('1'), slot('23')])]);
    final piece = row.pieces.single as StructPiece;

    test('is as wide as the wider part plus a pad on each side, parts centred', () {
      expect(piece.width, closeTo(200 + 20, 1e-9));
      expect(row.width, closeTo(220, 1e-9));
      expect(piece.slots[0].dx, closeTo((220 - 100) / 2, 1e-9));
      expect(piece.slots[1].dx, closeTo((220 - 200) / 2, 1e-9));
    });

    test('numerator sits above the bar, denominator below it', () {
      final numBase = 30 + 10 + 100 * descentEm;
      final denBase = 30 - 10 - 100 * ascentEm;
      expect(piece.slots[0].dy, closeTo(numBase, 1e-9));
      expect(piece.slots[1].dy, closeTo(denBase, 1e-9));
      expect(row.ascent, closeTo(numBase + 100 * ascentEm, 1e-9));
      expect(row.descent, closeTo(100 * descentEm - denBase, 1e-9));
      expect(row.height, greaterThan(100));
    });

    test('slots keep the size of the row they stand in', () {
      expect(piece.slots[0].row.size, 100);
      expect(piece.slots[1].row.size, 100);
    });
  });

  test('an empty slot is a hollow box of fixed width, a filled one is not', () {
    final row = lay([FracNode([SlotNode(), slot('2')])]);
    final piece = row.pieces.single as StructPiece;
    expect(piece.slots[0].row.emptyBox, isTrue);
    expect(piece.slots[0].row.width, closeTo(56, 1e-9));
    expect(piece.slots[1].row.emptyBox, isFalse);
    expect(piece.slots[0].row.boxColor, const Color(0xFF000000));
  });

  test('plain text and superscripts are never boxes', () {
    expect(lay(chars('abc')).emptyBox, isFalse);
    expect(lay([const CharNode('x'), SupNode()]).pieces.whereType<GroupPiece>().single.row.emptyBox, isFalse);
  });

  group('square root', () {
    test('has room for the sign in front and a little behind, and an overbar above the content', () {
      final row = lay([SqrtNode([slot('ab')])]);
      final p = row.pieces.single as StructPiece;
      expect(p.width, closeTo(62 + 200 + 12, 1e-9));
      expect(p.slots.single.dx, closeTo(62, 1e-9));
      expect(row.ascent, greaterThan(100 * ascentEm + 14 - 1e-9));
      expect(row.descent, closeTo(100 * descentEm, 1e-9));
    });

    test('the index of a root is small and sits to the left of the radicand', () {
      final row = lay([RootNode([slot('3'), slot('8')])]);
      final p = row.pieces.single as StructPiece;
      expect(p.slots[0].row.size, closeTo(62, 1e-9));
      expect(p.slots[1].dx, greaterThan(p.slots[0].row.width - 1));
      expect(p.slots[1].row.size, 100);
      // the index is raised, so the line is taller than for a plain square root
      expect(row.ascent, greaterThanOrEqualTo(lay([SqrtNode([slot('8')])]).ascent));
    });
  });

  test('absolute value bars add a margin on each side', () {
    final row = lay([AbsNode([slot('x')])]);
    final p = row.pieces.single as StructPiece;
    expect(p.width, closeTo(100 + 56, 1e-9));
    expect(p.slots.single.dx, closeTo(28, 1e-9));
  });

  test('log with a base: the word, a lowered small base, then the argument', () {
    final row = lay([LogBaseNode([slot('2'), slot('8')])]);
    final p = row.pieces.single as StructPiece;
    expect(p.slots[0].row.size, closeTo(62, 1e-9));
    expect(p.slots[0].dy, closeTo(-25, 1e-9));
    expect(p.slots[0].dx, closeTo(300, 1e-9), reason: 'the word log is three glyphs wide');
    expect(p.slots[1].dx, closeTo(300 + 62 + 12, 1e-9));
    expect(p.width, closeTo(300 + 62 + 12 + 100, 1e-9));
  });

  test('mixed fraction: whole part, then a fraction', () {
    final row = lay([MixedFracNode([slot('3'), slot('1'), slot('2')])]);
    final p = row.pieces.single as StructPiece;
    expect(p.slots.length, 3);
    expect(p.slots[0].dx, 0);
    expect(p.slots[1].dx, greaterThan(100));
    expect(p.width, closeTo(100 + 10 + 120, 1e-9));
  });

  test('a structure in the middle of text shifts what follows it and offsets are gaps around it', () {
    final row = lay([...chars('ab'), FracNode([slot('1'), slot('2')]), ...chars('c')]);
    expect(row.xAtOffset(2), closeTo(200, 1e-9));
    expect(row.xAtOffset(3), closeTo(200 + 120, 1e-9));
    expect(row.xAtOffset(4), closeTo(200 + 120 + 100, 1e-9));
  });

  group('caret', () {
    final nodes = <Node>[...chars('ab'), FracNode([slot('1'), slot('23')])];
    final row = lay(nodes);
    final piece = row.pieces.whereType<StructPiece>().single;

    test('in the numerator: on its baseline, at the end of its text', () {
      final g = caretGeometry(row, const [2, 0], 1);
      final place = piece.slots[0];
      expect(g.x, closeTo(piece.x + place.dx + 100, 1e-9));
      expect(g.baselineY, closeTo(row.ascent - place.dy, 1e-9));
      expect(g.size, 100);
      expect(g.block, isFalse);
    });

    test('in the denominator it is lower than in the numerator', () {
      final up = caretGeometry(row, const [2, 0], 0);
      final down = caretGeometry(row, const [2, 1], 0);
      expect(down.baselineY, greaterThan(up.baselineY));
    });

    test('in an empty slot the caret is the placeholder box, filled', () {
      final r = lay([FracNode()]);
      final g = caretGeometry(r, const [0, 0], 0);
      expect(g.block, isTrue);
      final box = g.rect();
      expect(box.width, closeTo(56, 1e-9));
      expect(box.height, closeTo(78, 1e-9));
      expect(box.top, closeTo(g.baselineY - 74, 1e-9));
    });

    test('before and after the fraction in the row', () {
      expect(caretGeometry(row, const [], 2).x, closeTo(200, 1e-9));
      expect(caretGeometry(row, const [], 3).x, closeTo(200 + piece.width, 1e-9));
    });

    test('inside a superscript inside a numerator', () {
      final r = lay([
        FracNode([
          SlotNode([const CharNode('X'), SupNode(chars('2'))]),
          slot('1'),
        ]),
      ]);
      final inSup = caretGeometry(r, const [0, 0, 1], 1);
      final inNum = caretGeometry(r, const [0, 0], 1);
      expect(inSup.size, closeTo(62, 1e-9));
      expect(inSup.baselineY, lessThan(inNum.baselineY), reason: 'raised');
    });
  });

  group('taps', () {
    final row = lay([FracNode([slot('1'), slot('23')])]);
    final piece = row.pieces.single as StructPiece;

    double centreY(SlotPlace s) => row.ascent - s.dy + (s.row.descent - s.row.ascent) / 2;

    test('a tap on the numerator or the denominator puts the caret in that slot', () {
      final up = piece.slots[0];
      final down = piece.slots[1];
      final hitUp = hitTest(row, piece.x + up.dx + 10, centreY(up));
      expect(hitUp.path, [0, 0]);
      final hitDown = hitTest(row, piece.x + down.dx + 180, centreY(down));
      expect(hitDown.path, [0, 1]);
      expect(hitDown.offset, 2, reason: 'nearest gap to the right of the 23');
    });

    test('a tap beside the fraction lands in the row, not in a slot', () {
      final hit = hitTest(row, piece.width + 500, row.ascent);
      expect(hit.path, isEmpty);
      expect(hit.offset, 1);
    });

    test('a tap on the bar picks the nearer slot', () {
      final barY = row.ascent - 30;
      final hit = hitTest(row, piece.width / 2, barY);
      expect(hit.path.length, 2);
    });
  });

  test('nested fractions lay out and the outer one gets taller', () {
    final inner = FracNode([slot('1'), slot('2')]);
    final outer = lay([FracNode([SlotNode([inner]), slot('3')])]);
    final single = lay([FracNode([slot('1'), slot('3')])]);
    expect(outer.height, greaterThan(single.height));
    final g = caretGeometry(outer, const [0, 0, 0, 0], 0);
    expect(g.block, isFalse);
    expect(g.baselineY, lessThan(outer.ascent));
  });
}
