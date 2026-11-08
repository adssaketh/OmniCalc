@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/editor/expr_doc.dart';
import 'package:omnicalc/editor/nodes.dart';
import 'package:omnicalc/editor/rich_expression_view.dart';
import 'package:omnicalc/state/app_settings.dart';
import 'package:omnicalc/state/navigation_state.dart';
import 'package:omnicalc/theme/tokens.dart';

import '../ui/shell_test.dart' show navOf, pumpApp, settle;

// Phase 8c: regression screenshots. These baselines are rendered by THIS app in the Flutter test font (not Roboto), so
// they catch a layout that changed, not a difference from the web app (that comparison needs Chrome, see PHASE8C_NOTES.md).
//
// Off in a normal `flutter test`: pixel output depends on the Flutter version, so CI runs them in their own job on a
// pinned version. Run or refresh them with
//   OMNI_SCREENSHOTS=1 flutter test test/screenshots                       (compare)
//   flutter test test/screenshots --update-goldens                        (create or refresh)
// A failure leaves the actual and the difference image in test/screenshots/failures/. Look at them before re-baselining.
final bool enabled = Platform.environment['OMNI_SCREENSHOTS'] == '1' || autoUpdateGoldenFiles;

const String dir = '../goldens/regression';

const List<(String, String)> themes = <(String, String)>[
  ('iris', ThemeIds.iris),
  ('ocean', ThemeIds.ocean),
  ('forest', ThemeIds.forest),
  ('sunset', ThemeIds.sunset),
  ('amoled', ThemeIds.amoled),
];

const List<(String, CalculatorMode)> screens = <(String, CalculatorMode)>[
  ('calculator', CalculatorMode.standard),
  ('advanced', CalculatorMode.scientific),
  ('converter', CalculatorMode.converter),
  ('finance', CalculatorMode.finance),
  ('physics', CalculatorMode.physics),
  ('chemistry', CalculatorMode.chemistry),
  ('grapher', CalculatorMode.grapher),
];

List<Node> chars(String s) => [for (final u in s.codeUnits) CharNode(String.fromCharCode(u))];
SlotNode slot(Object s) => SlotNode(s is String ? chars(s) : s as List<Node>);

/// The natural-display structures of Part 9.7 as documents (the same trees the editor builds).
final Map<String, List<Node>> structures = <String, List<Node>>{
  'fraction': [FracNode([slot('X²−6'), slot('X+3')]), ...chars('=10')],
  'nested_fraction': [FracNode([slot('1'), slot([...chars('1+'), FracNode([slot('1'), slot('2')])])])],
  'superscript': [...chars('2'), SupNode([...chars('3+X'), SupNode(chars('2'))])],
  'sqrt': [SqrtNode([slot('2')]), ...chars('+'), SqrtNode([slot([FracNode([slot('7'), slot('6')])])])],
  'nth_root': [RootNode([slot('5'), slot('32')])],
  'integral': [IntegralNode([slot('cos(X)'), slot('0'), slot('π÷2')])],
  'sigma': [SigmaNode([slot('X+1'), slot('1'), slot('5')])],
  'product': [ProdNode([slot('X+1'), slot('1'), slot('5')])],
  'derivative': [DerivNode([slot('sin(X)'), slot('π÷2')])],
  'log_base': [LogBaseNode([slot('2'), slot('16')])],
  'abs': [AbsNode([slot('2−7')]), ...chars('×2')],
  'mixed_fraction': [MixedFracNode([slot('1'), slot('1'), slot('6')])],
  'recurring_decimal': chars('1.4̅2̅8̅5̅7̅1̅'),
  'complex': [...chars('√2+√2i'), ...chars('  '), ...chars('2∠45')],
};

Future<void> screen(WidgetTester tester, String name, String theme, ColorMode mode, CalculatorMode screenMode, Size size) async {
  final h = await pumpApp(
    tester,
    size: size,
    settings: AppSettings(colorMode: mode, theme: theme, enableGrapher: true, enablePhysics: true, enableChemistry: true),
  );
  navOf(tester).setMode(screenMode);
  await settle(tester);
  await tester.pump(const Duration(milliseconds: 600));
  expect(h.settings.settings.theme, theme);
  await expectLater(find.byType(MaterialApp).first, matchesGoldenFile('$dir/$name.png'));
}

Future<void> structure(WidgetTester tester, String name, List<Node> nodes, bool dark) async {
  tester.view.physicalSize = const Size(420, 160);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final tokens = staticTokens(ThemeIds.iris, isDark: dark);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: M3Theme(
      tokens: tokens,
      child: Scaffold(
        backgroundColor: tokens.surface,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: RichExpressionView(doc: ExprDoc.fromNodes(nodes), max: 48, min: 20, color: tokens.onSurface),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
  await expectLater(find.byType(Scaffold), matchesGoldenFile('$dir/structure_${name}_${dark ? 'dark' : 'light'}.png'));
}

void main() {
  if (!enabled) {
    test('screenshots are off (set OMNI_SCREENSHOTS=1 to compare, or run with --update-goldens)', () {
      expect(enabled, isFalse);
    });
    return;
  }
  for (final (screenName, screenMode) in screens) {
    for (final (themeName, themeId) in themes) {
      for (final dark in <bool>[false, true]) {
        final mode = dark ? ColorMode.dark : ColorMode.light;
        final base = '${screenName}_${themeName}_${dark ? 'dark' : 'light'}';
        testWidgets('$base portrait', (t) => screen(t, '${base}_portrait', themeId, mode, screenMode, const Size(400, 800)));
        if (screenMode == CalculatorMode.standard || screenMode == CalculatorMode.scientific) {
          testWidgets('$base landscape', (t) => screen(t, '${base}_landscape', themeId, mode, screenMode, const Size(800, 400)));
        }
      }
    }
  }
  for (final e in structures.entries) {
    for (final dark in <bool>[false, true]) {
      testWidgets('structure ${e.key} ${dark ? 'dark' : 'light'}', (t) => structure(t, e.key, e.value, dark));
    }
  }
}
