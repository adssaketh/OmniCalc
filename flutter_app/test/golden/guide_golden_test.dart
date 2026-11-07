import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/evaluator.dart';
import 'package:omnicalc/engine/types.dart';
import 'package:omnicalc/ui/overlays/guide_content.dart';
import 'package:omnicalc/ui/overlays/guide_sheet.dart';

import 'golden_loader.dart';

/// `test/golden/guide.json` holds what the TypeScript engine shows for every example of the user guide
/// (tools/gen_guide.ts, computed like GuideSheet.tsx `runExample`). The Dart engine must show the same strings.
void main() {
  final vectors = (loadGolden('guide') as List).cast<Map<String, dynamic>>();

  test('the generated guide has the same examples, in the same order, as the vectors', () {
    final fromDart = [
      for (final s in kGuideSections)
        for (final e in s.examples) '${s.id}|${e.expr}|${e.angle?.id}|${e.setup}',
    ];
    final fromJson = [for (final v in vectors) '${v['section']}|${v['expr']}|${v['angle']}|${v['setup']}'];
    expect(fromDart, fromJson);
    expect(kGuideSections.length, 10);
    expect(vectors.length, 42);
  });

  group('every example shows what the web guide shows', () {
    var index = 0;
    for (final s in kGuideSections) {
      for (final e in s.examples) {
        final v = vectors[index++];
        test('${s.id}: ${e.expr}', () {
          MathEvaluator.setYDefinition(null);
          final r = runGuideExample(e);
          expect(r.text, v['text']);
          expect(r.isError, v['isError']);
          expect(r.plain, v['plain']);
        });
      }
    }
  });

  test('examples with their own equation put the saved one back', () {
    MathEvaluator.setYDefinition('x+1');
    final yExample = kGuideSections.firstWhere((s) => s.id == 'equation').examples.firstWhere((e) => e.setup != null);
    expect(runGuideExample(yExample).text, '2');
    expect(MathEvaluator.getYDefinition(), 'x+1');
    MathEvaluator.setYDefinition(null);
  });

  test('defining an equation is not a calculation', () {
    final define = kGuideSections.firstWhere((s) => s.id == 'equation').examples.first;
    MathEvaluator.setYDefinition('x');
    final r = runGuideExample(define);
    expect(r, const GuideResult('Saved. Now type an x value and press =', false, plain: true));
    expect(MathEvaluator.getYDefinition(), 'x'); // nothing was saved
    MathEvaluator.setYDefinition(null);
  });

  test('angle examples use their own unit, not the setting', () {
    final sin30 = kGuideSections.firstWhere((s) => s.id == 'trig').examples.first;
    expect(sin30.angle, AngleMode.deg);
    expect(runGuideExample(sin30).text, '0.5');
  });
}
