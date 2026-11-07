import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/cval.dart';
import 'package:omnicalc/engine/casio/matrix.dart';
import 'package:omnicalc/engine/casio/stat.dart';
import 'package:omnicalc/engine/types.dart';
import 'package:omnicalc/services/feedback_service.dart';
import 'package:omnicalc/state/casio_settings.dart';
import 'package:omnicalc/theme/tokens.dart';
import 'package:omnicalc/ui/calculator/calculator_controller.dart';
import 'package:omnicalc/ui/calculator/data_sheets.dart';

/// Phase 7d-2: STAT, MATRIX, VECTOR and TABLE at controller level and the sheets.
void main() {
  CalculatorController make() {
    final c = CalculatorController(feedback: SilentFeedbackService(), clipboard: (text) async {}, engine: CasioRuntime.instance.engine);
    c.updateProps(angleMode: AngleMode.deg, decimalPrecision: -1, soundEnabled: true, hapticEnabled: true, history: const []);
    return c;
  }

  void type(CalculatorController c, String s) {
    for (final ch in s.split('')) {
      c.handleInput(ch);
    }
  }

  CVal i(int v) => CVal.int(v);

  setUp(() => CasioRuntime.instance.reset());

  group('controller', () {
    test('STAT: annunciator, data, 1-VAR results', () {
      final c = make();
      var editors = 0;
      c.onOpenStatEditor = () => editors++;
      c.enterStat(StatType.oneVar);
      expect(editors, 1);
      expect(c.mode, CasioMode.stat);
      expect(c.annunciators, contains('STAT'));
      for (var k = 0; k < 5; k++) {
        c.statData.xs[k] = i(k + 1);
      }
      type(c, 'Σx');
      c.handleEvaluate();
      expect(c.lastAnswer, '15');
      c.handleClear();
      type(c, 'x̄');
      c.handleEvaluate();
      expect(c.lastAnswer, '3');
      c.handleClear();
      type(c, 'n');
      c.handleEvaluate();
      expect(c.lastAnswer, '5');
    });

    test('STAT: changing between paired types keeps the data, 1-VAR to paired clears it', () {
      final c = make();
      c.enterStat(StatType.linear);
      c.statData.xs[0] = i(1);
      c.statData.ys[0] = i(2);
      c.changeStatType(StatType.quadratic);
      expect(c.statData.xs[0]?.v, 1);
      expect(c.statData.ys[0]?.v, 2);
      c.changeStatType(StatType.oneVar);
      expect(c.statData.xs[0], isNull);
    });

    test('STAT: regression coefficients and the estimate', () {
      final c = make();
      c.enterStat(StatType.linear);
      final xs = [1, 2, 3, 4], ys = [3, 5, 7, 9];
      for (var k = 0; k < 4; k++) {
        c.statData.xs[k] = i(xs[k]);
        c.statData.ys[k] = i(ys[k]);
      }
      type(c, 'RegA');
      c.handleEvaluate();
      expect(c.lastAnswer, '1');
      c.handleClear();
      type(c, 'RegB');
      c.handleEvaluate();
      expect(c.lastAnswer, '2');
    });

    test('leaving STAT clears the data', () {
      final c = make();
      c.enterStat(StatType.oneVar);
      c.statData.xs[0] = i(4);
      c.setMode(CasioMode.comp);
      expect(c.annunciators, isNot(contains('STAT')));
      c.enterStat(StatType.oneVar);
      expect(c.statData.xs[0], isNull);
    });

    test('MATRIX: MatA×MatB opens the result, MatAns continues', () {
      final c = make();
      var shown = 0;
      c.onShowMatVecResult = () => shown++;
      c.enterMatrix();
      expect(c.annunciators, contains('MAT'));
      c.matVec.mats['MatA'] = CMatrix(2, 2, [i(2), i(1), i(1), i(1)]);
      c.matVec.mats['MatB'] = CMatrix(2, 2, [i(2), i(1), i(1), i(2)]);
      type(c, 'MatA×MatB');
      c.handleEvaluate();
      expect(shown, 1);
      expect(c.matrixResult?.cells.map((v) => v.v).toList(), [5, 4, 3, 3]);
      c.handleClear();
      type(c, 'det(MatA)');
      c.handleEvaluate();
      expect(c.lastAnswer, '1');
      expect(shown, 1);
    });

    test('MATRIX: an unset matrix is a Dimension ERROR', () {
      final c = make();
      c.enterMatrix();
      type(c, 'MatA+MatB');
      c.handleEvaluate();
      expect(c.lastAnswer, contains('Dimension'));
    });

    test('VECTOR: Dot product and annunciator', () {
      final c = make();
      c.enterVector();
      expect(c.annunciators, contains('VCT'));
      c.matVec.vecs['VctA'] = CVector([i(1), i(2)]);
      c.matVec.vecs['VctB'] = CVector([i(3), i(4)]);
      type(c, 'VctA Dot VctB');
      c.handleEvaluate();
      expect(c.lastAnswer, '11');
    });

    test('TABLE: = opens the table sheet', () {
      final c = make();
      var opened = 0;
      c.onOpenTable = () => opened++;
      c.enterTable();
      expect(opened, 1);
      type(c, 'X²');
      c.handleEvaluate();
      expect(opened, 2);
      expect(c.tableF, 'X²');
    });

    test('MODE name and the Data tab', () {
      final c = make();
      expect(c.modeName, 'COMP');
      c.enterTable();
      expect(c.modeName, 'TABLE');
      expect(advancedTabDefs.last.id, AdvancedTab.data);
    });
  });

  group('sheets', () {
    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: M3Theme(tokens: staticTokens('iris', isDark: false), child: Scaffold(body: child)),
      ));
    }

    testWidgets('Statistics Editor: typing a value stores it; Ins and Del move rows', (tester) async {
      final c = make();
      c.enterStat(StatType.oneVar);
      await pump(tester, StatEditor(controller: c, onClose: () {}));
      await tester.enterText(find.byKey(const ValueKey('stat-cell-0-0')), '5');
      await tester.enterText(find.byKey(const ValueKey('stat-cell-1-0')), '7');
      expect(c.statData.xs[0]?.v, 5);
      expect(c.statData.xs[1]?.v, 7);
      await tester.tap(find.byKey(const ValueKey('stat-cell-0-0')));
      await tester.tap(find.byKey(const ValueKey('stat-ins')));
      await tester.pump();
      expect(c.statData.xs[0], isNull);
      expect(c.statData.xs[1]?.v, 5);
      await tester.tap(find.byKey(const ValueKey('stat-del')));
      await tester.pump();
      expect(c.statData.xs[0]?.v, 5);
      await tester.tap(find.byKey(const ValueKey('stat-delall')));
      await tester.pump();
      expect(c.statData.xs[0], isNull);
    });

    testWidgets('Statistics Editor: a bad entry shows an error', (tester) async {
      final c = make();
      c.enterStat(StatType.oneVar);
      await pump(tester, StatEditor(controller: c, onClose: () {}));
      await tester.enterText(find.byKey(const ValueKey('stat-cell-0-0')), '5+');
      await tester.pump();
      expect(find.byKey(const ValueKey('stat-msg')), findsOneWidget);
    });

    testWidgets('Matrix editor: Dim, fill, and the matrix is stored', (tester) async {
      final c = make();
      await pump(tester, MatVecEditor(controller: c, vector: false, onClose: () {}));
      expect(find.byKey(const ValueKey('mv-dim')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mv-dim-2-2')));
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('mv-cell-0-1')), '3');
      await tester.enterText(find.byKey(const ValueKey('mv-cell-1-1')), '1÷2');
      final m = c.matVec.mats['MatA']!;
      expect((m.rows, m.cols), (2, 2));
      expect(m.cells[1].v, 3);
      expect(m.cells[3].v, 0.5);
    });

    testWidgets('Matrix editor: 4×4 does not exist; vector Dim 3', (tester) async {
      final c = make();
      await pump(tester, MatVecEditor(controller: c, vector: true, onClose: () {}));
      expect(find.byKey(const ValueKey('mv-dim-4')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('mv-dim-3')));
      await tester.pump();
      expect(c.matVec.vecs['VctA']!.dim, 3);
    });

    testWidgets('Result screen shows the cells and STO copies to MatC', (tester) async {
      final c = make();
      c.enterMatrix();
      c.matVec.mats['MatA'] = CMatrix(2, 2, [i(2), i(1), i(1), i(1)]);
      type(c, 'MatA²');
      c.handleEvaluate();
      await pump(tester, MatVecResult(controller: c, onClose: () {}));
      expect(find.text('5'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('res-sto-MatC')));
      await tester.pump();
      expect(c.matVec.mats['MatC']!.cells.map((v) => v.v).toList(), [5, 3, 3, 2]);
    });

    testWidgets('Table sheet: the manual defaults generate five rows; End ≤ Start is an error', (tester) async {
      final c = make();
      await pump(tester, TableSheet(controller: c, onClose: () {}));
      await tester.enterText(find.byKey(const ValueKey('table-f')), 'x²');
      await tester.tap(find.byKey(const ValueKey('table-go')));
      await tester.pump();
      expect(find.byKey(const ValueKey('table-f-4')), findsOneWidget);
      expect((tester.widget(find.byKey(const ValueKey('table-f-4'))) as Text).data, '25');
      await tester.enterText(find.byKey(const ValueKey('table-end')), '1');
      await tester.tap(find.byKey(const ValueKey('table-go')));
      await tester.pump();
      expect(find.byKey(const ValueKey('table-msg')), findsOneWidget);
    });
  });
}
