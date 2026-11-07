import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/state/navigation_state.dart';
import 'package:omnicalc/ui/widgets/m3_sheet.dart';

import '../shell_test.dart' show navOf, pumpApp, settle;

Finder handle() =>
    find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Drag down or tap to close');

void main() {
  test('dismiss rule: past 110 px, or a flick of more than 0.6 px/ms after at least 24 px', () {
    expect(kSheetDragStartPx, 6);
    expect(kSheetDismissDistancePx, 110);
    expect(kSheetDismissFlickPxPerMs, 0.6);
    expect(shouldDismissSheet(111, 0), true);
    expect(shouldDismissSheet(110, 0), false);
    expect(shouldDismissSheet(30, 0.7), true);
    expect(shouldDismissSheet(30, 0.6), false);
    expect(shouldDismissSheet(24, 2), false); // the flick needs MORE than 24 px
    expect(shouldDismissSheet(0, 5), false);
  });

  testWidgets('tapping the scrim closes a sheet', (tester) async {
    await pumpApp(tester);
    navOf(tester).setHistoryOpen(true);
    await settle(tester);
    await tester.tapAt(const Offset(200, 20)); // above the panel
    await settle(tester);
    expect(navOf(tester).isHistoryOpen, false);
  });

  testWidgets('a tap on the handle closes the sheet (phone)', (tester) async {
    await pumpApp(tester);
    navOf(tester).setHistoryOpen(true);
    await settle(tester);
    await tester.tap(handle());
    await settle(tester);
    expect(navOf(tester).isHistoryOpen, false);
  });

  testWidgets('dragging the handle down past 110 px closes the sheet', (tester) async {
    await pumpApp(tester);
    navOf(tester).setHistoryOpen(true);
    await settle(tester);
    await tester.timedDrag(handle(), const Offset(0, 200), const Duration(milliseconds: 1000));
    await settle(tester);
    expect(navOf(tester).isHistoryOpen, false);
  });

  testWidgets('a short slow drag springs back and the sheet stays open', (tester) async {
    await pumpApp(tester);
    navOf(tester).setHistoryOpen(true);
    await settle(tester);
    final before = tester.getTopLeft(find.text('Recent Calculations')).dy;
    final g = await tester.startGesture(tester.getCenter(handle()));
    await g.moveBy(const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 500));
    await g.moveBy(const Offset(0, 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getTopLeft(find.text('Recent Calculations')).dy, greaterThan(before + 20)); // it follows the finger
    await g.up();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 600));
    expect(navOf(tester).isHistoryOpen, true);
    expect(tester.getTopLeft(find.text('Recent Calculations')).dy, closeTo(before, 1));
  });

  testWidgets('from 640 px wide it is a centred card without a handle', (tester) async {
    await pumpApp(tester, size: const Size(700, 900));
    navOf(tester).setHistoryOpen(true);
    await settle(tester);
    expect(handle(), findsNothing);
    expect(navOf(tester).mode, CalculatorMode.standard);
  });
}
