// Phase 8c (row A18): SETUP > CONT dims the calculator display; level 5 adds nothing to the tree.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/state/casio_settings.dart';

import 'calculator_screen_test.dart' show pumpApp, settle;

void main() {
  tearDown(() => CasioRuntime.instance.reset());

  testWidgets('the display is drawn at full strength by default (no Opacity wrapper)', (tester) async {
    await pumpApp(tester);
    await settle(tester);
    expect(find.byKey(const ValueKey('display-contrast')), findsNothing);
  });

  testWidgets('contrast 1 and 3 fade the display to 40% and 70%, and back to 5 removes the wrapper', (tester) async {
    await pumpApp(tester);
    await settle(tester);
    CasioRuntime.instance.update((c) => c.copyWith(contrast: 1));
    await tester.pump();
    expect(tester.widget<Opacity>(find.byKey(const ValueKey('display-contrast'))).opacity, closeTo(0.4, 1e-9));
    CasioRuntime.instance.update((c) => c.copyWith(contrast: 3));
    await tester.pump();
    expect(tester.widget<Opacity>(find.byKey(const ValueKey('display-contrast'))).opacity, closeTo(0.7, 1e-9));
    CasioRuntime.instance.update((c) => c.copyWith(contrast: 5));
    await tester.pump();
    expect(find.byKey(const ValueKey('display-contrast')), findsNothing);
  });
}
