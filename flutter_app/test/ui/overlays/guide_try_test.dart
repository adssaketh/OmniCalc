import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/editor/expr_doc.dart';
import 'package:omnicalc/editor/nodes.dart';
import 'package:omnicalc/engine/types.dart';
import 'package:omnicalc/state/navigation_state.dart';
import 'package:omnicalc/ui/overlays/guide_content.dart';
import 'package:omnicalc/ui/overlays/guide_sheet.dart';
import 'package:provider/provider.dart';

import '../../casio/keypad_math_test.dart' show make;
import '../calculator_screen_test.dart' show pumpApp, settle, shown, tapKey;

/// The guide's Try button: the example reaches the calculator display (also while the calculator is already the screen
/// underneath the guide), as boxes for ∫ d/dx Σ ∏, and = gives the answer printed under the example.
void main() {
  final withLoad = [
    for (final s in kGuideSections)
      for (final e in s.examples)
        if (e.load != null && RegExp(r'^(∫|Σ|∏|d/dx)\(').hasMatch(e.load!)) (section: s.id, example: e),
  ];

  test('the calculus examples have a load form', () {
    expect(withLoad.length, greaterThanOrEqualTo(11));
  });

  for (final item in withLoad) {
    final ex = item.example;
    test('${item.section}: ${ex.load} is boxes and gives the answer in the guide', () async {
      final doc = ExprDoc.fromExample(ex.load!);
      expect(doc.root.whereType<StructNode>(), isNotEmpty, reason: 'loads as a structure');
      expect(doc.linear, ex.load, reason: 'the engine reads what the example says');
      final c = make(rad: ex.angle == AngleMode.rad);
      c.loadExternal(ex.load!);
      expect(c.doc.root.whereType<StructNode>(), isNotEmpty);
      c.handleEvaluate();
      await c.pending;
      final expected = double.parse(runGuideExample(ex).text);
      expect(c.syntaxError, isNull);
      expect(double.parse(c.lastAnswer), closeTo(expected, 1e-6 * (expected.abs() + 1)), reason: ex.load);
    });
  }

  testWidgets('Try on the calculator screen loads the boxes and = calculates', (tester) async {
    await pumpApp(tester, size: const Size(400, 1600));
    await settle(tester);
    final nav = Provider.of<NavigationState>(tester.element(find.byType(Directionality).first), listen: false);
    nav.setGuideOpen(true);
    await settle(tester);
    expect(find.byKey(const ValueKey('guide-example-structure')), findsWidgets, reason: 'the card shows the boxes');
    final tryButton = find.byKey(const ValueKey('guide-try')).first;
    await tester.ensureVisible(tryButton);
    await tester.tap(tryButton);
    await settle(tester);
    expect(nav.isGuideOpen, isFalse);
    expect(shown(tester), 'd/dx(x^2,3)');
    await tapKey(tester, '=');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
    await settle(tester);
    expect(shown(tester), '6');
  });
}
