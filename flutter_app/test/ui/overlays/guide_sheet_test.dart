import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/types.dart';
import 'package:omnicalc/state/app_settings.dart';
import 'package:omnicalc/state/navigation_state.dart';
import 'package:omnicalc/ui/overlays/guide_content.dart';
import 'package:omnicalc/ui/overlays/guide_sheet.dart';

import '../shell_test.dart' show Harness, navOf, pumpApp, settle;

Finder k(String key) => find.byKey(ValueKey(key));

Future<Harness> openGuide(WidgetTester tester, {AppSettings settings = const AppSettings()}) async {
  final h = await pumpApp(tester, size: const Size(630, 1000), settings: settings);
  navOf(tester).setGuideOpen(true);
  await settle(tester);
  return h;
}

Future<void> tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await settle(tester);
}

void main() {
  testWidgets('opens with the topic "diff" expanded and its example results shown', (tester) async {
    await openGuide(tester);
    expect(find.text('How to use OmniCalc'), findsOneWidget);
    for (final s in kGuideSections) {
      expect(k('guide-section-${s.id}'), findsOneWidget, reason: s.id);
    }
    final diff = kGuideSections.firstWhere((s) => s.id == 'diff');
    expect(k('guide-example-diff-${diff.examples.length - 1}'), findsOneWidget);
    expect(k('guide-example-trig-0'), findsNothing); // closed topics do not build their examples
    expect(k('guide-result'), findsWidgets);
  });

  testWidgets('accordion: opening another topic closes the first, tapping the open one closes it', (tester) async {
    await openGuide(tester);
    await tapVisible(tester, k('guide-toggle-trig'));
    expect(k('guide-example-trig-0'), findsOneWidget);
    expect(k('guide-example-diff-0'), findsNothing);
    await tapVisible(tester, k('guide-toggle-trig'));
    expect(k('guide-example-trig-0'), findsNothing);
  });

  testWidgets('the result of an example is what the engine shows', (tester) async {
    await openGuide(tester);
    await tapVisible(tester, k('guide-toggle-trig'));
    final sin30 = kGuideSections.firstWhere((s) => s.id == 'trig').examples.first;
    final expected = runGuideExample(sin30);
    expect(find.descendant(of: k('guide-example-trig-0'), matching: find.textContaining(expected.text)), findsWidgets);
  });

  testWidgets('Try loads the expression into the calculator, closes the guide and switches the angle unit', (tester) async {
    final h = await openGuide(tester, settings: const AppSettings(angleMode: AngleMode.rad));
    await tapVisible(tester, k('guide-toggle-trig'));
    final ex = kGuideSections.firstWhere((s) => s.id == 'trig').examples.first;
    expect(ex.angle, AngleMode.deg);
    await tapVisible(tester, find.descendant(of: k('guide-example-trig-0'), matching: k('guide-try')));
    final nav = navOf(tester);
    expect(nav.isGuideOpen, false);
    expect(nav.mode, CalculatorMode.standard);
    expect(nav.externalExpression, ex.load ?? ex.expr);
    expect(h.settings.settings.angleMode, AngleMode.deg);
  });

  testWidgets('Try on an example with no angle leaves the angle unit alone', (tester) async {
    final h = await openGuide(tester, settings: const AppSettings(angleMode: AngleMode.rad));
    final ex = kGuideSections.firstWhere((s) => s.id == 'diff').examples.first;
    expect(ex.angle, isNull);
    await tapVisible(tester, find.descendant(of: k('guide-example-diff-0'), matching: k('guide-try')));
    expect(h.settings.settings.angleMode, AngleMode.rad);
    expect(navOf(tester).externalExpression, ex.load ?? ex.expr);
  });

  testWidgets('the back arrow and the Android back button close the guide', (tester) async {
    await openGuide(tester);
    await tester.tap(k('guide-back'));
    await settle(tester);
    expect(navOf(tester).isGuideOpen, false);
    navOf(tester).setGuideOpen(true);
    await settle(tester);
    expect(navOf(tester).handleBack(), BackAction.closedGuide);
  });

  testWidgets('the topic that was open is remembered when the guide is reopened', (tester) async {
    await openGuide(tester);
    await tapVisible(tester, k('guide-toggle-prob'));
    navOf(tester).setGuideOpen(false);
    await settle(tester);
    navOf(tester).setGuideOpen(true);
    await settle(tester);
    expect(k('guide-example-prob-0'), findsOneWidget);
  });
}
