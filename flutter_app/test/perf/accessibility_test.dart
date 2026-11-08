// Phase 8b: accessibility guards. Screen-reader labels of the keys, and no layout overflow on narrow phones or with a large
// system font.

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/ui/calculator/spoken.dart';

import '../ui/calculator_screen_test.dart' show pumpApp, settle, tapKey;

void collect(SemanticsNode n, List<SemanticsData> out) {
  final d = n.getSemanticsData();
  if (d.hasAction(SemanticsAction.tap)) out.add(d);
  n.visitChildren((c) {
    collect(c, out);
    return true;
  });
}

List<SemanticsData> tappable(WidgetTester tester) {
  final out = <SemanticsData>[];
  collect(tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!, out);
  return out;
}

void main() {
  group('spoken key names', () {
    test('operators and glyph keys have spoken names', () {
      expect(spokenKey('÷'), 'divide');
      expect(spokenKey('×'), 'multiply');
      expect(spokenKey('−'), 'minus');
      expect(spokenKey('.'), 'decimal point');
      expect(spokenKey('▭/▭'), 'fraction');
      expect(spokenKey('◀'), 'left');
      expect(spokenKey('∫▭▭'), 'integral');
    });
    test('digits and plain words are left to the screen reader', () {
      expect(spokenKey('7'), isNull);
      expect(spokenKey('sin'), isNull);
      expect(spokenKey('AC'), isNull);
    });
    test('an unlisted glyph mix still gets words for its symbols', () {
      expect(spokenKey('A▭B'), 'A box B');
    });
  });

  group('screen reader on the calculator', () {
    testWidgets('the main keys are announced by name, none is silent', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester);
      await settle(tester);
      final labels = tappable(tester).map((d) => d.label).toList();
      for (final want in ['divide', 'multiply', 'minus', 'plus', 'percent', 'decimal point', 'Equals', 'Backspace']) {
        expect(labels.any((l) => l.contains(want)), isTrue, reason: want);
      }
      expect(labels.where((l) => l.trim().isEmpty), isEmpty);
      handle.dispose();
    });

    testWidgets('the ES tab keys read as words, not box glyphs', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, size: const Size(400, 1900));
      await settle(tester);
      await tapKey(tester, 'fx ADV');
      await settle(tester);
      final tab = find.text('ES').first;
      await tester.ensureVisible(tab);
      await tester.tap(tab);
      await settle(tester);
      final labels = tappable(tester).map((d) => d.label).toList();
      expect(labels.any((l) => l.startsWith('fraction')), isTrue);
      expect(labels.any((l) => l.startsWith('square root')), isTrue);
      expect(labels.any((l) => l.startsWith('left')), isTrue);
      expect(labels.where((l) => l.trim().isEmpty), isEmpty);
      handle.dispose();
    });
  });

  group('results are announced', () {
    testWidgets('after = the answer is a live region', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester);
      await settle(tester);
      bool anyLive() {
        var found = false;
        void walk(SemanticsNode n) {
          if (n.getSemanticsData().flagsCollection.isLiveRegion) found = true;
          n.visitChildren((c) {
            walk(c);
            return true;
          });
        }

        walk(tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
        return found;
      }

      await tapKey(tester, '7');
      await tapKey(tester, '+');
      await tapKey(tester, '3');
      expect(anyLive(), isFalse, reason: 'nothing is announced while typing');
      await tester.tap(find.text('=').last);
      await settle(tester);
      expect(anyLive(), isTrue);
      handle.dispose();
    });
  });

  group('layout on narrow phones and large fonts', () {
    for (final w in <double>[280, 320, 360]) {
      testWidgets('no overflow at width $w', (tester) async {
        await pumpApp(tester, size: Size(w, 800));
        await settle(tester);
        expect(tester.takeException(), isNull);
      });
    }
    for (final scale in <double>[1.3, 1.6, 2.0]) {
      testWidgets('no overflow at 360 wide with the system font at ${scale}x', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpApp(tester, size: const Size(360, 800));
        await settle(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
