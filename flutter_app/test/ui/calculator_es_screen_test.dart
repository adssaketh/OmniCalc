import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Scrollable, ValueKey;
import 'package:flutter_test/flutter_test.dart';

import 'calculator_screen_test.dart' show pumpApp, settle, shown, tapKey;

/// Phase 8a on the real screen: the ES tab of the Advanced drawer, its keys, the natural display and the status bar.
Future<void> openEsTab(WidgetTester tester) async {
  await settle(tester);
  await tapKey(tester, 'fx ADV');
  await settle(tester);
  final tab = find.text('ES').first;
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await settle(tester);
}

/// A key by its label. Labels with the `▭` placeholder are drawn with real square boxes (a Text.rich), so they are found
/// by the key the key button gives them; every other label is plain text.
Finder keyLabel(String label) => label.contains('▭') ? find.byKey(ValueKey('key-label:$label')) : find.text(label);

Future<void> esKey(WidgetTester tester, String label) async {
  final f = keyLabel(label).first;
  await tester.ensureVisible(f);
  // The ES tab has seven rows since Phase 7b: when the page is scrolled far down, the first rows sit under the pinned
  // display. Scroll the page back until the key can be hit, as a person would.
  for (var i = 0; i < 6 && keyLabel(label).hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 160), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.tap(f, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('ES tab', () {
    testWidgets('the tab is in the strip and shows the natural-display keys', (tester) async {
      await pumpApp(tester);
      await openEsTab(tester);
      for (final label in ['SHIFT', 'ALPHA', 'INS', 'CALC', '◀', '▲', '▼', '▶', '▭/▭', '√▭', 'ⁿ√▭', '|▭|', 'log▭▭', 'x²', 'x⁻¹', 'xʸ', 'X', 'Y']) {
        expect(keyLabel(label), findsWidgets, reason: label);
      }
    });

    testWidgets('the key labels do not overflow at tablet width (900)', (tester) async {
      await pumpApp(tester, size: const Size(900, 1400));
      await openEsTab(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fraction key: two hollow boxes, caret in the numerator, Math annunciator on', (tester) async {
      await pumpApp(tester);
      await openEsTab(tester);
      expect(find.byKey(const ValueKey('annunciator-Math')), findsNothing);
      await esKey(tester, '▭/▭');
      expect(shown(tester), '(()÷())');
      expect(find.byKey(const ValueKey('annunciator-Math')), findsOneWidget);
    });

    testWidgets('the video sequence on screen: (X²−6)/(X+3) = 10', (tester) async {
      await pumpApp(tester, size: const Size(400, 1900)); // the 7e and 8a keys (×10ˣ, DRG▸, STO, RCL, variables) added rows to the ES tab
      await openEsTab(tester);
      await esKey(tester, '▭/▭');
      await esKey(tester, 'X');
      await esKey(tester, 'x²');
      await esKey(tester, '▶'); // leaves the superscript
      await tapKey(tester, '−');
      await tapKey(tester, '6');
      await esKey(tester, '▼');
      await esKey(tester, 'X');
      await tapKey(tester, '+');
      await tapKey(tester, '3');
      await esKey(tester, '▶'); // leaves the fraction
      await esKey(tester, 'ALPHA');
      expect(find.byKey(const ValueKey('annunciator-A')), findsOneWidget);
      await esKey(tester, 'CALC');
      expect(find.byKey(const ValueKey('annunciator-A')), findsNothing);
      await tapKey(tester, '1');
      await tapKey(tester, '0');
      expect(shown(tester), '((X^2−6)÷(X+3))=10');
    });

    testWidgets('SHIFT shows S and the shifted key does its shifted job: SHIFT x² is x³', (tester) async {
      await pumpApp(tester, size: const Size(400, 1900)); // the 7e and 8a keys (×10ˣ, DRG▸, STO, RCL, variables) added rows to the ES tab
      await openEsTab(tester);
      await tapKey(tester, '2');
      await esKey(tester, 'SHIFT');
      expect(find.byKey(const ValueKey('annunciator-S')), findsOneWidget);
      await esKey(tester, 'x²');
      expect(find.byKey(const ValueKey('annunciator-S')), findsNothing);
      expect(shown(tester), '2^3');
    });

    testWidgets('a placeholder left empty: = shows Syntax ERROR and the expression stays editable', (tester) async {
      await pumpApp(tester);
      await openEsTab(tester);
      await esKey(tester, '√▭');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(find.text('Syntax ERROR'), findsOneWidget);
      expect(shown(tester), 'sqrt()');
      await tapKey(tester, '9');
      expect(find.text('Syntax ERROR'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(shown(tester), '3');
    });

    testWidgets('plain arithmetic still shows no annunciator and the same display as before', (tester) async {
      await pumpApp(tester);
      await settle(tester);
      await tapKey(tester, '7');
      await tapKey(tester, '+');
      await tapKey(tester, '8');
      expect(shown(tester), '7+8');
      for (final n in ['S', 'A', 'M', 'INS', 'Math']) {
        expect(find.byKey(ValueKey('annunciator-$n')), findsNothing, reason: n);
      }
    });
  });
}
