// Phase 7e screens: the INEQ and DIST panels, the new MODE menu entries and the CLR menu.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/config.dart';
import 'package:omnicalc/engine/casio/cval.dart';
import 'package:omnicalc/engine/types.dart';
import 'package:omnicalc/services/feedback_service.dart';
import 'package:omnicalc/state/casio_settings.dart';
import 'package:omnicalc/theme/tokens.dart';
import 'package:omnicalc/ui/calculator/calculator_controller.dart';
import 'package:omnicalc/ui/calculator/ineq_dist_panels.dart';
import 'package:omnicalc/ui/calculator/mode_menu.dart';

void main() {
  CalculatorController make() {
    final c = CalculatorController(feedback: SilentFeedbackService(), clipboard: (text) async {}, engine: CasioRuntime.instance.engine);
    c.updateProps(angleMode: AngleMode.deg, decimalPrecision: -1, soundEnabled: true, hapticEnabled: true, history: const []);
    return c;
  }

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: M3Theme(tokens: staticTokens('iris', isDark: false), child: Scaffold(body: child)),
    ));
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    await tester.enterText(find.byKey(ValueKey(key)), text);
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pump();
  }

  String text(WidgetTester tester, String key) => (tester.widget(find.byKey(ValueKey(key))) as Text).data!;

  setUp(() {
    CasioRuntime.instance.reset();
    CasioRuntime.instance.engine.memory.clearVariables();
  });

  group('INEQ panel', () {
    testWidgets('manual example 1: x²+2x−3 < 0 shows −3<X<1', (tester) async {
      await pump(tester, IneqPanel(onClose: () {}));
      await tap(tester, 'ineq-rel-lt');
      await enter(tester, 'ineq-cell-0', '1');
      await enter(tester, 'ineq-cell-1', '2');
      await enter(tester, 'ineq-cell-2', '-3');
      await tap(tester, 'ineq-solve');
      expect(text(tester, 'ineq-line-0'), '-3<X<1');
    });

    testWidgets('manual example 2: ≥ gives two lines', (tester) async {
      await pump(tester, IneqPanel(onClose: () {}));
      await tap(tester, 'ineq-rel-ge');
      await enter(tester, 'ineq-cell-0', '1');
      await enter(tester, 'ineq-cell-1', '2');
      await enter(tester, 'ineq-cell-2', '-3');
      await tap(tester, 'ineq-solve');
      expect(text(tester, 'ineq-line-0'), 'X≤-3');
      expect(text(tester, 'ineq-line-1'), '1≤X');
    });

    testWidgets('manual example 3 (cubic): 2x³−3x² ≥ 0', (tester) async {
      await pump(tester, IneqPanel(onClose: () {}));
      await tap(tester, 'ineq-type-cubic');
      await tap(tester, 'ineq-rel-ge');
      await enter(tester, 'ineq-cell-0', '2');
      await enter(tester, 'ineq-cell-1', '-3');
      await tap(tester, 'ineq-solve');
      expect(text(tester, 'ineq-line-0'), 'X=0');
      expect(text(tester, 'ineq-line-1'), '3⌟2≤X');
    });

    testWidgets('special results: All Real Numbers and No-Solution', (tester) async {
      await pump(tester, IneqPanel(onClose: () {}));
      await tap(tester, 'ineq-rel-ge');
      await enter(tester, 'ineq-cell-0', '1');
      await tap(tester, 'ineq-solve');
      expect(text(tester, 'ineq-line-0'), 'All Real Numbers');
      await tap(tester, 'ineq-rel-lt');
      await tap(tester, 'ineq-solve');
      expect(text(tester, 'ineq-line-0'), 'No-Solution');
    });

    testWidgets('changing the type zeroes the coefficients; a = 0 is a Math ERROR', (tester) async {
      await pump(tester, IneqPanel(onClose: () {}));
      await enter(tester, 'ineq-cell-0', '5');
      await tap(tester, 'ineq-type-cubic');
      expect(tester.widget<TextField>(find.byKey(const ValueKey('ineq-cell-0'))).controller!.text, '0');
      expect(find.byKey(const ValueKey('ineq-cell-3')), findsOneWidget);
      await tap(tester, 'ineq-solve');
      expect(text(tester, 'ineq-message'), 'Math ERROR');
    });

    testWidgets('AC clears the coefficients', (tester) async {
      await pump(tester, IneqPanel(onClose: () {}));
      await enter(tester, 'ineq-cell-1', '9');
      await tap(tester, 'ineq-clear');
      expect(tester.widget<TextField>(find.byKey(const ValueKey('ineq-cell-1'))).controller!.text, '0');
    });

    // O04: the header line (guide p.82-84) in MathO and the Linear Display layout in LineIO.
    testWidgets('MathO: the header A<X<B sits above the solution line', (tester) async {
      await pump(tester, IneqPanel(onClose: () {}));
      await tap(tester, 'ineq-rel-lt');
      await enter(tester, 'ineq-cell-0', '1');
      await enter(tester, 'ineq-cell-1', '2');
      await enter(tester, 'ineq-cell-2', '-3');
      await tap(tester, 'ineq-solve');
      expect(text(tester, 'ineq-header'), 'A<X<B');
      expect(text(tester, 'ineq-line-0'), '-3<X<1');
      expect(find.byKey(const ValueKey('ineq-ep-name-0')), findsNothing);
    });

    testWidgets('MathO: example 2 shows the header X≤A,B≤X above X≤-3 and 1≤X', (tester) async {
      await pump(tester, IneqPanel(onClose: () {}));
      await tap(tester, 'ineq-rel-ge');
      await enter(tester, 'ineq-cell-0', '1');
      await enter(tester, 'ineq-cell-1', '2');
      await enter(tester, 'ineq-cell-2', '-3');
      await tap(tester, 'ineq-solve');
      expect(text(tester, 'ineq-header'), 'X≤A,B≤X');
      expect(text(tester, 'ineq-line-0'), 'X≤-3');
      expect(text(tester, 'ineq-line-1'), '1≤X');
    });

    testWidgets('LineIO example 2: the header, then A= -3 and B= 1', (tester) async {
      final engine = CasioRuntime.instance.engine;
      final saved = engine.config;
      engine.config = saved.copyWith(displayFormat: CasioDisplayFormat.lineIO);
      try {
        await pump(tester, IneqPanel(onClose: () {}));
        await tap(tester, 'ineq-rel-ge');
        await enter(tester, 'ineq-cell-0', '1');
        await enter(tester, 'ineq-cell-1', '2');
        await enter(tester, 'ineq-cell-2', '-3');
        await tap(tester, 'ineq-solve');
        expect(text(tester, 'ineq-header'), 'X≤A,B≤X');
        expect(text(tester, 'ineq-ep-name-0'), 'A=');
        expect(text(tester, 'ineq-ep-value-0'), '-3');
        expect(text(tester, 'ineq-ep-name-1'), 'B=');
        expect(text(tester, 'ineq-ep-value-1'), '1');
        expect(find.byKey(const ValueKey('ineq-line-0')), findsNothing);
      } finally {
        engine.config = saved;
      }
    });

    testWidgets('LineIO example 4: A<X<B,C<X with three endpoints to 10 digits', (tester) async {
      final engine = CasioRuntime.instance.engine;
      final saved = engine.config;
      engine.config = saved.copyWith(displayFormat: CasioDisplayFormat.lineIO);
      try {
        await pump(tester, IneqPanel(onClose: () {}));
        await tap(tester, 'ineq-type-cubic');
        await tap(tester, 'ineq-rel-gt');
        await enter(tester, 'ineq-cell-0', '3');
        await enter(tester, 'ineq-cell-1', '3');
        await enter(tester, 'ineq-cell-2', '-1');
        await tap(tester, 'ineq-solve');
        expect(text(tester, 'ineq-header'), 'A<X<B,C<X');
        expect(text(tester, 'ineq-ep-value-0'), '-1.263762616');
        expect(text(tester, 'ineq-ep-value-1'), '0');
        expect(text(tester, 'ineq-ep-value-2'), '0.2637626158');
        expect(text(tester, 'ineq-ep-name-2'), 'C=');
      } finally {
        engine.config = saved;
      }
    });

    testWidgets('LineIO: All Real Numbers and No-Solution look the same as in MathO, with no header', (tester) async {
      final engine = CasioRuntime.instance.engine;
      final saved = engine.config;
      engine.config = saved.copyWith(displayFormat: CasioDisplayFormat.lineIO);
      try {
        await pump(tester, IneqPanel(onClose: () {}));
        await tap(tester, 'ineq-rel-ge');
        await enter(tester, 'ineq-cell-0', '1');
        await tap(tester, 'ineq-solve');
        expect(text(tester, 'ineq-line-0'), 'All Real Numbers');
        expect(find.byKey(const ValueKey('ineq-header')), findsNothing);
        await tap(tester, 'ineq-rel-lt');
        await tap(tester, 'ineq-solve');
        expect(text(tester, 'ineq-line-0'), 'No-Solution');
        expect(find.byKey(const ValueKey('ineq-header')), findsNothing);
      } finally {
        engine.config = saved;
      }
    });

    testWidgets('changing the relation or the type hides the old header', (tester) async {
      await pump(tester, IneqPanel(onClose: () {}));
      await tap(tester, 'ineq-rel-lt');
      await enter(tester, 'ineq-cell-0', '1');
      await enter(tester, 'ineq-cell-1', '2');
      await enter(tester, 'ineq-cell-2', '-3');
      await tap(tester, 'ineq-solve');
      expect(find.byKey(const ValueKey('ineq-header')), findsOneWidget);
      await tap(tester, 'ineq-rel-gt');
      expect(find.byKey(const ValueKey('ineq-header')), findsNothing);
    });
  });

  group('DIST panel', () {
    testWidgets('manual example 1: Normal PD shows 0.1760326634', (tester) async {
      await pump(tester, DistPanel(onClose: () {}));
      await enter(tester, 'dist-var-0', '36');
      await enter(tester, 'dist-var-1', '2');
      await enter(tester, 'dist-var-2', '35');
      await tap(tester, 'dist-calc');
      expect(text(tester, 'dist-result'), '0.1760326634');
    });

    testWidgets('a result in Var format is stored in Ans', (tester) async {
      await pump(tester, DistPanel(onClose: () {}));
      await enter(tester, 'dist-var-0', '36');
      await enter(tester, 'dist-var-1', '2');
      await enter(tester, 'dist-var-2', '35');
      await tap(tester, 'dist-calc');
      expect(CasioRuntime.instance.engine.memory.ans.v, closeTo(0.1760326634, 1e-9));
    });

    testWidgets('manual example 2: Binomial PD List of 10..14, N=15, p=0.6, five digits', (tester) async {
      await pump(tester, DistPanel(onClose: () {}));
      await tap(tester, 'dist-type-binomPd');
      await tap(tester, 'dist-mode-list');
      for (var i = 1; i < 5; i++) {
        await tap(tester, 'dist-ins');
      }
      for (var i = 0; i < 5; i++) {
        await enter(tester, 'dist-sample-$i', '${10 + i}');
      }
      await enter(tester, 'dist-var-1', '15');
      await enter(tester, 'dist-var-2', '0.6');
      await tap(tester, 'dist-calc');
      expect([for (var i = 0; i < 5; i++) text(tester, 'dist-result-$i')], ['0.18594', '0.12678', '0.063388', '0.021942', '4.7018×10⁻³']);
    });

    testWidgets('a sample out of range shows ERROR in its Ans cell only', (tester) async {
      await pump(tester, DistPanel(onClose: () {}));
      await tap(tester, 'dist-type-poissonPd');
      await tap(tester, 'dist-mode-list');
      await tap(tester, 'dist-ins');
      await enter(tester, 'dist-sample-0', '2');
      await enter(tester, 'dist-sample-1', '1.5');
      await enter(tester, 'dist-var-1', '3');
      await tap(tester, 'dist-calc');
      expect(text(tester, 'dist-result-0'), '0.22404');
      expect(text(tester, 'dist-result-1'), 'ERROR');
    });

    testWidgets('the list holds 25 samples; Del and Del-A shrink it', (tester) async {
      await pump(tester, DistPanel(onClose: () {}));
      await tap(tester, 'dist-type-binomCd');
      await tap(tester, 'dist-mode-list');
      for (var i = 0; i < 30; i++) {
        await tap(tester, 'dist-ins');
      }
      expect(find.byKey(const ValueKey('dist-sample-24')), findsOneWidget);
      expect(find.byKey(const ValueKey('dist-sample-25')), findsNothing);
      await tap(tester, 'dist-del');
      expect(find.byKey(const ValueKey('dist-sample-24')), findsNothing);
      await tap(tester, 'dist-delall');
      expect(find.byKey(const ValueKey('dist-sample-1')), findsNothing);
      expect(find.byKey(const ValueKey('dist-sample-0')), findsOneWidget);
    });

    testWidgets('the Normal types have no list; Inverse Normal with Area > 1 is an Argument ERROR', (tester) async {
      await pump(tester, DistPanel(onClose: () {}));
      expect(find.byKey(const ValueKey('dist-mode-list')), findsNothing);
      await tap(tester, 'dist-type-invNorm');
      await enter(tester, 'dist-var-0', '1.5');
      await enter(tester, 'dist-var-1', '1');
      await tap(tester, 'dist-calc');
      expect(text(tester, 'dist-message'), 'Argument ERROR');
    });

    testWidgets('Inverse Normal 0.975 gives 1.959963985 (σ=1, μ=0)', (tester) async {
      await pump(tester, DistPanel(onClose: () {}));
      await tap(tester, 'dist-type-invNorm');
      await enter(tester, 'dist-var-0', '0.975');
      await enter(tester, 'dist-var-1', '1');
      await tap(tester, 'dist-calc');
      expect(text(tester, 'dist-result'), '1.959963985');
    });
  });

  group('MODE and CLR menus', () {
    testWidgets('the menu lists INEQ, VERIF and DIST after TABLE; VERIF enters the mode', (tester) async {
      final c = make();
      await pump(tester, ModeMenu(controller: c, onPick: (m) => m == CasioMode.verif ? c.enterVerif() : c.setMode(m), onEqn: () {}));
      for (final k in ['mode-ineq', 'mode-verif', 'mode-dist']) {
        expect(find.byKey(ValueKey(k)), findsOneWidget);
      }
      await tap(tester, 'mode-verif');
      expect(c.mode, CasioMode.verif);
    });

    testWidgets('CLR Memory asks first, Cancel changes nothing, Yes clears', (tester) async {
      final c = make();
      c.engine.memory.vars['A'] = CVal.int(7);
      c.engine.memory.setAns(CVal.int(5));
      await pump(tester, ClrMenu(controller: c, onClose: () {}));
      await tap(tester, 'clr-memory');
      expect(find.byKey(const ValueKey('clr-confirm-title')), findsOneWidget);
      expect(text(tester, 'clr-confirm-title'), 'Reset Memory?');
      await tap(tester, 'clr-cancel');
      expect(c.engine.memory.ans.v, 5); // Cancel only closes (here onClose does nothing), memory is untouched
      await tap(tester, 'clr-yes');
      expect(c.engine.memory.ans.v, 0);
      expect(c.engine.memory.vars['A']!.v, 0);
    });

    testWidgets('CLR Setup asks the screen to reset SETUP', (tester) async {
      final c = make();
      var reset = 0;
      c.onResetSetup = () => reset++;
      await pump(tester, ClrMenu(controller: c, onClose: () {}));
      await tap(tester, 'clr-setup');
      await tap(tester, 'clr-yes');
      expect(reset, 1);
    });
  });
}
