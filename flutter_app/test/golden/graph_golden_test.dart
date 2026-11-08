
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/ui/screens/graph_screen.dart';

import 'golden_loader.dart';

/// graph.json is produced by tools/gen_vectors.ts from the arithmetic of GraphScreen.tsx `drawGraph` (grid loops with
/// JS `%`, `toFixed` labels, the 2 px curve loop, the cursor point and tooltip) running on the real MathEvaluator.
void main() {
  final vectors = (loadGolden('graph') as List).cast<Map<String, dynamic>>();

  void expectNum(double actual, String expected, String what) {
    final e = parseGoldenNumber(expected);
    expect(closeRel(actual, e), isTrue, reason: '$what: got $actual, expected $e');
  }

  void expectLines(List<GraphGridLine> actual, List expected, String what) {
    expect(actual.length, expected.length, reason: '$what: number of lines');
    for (var i = 0; i < expected.length; i++) {
      final e = expected[i] as Map<String, dynamic>;
      expectNum(actual[i].pos, e['pos'] as String, '$what[$i].pos');
      final label = e['label'] as Map<String, dynamic>?;
      if (label == null) {
        expect(actual[i].label, isNull, reason: '$what[$i] has no label');
      } else {
        expect(actual[i].label?.text, label['text'], reason: '$what[$i].label');
        expectNum(actual[i].label!.at.dx, label['x'] as String, '$what[$i].label.x');
        expectNum(actual[i].label!.at.dy, label['y'] as String, '$what[$i].label.y');
      }
    }
  }

  for (var n = 0; n < vectors.length; n++) {
    final v = vectors[n];
    final expr = v['expr'] as String;
    final width = (v['width'] as num).toDouble();
    final height = (v['height'] as num).toDouble();
    final origin = Offset((v['originX'] as num).toDouble(), (v['originY'] as num).toDouble());
    final scale = (v['scale'] as num).toDouble();
    final mouseX = (v['mouseX'] as num?)?.toDouble();
    test('#$n f(x) = "$expr" ${width.toInt()}x${height.toInt()} origin(${origin.dx}, ${origin.dy}) scale $scale mouse $mouseX', () {
      final frame = GraphFrame.compute(expr: expr, width: width, height: height, origin: origin, scale: scale);
      expectNum(frame.ox, v['ox'] as String, 'ox');
      expectNum(frame.oy, v['oy'] as String, 'oy');
      expectLines(frame.vertical, v['vertical'] as List, 'vertical');
      expectLines(frame.horizontal, v['horizontal'] as List, 'horizontal');

      final curve = v['curve'] as List;
      expect(frame.curve.length, curve.length, reason: 'number of curve pieces');
      for (var i = 0; i < curve.length; i++) {
        final piece = curve[i] as List;
        expect(frame.curve[i].length, piece.length, reason: 'piece $i length');
        for (var j = 0; j < piece.length; j++) {
          final p = piece[j] as List;
          expectNum(frame.curve[i][j].dx, p[0] as String, 'curve[$i][$j].x');
          expectNum(frame.curve[i][j].dy, p[1] as String, 'curve[$i][$j].y');
        }
      }

      if (mouseX == null) return;
      final cursor = graphCursorPoint(expr, mouseX, frame.ox, frame.oy, scale);
      final expected = v['cursor'] as List?;
      if (expected == null) {
        expect(cursor, isNull);
      } else {
        expect(cursor, isNotNull);
        expectNum(cursor!.dx, expected[0] as String, 'cursor.x');
        expectNum(cursor.dy, expected[1] as String, 'cursor.y');
      }
      expect(graphTooltipX(mouseX, width, origin.dx, scale), v['tipX']);
      expect(graphTooltipY(expr, mouseX, width, origin.dx, scale), v['tipY']);
    });
  }
}
