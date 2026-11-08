// Phase 8c (row A18): the SETUP Disp and CONT rows of the settings sheet.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/state/casio_settings.dart';
import 'package:omnicalc/ui/overlays/settings_sheet.dart';

import '../shell_test.dart' show Harness, navOf, pumpApp, settle;

Future<Harness> openSettings(WidgetTester tester) async {
  final h = await pumpApp(tester, size: const Size(630, 1000));
  navOf(tester).setSettingsOpen(true);
  await settle(tester);
  return h;
}

Finder k(String key) => find.byKey(ValueKey(key));

Future<void> tapRow(WidgetTester tester, String key) async {
  await tester.ensureVisible(k(key));
  await tester.pump();
  await tester.tap(k(key));
  await settle(tester);
}

void main() {
  tearDown(() => CasioRuntime.instance.reset());

  test('contrast labels', () {
    expect(casioContrastLabel(5), '5 (normal)');
    expect(casioContrastLabel(2), '2');
  });

  testWidgets('Decimal point (Disp) shows Dot by default and Comma after choosing it', (tester) async {
    await openSettings(tester);
    await tester.ensureVisible(k('row-disp'));
    expect(find.text('Dot in results (1.5)'), findsOneWidget);
    await tapRow(tester, 'row-disp');
    await tester.tap(find.text('Comma (,)'));
    await settle(tester);
    expect(CasioRuntime.instance.settings.commaDecimal, isTrue);
    await tester.ensureVisible(k('row-disp'));
    expect(find.text('Comma in results (1,5)'), findsOneWidget);
  });

  testWidgets('Display contrast (CONT) defaults to 5 and a lower level is saved', (tester) async {
    await openSettings(tester);
    await tester.ensureVisible(k('row-contrast'));
    expect(find.text('5 (normal)'), findsWidgets);
    await tapRow(tester, 'row-contrast');
    await tester.tap(find.text('3').last);
    await settle(tester);
    expect(CasioRuntime.instance.settings.contrast, 3);
  });

  testWidgets('Reset in Settings brings Disp and CONT back to the defaults', (tester) async {
    await openSettings(tester);
    CasioRuntime.instance.update((c) => c.copyWith(commaDecimal: true, contrast: 1));
    CasioRuntime.instance.reset();
    expect(CasioRuntime.instance.settings.commaDecimal, isFalse);
    expect(CasioRuntime.instance.settings.contrast, 5);
  });
}
