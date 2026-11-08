// EQN solution screen (manual p.71): one solution per `=`, ▲ ▼ scroll, the last `=` returns to the Coefficient Editor. Row K06.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/state/casio_settings.dart';
import 'package:omnicalc/theme/tokens.dart';
import 'package:omnicalc/ui/calculator/mode_menu.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: M3Theme(tokens: staticTokens('iris', isDark: false), child: Scaffold(body: EqnPanel(onClose: () {}))),
    ));
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pump();
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    await tester.enterText(find.byKey(ValueKey(key)), text);
    await tester.pump();
  }

  String position(WidgetTester tester) => (tester.widget(find.byKey(const ValueKey('eqn-position'))) as Text).data!;

  // manual example 1: x + 2y = 3, 2x + 3y = 4 gives X=-1, Y=2
  Future<void> solveSimul2(WidgetTester tester) async {
    await pump(tester);
    await enter(tester, 'eqn-cell-0-0', '1');
    await enter(tester, 'eqn-cell-0-1', '2');
    await enter(tester, 'eqn-cell-0-2', '3');
    await enter(tester, 'eqn-cell-1-0', '2');
    await enter(tester, 'eqn-cell-1-1', '3');
    await enter(tester, 'eqn-cell-1-2', '4');
    await tap(tester, 'eqn-solve');
  }

  setUp(() => CasioRuntime.instance.reset());

  testWidgets('only the first solution is shown, with its position', (tester) async {
    await solveSimul2(tester);
    expect(find.textContaining('X='), findsOneWidget);
    expect(find.textContaining('Y='), findsNothing);
    expect(position(tester), '1 / 2');
  });

  testWidgets('= shows the next solution: X=-1 then Y=2', (tester) async {
    await solveSimul2(tester);
    expect(find.textContaining('X= -1'), findsOneWidget);
    await tap(tester, 'eqn-next');
    expect(find.textContaining('Y= 2'), findsOneWidget);
    expect(position(tester), '2 / 2');
  });

  testWidgets('= on the last solution returns to the Coefficient Editor', (tester) async {
    await solveSimul2(tester);
    await tap(tester, 'eqn-next');
    await tap(tester, 'eqn-next');
    expect(find.byKey(const ValueKey('eqn-position')), findsNothing);
    expect(find.byKey(const ValueKey('eqn-cell-0-0')), findsOneWidget);
  });

  testWidgets('▲ ▼ scroll between the solutions and stop at the ends', (tester) async {
    await solveSimul2(tester);
    await tap(tester, 'eqn-up');
    expect(position(tester), '1 / 2');
    await tap(tester, 'eqn-down');
    expect(position(tester), '2 / 2');
    await tap(tester, 'eqn-down');
    expect(position(tester), '2 / 2');
    await tap(tester, 'eqn-up');
    expect(position(tester), '1 / 2');
  });

  testWidgets('AC goes back to the Coefficient Editor and keeps the coefficients', (tester) async {
    await solveSimul2(tester);
    await tap(tester, 'eqn-editor');
    expect(find.byKey(const ValueKey('eqn-position')), findsNothing);
    final cell = tester.widget<TextField>(find.byKey(const ValueKey('eqn-cell-1-2')));
    expect(cell.controller!.text, '4');
  });

  testWidgets('a quadratic has its roots and the vertex as separate screens (manual p.72 example 3)', (tester) async {
    await pump(tester);
    await tap(tester, 'eqn-type-quadratic');
    await enter(tester, 'eqn-cell-0-0', '2');
    await enter(tester, 'eqn-cell-0-1', '-3');
    await enter(tester, 'eqn-cell-0-2', '-6');
    await tap(tester, 'eqn-solve');
    expect(position(tester), '1 / 4');
    await tap(tester, 'eqn-next');
    await tap(tester, 'eqn-next');
    expect(find.textContaining('Minimum'), findsOneWidget);
  });
}
