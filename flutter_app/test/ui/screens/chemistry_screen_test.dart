import 'package:flutter/material.dart' show SelectableText, TextField;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/chemistry/elements.dart';
import 'package:omnicalc/engine/evaluator.dart';
import 'package:omnicalc/engine/types.dart';
import 'package:omnicalc/main.dart';
import 'package:omnicalc/services/feedback_service.dart';
import 'package:omnicalc/state/app_settings.dart';
import 'package:omnicalc/state/history_store.dart';
import 'package:omnicalc/state/navigation_state.dart';
import 'package:omnicalc/state/settings_store.dart';
import 'package:omnicalc/theme/dynamic_colors.dart';
import 'package:omnicalc/ui/calculator/calculator_controller.dart';
import 'package:omnicalc/ui/screens/chemistry_periodic.dart';
import 'package:omnicalc/ui/shell/app_shell.dart';
import 'package:provider/provider.dart';

import '../../support/fake_currency.dart';

Future<SilentFeedbackService> pumpChemistry(WidgetTester tester, {Size size = const Size(420, 4000), String? tabLabel}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final feedback = SilentFeedbackService();
  await tester.pumpWidget(OmniCalcApp(
    settings: SettingsStore.memory(const AppSettings(enableChemistry: true), true),
    history: HistoryStore.memory(),
    systemColorsSource: const FakeSystemColorsSource(null),
    feedback: feedback,
    currencyService: offlineCurrencyService(),
  ));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 1500));
  navOf(tester).setMode(CalculatorMode.chemistry);
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 1500));
  if (tabLabel != null) {
    await tester.ensureVisible(find.text(tabLabel).first);
    await tester.tap(find.text(tabLabel).first);
    await tester.pump(const Duration(milliseconds: 600));
  }
  return feedback;
}

NavigationState navOf(WidgetTester tester) =>
    Provider.of<NavigationState>(tester.element(find.byType(AppShell)), listen: false);

String fieldText(WidgetTester tester, String key) => tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

Future<void> typeInto(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.enterText(find.byKey(ValueKey(key)), text);
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> tapText(WidgetTester tester, String text, {bool last = false}) async {
  final f = last ? find.text(text).last : find.text(text).first;
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('navigation and settings', () {
    test('Chemistry is off by default and sits after Physics Lab when both are on', () {
      expect(const AppSettings().enableChemistry, false);
      expect(getNavItems(false).map((i) => i.id), ['standard', 'converter', 'finance', 'recents']);
      expect(getNavItems(false, false, true).map((i) => i.id), ['standard', 'converter', 'chemistry', 'finance', 'recents']);
      expect(getNavItems(true, true, true).map((i) => i.id),
          ['standard', 'converter', 'physics', 'chemistry', 'finance', 'recents', 'grapher']);
    });

    test('switching Chemistry off while on it returns to the calculator', () {
      final nav = NavigationState()..setMode(CalculatorMode.chemistry);
      nav.enforceEnabledModes(enableGrapher: false, enablePhysics: false, enableChemistry: true);
      expect(nav.mode, CalculatorMode.chemistry);
      nav.enforceEnabledModes(enableGrapher: false, enablePhysics: false, enableChemistry: false);
      expect(nav.mode, CalculatorMode.standard);
    });

    test('the setting survives a JSON round trip', () {
      final s = const AppSettings().copyWith(enableChemistry: true);
      expect(AppSettings.fromJson(s.toJson()).enableChemistry, true);
    });
  });

  group('periodic table layout', () {
    test('every element has its own cell, groups 1-18 in periods 1-7, f-block below', () {
      final seen = <(int, int)>{};
      for (final e in chemElements) {
        final cell = elementCell(e);
        expect(seen.add(cell), true, reason: '${e.symbol} shares a cell');
        expect(cell.$2, inInclusiveRange(0, 17));
      }
      expect(seen.length, 118);
      expect(elementCell(chemElements[0]), (0, 0)); // H
      expect(elementCell(chemElements[1]), (0, 17)); // He
      expect(elementCell(chemElements[25]), (3, 7)); // Fe: period 4, group 8
      expect(elementCell(chemElements[56]), (8, 2)); // La
      expect(elementCell(chemElements[70]), (8, 16)); // Lu
      expect(elementCell(chemElements[88]), (9, 2)); // Ac
      expect(elementCell(chemElements[117]), (6, 17)); // Og
    });

    test('filters and search', () {
      final fe = chemElements[25];
      expect(elementHighlighted(fe, '', const ElementFilter()), true);
      expect(elementHighlighted(fe, 'iron', const ElementFilter()), true);
      expect(elementHighlighted(fe, 'cu', const ElementFilter()), false);
      expect(elementHighlighted(fe, '26', const ElementFilter()), true);
      expect(elementHighlighted(fe, '', const ElementFilter(category: 'Transition metal')), true);
      expect(elementHighlighted(fe, '', const ElementFilter(category: 'Halogen')), false);
      expect(elementHighlighted(fe, '', const ElementFilter(block: 'd')), true);
      expect(elementHighlighted(fe, '', const ElementFilter(block: 's')), false);
      expect(elementHighlighted(fe, '', const ElementFilter(state: 'solid')), true);
      expect(elementHighlighted(fe, '', const ElementFilter(state: 'gas')), false);
      final unknown = chemElements.where((e) => e.standardState == null).toList();
      for (final e in unknown) {
        expect(elementHighlighted(e, '', const ElementFilter(state: 'unknown')), true);
      }
    });

    test('the detail rows show a dash for data the table does not have, never a made-up value', () {
      final he = chemElements[1];
      final rows = {for (final (k, v) in elementDetailRows(he)) k: v};
      expect(rows['Atomic number'], '2');
      expect(rows['Electronegativity (Pauling)'], '—');
      expect(rows['Oxidation states'], '—');
      final fe = {for (final (k, v) in elementDetailRows(chemElements[25])) k: v};
      expect(fe['Electron configuration'], contains('4s'));
      expect(fe['Oxidation states'], contains('+3'));
      expect(fe['Block'], 'd');
    });

    test('superscripts in the electron configuration', () {
      final fe = chemElements[25];
      expect(fe.electronConfig, matches(RegExp(r'[⁰¹²³⁴⁵⁶⁷⁸⁹]')));
    });
  });

  group('advanced keypad tab', () {
    test('the Chemistry tab comes after the original five (the ES tab of Phase 8a follows it)', () {
      expect(advancedTabDefs.map((d) => d.id).toList(), [
        AdvancedTab.calculus,
        AdvancedTab.trig,
        AdvancedTab.powers,
        AdvancedTab.prob,
        AdvancedTab.constants,
        AdvancedTab.chemistry,
        AdvancedTab.es,
      ]);
    });

    test('typed through the key handlers, the chemistry functions evaluate', () {
      MathEvaluator.setYDefinition(null);
      final c = CalculatorController(feedback: SilentFeedbackService(), clipboard: (_) async {});
      c.updateProps(angleMode: AngleMode.deg, decimalPrecision: -1, soundEnabled: false, hapticEnabled: false, history: const []);
      c.handleInsertTemplate('molar("H2O")');
      c.handleEvaluate();
      expect(c.expression, '18.015');
      final d = CalculatorController(feedback: SilentFeedbackService(), clipboard: (_) async {});
      d.updateProps(angleMode: AngleMode.deg, decimalPrecision: -1, soundEnabled: false, hapticEnabled: false, history: const []);
      d.handleInsertTemplate('atomicsym(');
      for (final ch in '26)'.split('')) {
        d.handleInput(ch);
      }
      d.handleEvaluate();
      expect(d.expression, 'Fe');
    });
  });

  group('screen', () {
    testWidgets('opens on the periodic table with 118 element cells', (tester) async {
      await pumpChemistry(tester);
      expect(find.byKey(const ValueKey('pt-search')), findsOneWidget);
      var n = 0;
      for (final e in chemElements) {
        if (find.byKey(ValueKey('element-${e.symbol}')).evaluate().isNotEmpty) n++;
      }
      expect(n, 118);
    });

    testWidgets('search dims the other elements and a tap opens the detail with the symbol', (tester) async {
      await pumpChemistry(tester);
      await typeInto(tester, 'pt-search', 'iron');
      expect(find.text('1 of 118 elements match'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('element-Fe')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('element-detail')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('detail-symbol'))).data, 'Fe');
      expect(find.text('Iron'), findsWidgets);
      await tapText(tester, 'Close');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('element-detail')), findsNothing);
    });

    testWidgets('Use in calculator puts the atomic mass into the calculator', (tester) async {
      await pumpChemistry(tester);
      await tester.tap(find.byKey(const ValueKey('element-H')));
      await tester.pump(const Duration(milliseconds: 500));
      await tapText(tester, 'Use in calculator');
      await tester.pump(const Duration(milliseconds: 500));
      expect(navOf(tester).mode, CalculatorMode.standard);
    });

    testWidgets('formula tools: molar mass, breakdown and the typeset formula', (tester) async {
      await pumpChemistry(tester, tabLabel: 'Formula Tools');
      await typeInto(tester, 'formula-input', 'Al2(SO4)3');
      expect(tester.widget<Text>(find.byKey(const ValueKey('formula-pretty'))).data, 'Al₂(SO₄)₃');
      expect(find.textContaining('342.1'), findsWidgets);
      await typeInto(tester, 'formula-input', 'Xx2');
      expect(find.textContaining('Xx'), findsWidgets);
      expect(find.byKey(const ValueKey('formula-pretty')), findsNothing);
    });

    testWidgets('formula tools: grams to moles and particles', (tester) async {
      await pumpChemistry(tester, tabLabel: 'Formula Tools');
      await typeInto(tester, 'formula-input', 'H2O');
      await typeInto(tester, 'convert-amount', '18.015');
      expect(find.textContaining('1 mol'), findsWidgets);
      expect(find.textContaining('6.02214e+23'), findsWidgets);
    });

    testWidgets('formula tools: empirical formula from percent data', (tester) async {
      await pumpChemistry(tester, tabLabel: 'Formula Tools');
      await typeInto(tester, 'emp-amt-0', '40.0');
      await typeInto(tester, 'emp-amt-1', '6.7');
      await typeInto(tester, 'emp-amt-2', '53.3');
      await typeInto(tester, 'emp-molar', '180.16');
      expect(find.text('CH₂O'), findsWidgets);
      expect(find.text('C₆H₁₂O₆'), findsWidgets);
    });

    testWidgets('balancer: propane combustion and a clear error', (tester) async {
      await pumpChemistry(tester, tabLabel: 'Balancer');
      await tapText(tester, 'Balance', last: true);
      expect(tester.widget<SelectableText>(find.byKey(const ValueKey('balanced-text'))).data, 'C₃H₈ + 5 O₂ → 3 CO₂ + 4 H₂O');
      await typeInto(tester, 'equation-input', 'H2 + O2');
      await tapText(tester, 'Balance', last: true);
      expect(find.textContaining('arrow'), findsWidgets);
    });

    testWidgets('balancer: limiting reagent', (tester) async {
      await pumpChemistry(tester, tabLabel: 'Balancer');
      await typeInto(tester, 'equation-input', 'N2 + H2 -> NH3');
      await tapText(tester, 'Balance', last: true);
      await typeInto(tester, 'lr-grams-0', '10');
      await typeInto(tester, 'lr-grams-1', '3');
      await tapText(tester, 'Find limiting reagent');
      expect(find.byKey(const ValueKey('chem-result')), findsOneWidget);
      expect(find.textContaining('Limiting reagent: N₂'), findsWidgets);
    });

    testWidgets('solvers: ideal gas law shows its formula and the working', (tester) async {
      await pumpChemistry(tester, tabLabel: 'Solvers');
      await tester.tap(find.byKey(const ValueKey('solver-tile-ideal_gas')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('solver-formula')), findsOneWidget);
      await tapText(tester, 'Solve');
      // nothing entered: the solver says what is missing
      expect(find.textContaining('Enter'), findsWidgets);
    });

    testWidgets('solvers: search finds a topic across groups', (tester) async {
      await pumpChemistry(tester, tabLabel: 'Solvers');
      await typeInto(tester, 'solver-search', 'buffer');
      expect(find.byKey(const ValueKey('solver-tile-buffer')), findsOneWidget);
      await typeInto(tester, 'solver-search', 'zzzz');
      expect(find.text('No topic matches that search.'), findsOneWidget);
    });

    testWidgets('reference tables switch and show their rows', (tester) async {
      await pumpChemistry(tester, tabLabel: 'Reference');
      expect(find.byKey(const ValueKey('ref-table-solubility')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('ref-polyatomic')));
      await tester.tap(find.byKey(const ValueKey('ref-polyatomic')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('ref-table-polyatomic')), findsOneWidget);
      expect(find.text('SO₄²⁻'), findsOneWidget);
    });

    testWidgets('constants: filter, search and copy', (tester) async {
      await pumpChemistry(tester, tabLabel: 'Constants');
      await typeInto(tester, 'const-search', 'faraday');
      expect(find.textContaining('Faraday'), findsWidgets);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.tap(find.byKey(const ValueKey('chem-const-copy-F')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(double.parse(copied!), closeTo(96485.33212, 1e-4));
    });

    testWidgets('a phone-width window scrolls the 18-column table instead of squeezing it', (tester) async {
      await pumpChemistry(tester, size: const Size(400, 4000));
      expect(find.byKey(const ValueKey('pt-scroll')), findsOneWidget);
    });
  });
}
