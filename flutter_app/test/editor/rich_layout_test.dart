import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/editor/linear.dart';
import 'package:omnicalc/editor/rich_layout.dart';

// flutter_test draws all text with the Ahem font: every glyph is 1 em wide, 0.8 em above the baseline and 0.2 em below.
// That makes the expected numbers exact.
TextStyle style(double s) => TextStyle(fontSize: s, color: const Color(0xFF000000));

RowLayout lay(String linear, {double size = 100}) => layoutRow(
      parseLinear(linear).nodes,
      baseSize: size,
      styleFor: style,
      textDirection: TextDirection.ltr,
    );

void main() {
  test('level scales: 1, 0.62, then smaller, never below 0.45', () {
    expect(levelScale(0), 1);
    expect(levelScale(1), closeTo(0.62, 1e-9));
    expect(levelScale(2), closeTo(0.496, 1e-9));
    expect(levelScale(3), 0.45);
    expect(levelScale(9), 0.45);
  });

  group('rows', () {
    test('text without groups is one run with the metrics of the plain text', () {
      final row = lay('abc');
      final plain = TextPainter(text: TextSpan(text: 'abc', style: style(100)), textDirection: TextDirection.ltr)
        ..layout();
      expect(row.pieces.length, 1);
      expect(row.width, closeTo(plain.width, 1e-9));
      expect(row.height, closeTo(plain.height, 1e-9));
      expect(row.width, closeTo(300, 1e-9));
    });

    test('a superscript is smaller, raised, and makes the line taller above', () {
      final row = lay('x^2');
      expect(row.width, closeTo(100 + 62, 1e-9));
      // child ascent 0.8 * 62 = 49.6, raised by 0.38 * 100 = 38
      expect(row.ascent, closeTo(87.6, 1e-9));
      expect(row.descent, closeTo(20, 1e-9));
    });

    test('a subscript is lowered and makes the line taller below', () {
      final row = lay('x_2');
      // child descent 0.2 * 62 = 12.4, lowered by 0.25 * 100 = 25
      expect(row.descent, closeTo(37.4, 1e-9));
      expect(row.ascent, closeTo(80, 1e-9));
    });

    test('nested groups shrink further and add up', () {
      final one = lay('x^(y^2)');
      final two = lay('x^y');
      expect(one.width, greaterThan(two.width));
      final outer = one.pieces.whereType<GroupPiece>().single;
      final inner = outer.row.pieces.whereType<GroupPiece>().single;
      expect(outer.row.size, closeTo(62, 1e-9));
      expect(inner.row.size, closeTo(49.6, 1e-9));
      // the inner group is raised by 0.38 of the outer size
      expect(inner.dy, closeTo(0.38 * 62, 1e-9));
    });

    test('an empty group has a width so the caret can stand in it', () {
      final row = lay('x^');
      expect(row.width, closeTo(100 + 0.35 * 62, 1e-9));
    });

    test('an empty row still has a line height', () {
      final row = lay('');
      expect(row.width, 0);
      expect(row.height, closeTo(100, 1e-9));
    });
  });

  group('caret geometry', () {
    test('in plain text', () {
      final row = lay('abc');
      expect(caretGeometry(row, const [], 0).x, closeTo(0, 1e-9));
      expect(caretGeometry(row, const [], 1).x, closeTo(100, 1e-9));
      expect(caretGeometry(row, const [], 3).x, closeTo(300, 1e-9));
      expect(caretGeometry(row, const [], 3).baselineY, closeTo(row.ascent, 1e-9));
      expect(caretGeometry(row, const [], 3).size, 100);
    });

    test('inside a superscript it sits on the raised baseline at the small size', () {
      final row = lay('x^2');
      final g = caretGeometry(row, const [1], 1);
      expect(g.x, closeTo(162, 1e-9));
      expect(g.baselineY, closeTo(87.6 - 38, 1e-9));
      expect(g.size, closeTo(62, 1e-9));
      expect(caretGeometry(row, const [1], 0).x, closeTo(100, 1e-9));
    });

    test('before and after a group in its own row', () {
      final row = lay('x^2+1');
      expect(caretGeometry(row, const [], 1).x, closeTo(100, 1e-9));
      expect(caretGeometry(row, const [], 2).x, closeTo(162, 1e-9));
    });

    test('rect is a bar around the caret', () {
      final r = const CaretGeometry(50, 80, 100).rect();
      expect(r.width, 2);
      expect(r.left, closeTo(49, 1e-9));
      expect(r.top, closeTo(80 - 82, 1e-9));
      expect(r.height, closeTo(104, 1e-9));
    });
  });

  group('hit testing', () {
    test('a tap on plain text goes to the nearest gap', () {
      final row = lay('abc');
      expect(hitTest(row, 10, 40).offset, 0);
      expect(hitTest(row, 110, 40).offset, 1);
      expect(hitTest(row, 290, 40).offset, 3);
      expect(hitTest(row, 900, 40).offset, 3);
      expect(hitTest(row, 10, 40).path, isEmpty);
    });

    test('a tap on a superscript goes inside it', () {
      final row = lay('x^23');
      final hit = hitTest(row, 150, 30);
      expect(hit.path, [1]);
      expect(hit.offset, 1);
    });

    test('a tap beside the superscript but below it stays in the line', () {
      final row = lay('x^2');
      final hit = hitTest(row, 130, 95);
      expect(hit.path, isEmpty);
      expect(hit.offset, 1);
    });
  });
}
