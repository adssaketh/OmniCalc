@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/config.dart';
import 'package:omnicalc/state/casio_settings.dart';
import 'package:omnicalc/theme/tokens.dart';
import 'package:omnicalc/ui/calculator/ineq_dist_panels.dart';

// Screenshot goldens of the Phase 7e screens (INEQ result, DIST list result). The real calculator has no TypeScript oracle, so a
// baseline is a regression picture rendered by this app, not a parity reference. Create or refresh them with
//   flutter test --tags golden --update-goldens test/ui/golden_casio_7e_test.dart
// and compare with `flutter test --tags golden`. A baseline that is not committed yet is reported as skipped.
Future<void> shot(WidgetTester tester, String name, Widget panel, Future<void> Function() act) async {
  if (!File('test/goldens/casio/$name.png').existsSync() && !autoUpdateGoldenFiles) {
    markTestSkipped('no baseline test/goldens/casio/$name.png yet');
    return;
  }
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: M3Theme(tokens: staticTokens('iris', isDark: false), child: Scaffold(body: panel)),
  ));
  await act();
  await expectLater(find.byType(Scaffold), matchesGoldenFile('../goldens/casio/$name.png'));
}

void main() {
  testWidgets('ineq_example1', (tester) async {
    Future<void> act() async {
      await tester.tap(find.byKey(const ValueKey('ineq-rel-lt')));
      await tester.enterText(find.byKey(const ValueKey('ineq-cell-0')), '1');
      await tester.enterText(find.byKey(const ValueKey('ineq-cell-1')), '2');
      await tester.enterText(find.byKey(const ValueKey('ineq-cell-2')), '-3');
      await tester.tap(find.byKey(const ValueKey('ineq-solve')));
      await tester.pump();
    }

    await shot(tester, 'ineq_example1', IneqPanel(onClose: () {}), act);
  });

  // O04: Linear Display layout of the INEQ answer (guide p.82-84, Example 4): the header, then A=, B=, C= with their values
  testWidgets('ineq_linear_example4', (tester) async {
    final engine = CasioRuntime.instance.engine;
    final saved = engine.config;
    engine.config = saved.copyWith(displayFormat: CasioDisplayFormat.lineIO);
    addTearDown(() => engine.config = saved);
    Future<void> act() async {
      await tester.tap(find.byKey(const ValueKey('ineq-type-cubic')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('ineq-rel-gt')));
      await tester.enterText(find.byKey(const ValueKey('ineq-cell-0')), '3');
      await tester.enterText(find.byKey(const ValueKey('ineq-cell-1')), '3');
      await tester.enterText(find.byKey(const ValueKey('ineq-cell-2')), '-1');
      await tester.tap(find.byKey(const ValueKey('ineq-solve')));
      await tester.pump();
    }

    await shot(tester, 'ineq_linear_example4', IneqPanel(onClose: () {}), act);
  });

  testWidgets('dist_binomial_list', (tester) async {
    Future<void> act() async {
      await tester.tap(find.byKey(const ValueKey('dist-type-binomPd')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('dist-mode-list')));
      await tester.pump();
      for (var i = 1; i < 5; i++) {
        await tester.tap(find.byKey(const ValueKey('dist-ins')));
        await tester.pump();
      }
      for (var i = 0; i < 5; i++) {
        await tester.enterText(find.byKey(ValueKey('dist-sample-$i')), '${10 + i}');
      }
      await tester.enterText(find.byKey(const ValueKey('dist-var-1')), '15');
      await tester.enterText(find.byKey(const ValueKey('dist-var-2')), '0.6');
      await tester.tap(find.byKey(const ValueKey('dist-calc')));
      await tester.pump();
    }

    await shot(tester, 'dist_binomial_list', DistPanel(onClose: () {}), act);
  });
}
