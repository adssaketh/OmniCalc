import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/state/history_store.dart';
import 'package:omnicalc/state/navigation_state.dart';
import 'package:omnicalc/ui/overlays/history_tape_sheet.dart';

import '../shell_test.dart' show Harness, navOf, pumpApp, settle;

Future<Harness> openHistory(WidgetTester tester, {bool seed = true, Size size = const Size(400, 800)}) async {
  final h = await pumpApp(tester, size: size);
  if (seed) {
    h.history.add(id: 'a', expression: '2+3', result: '5', mode: 'calc', timestamp: 1000);
    h.history.add(id: 'b', expression: 'v=u+at', result: '12', mode: 'physics', timestamp: 2000);
    h.history.add(id: 'c', expression: 'sin(30)', result: '0.5', mode: 'scientific', timestamp: 3000);
    h.history.add(id: 'd', expression: '7×6', result: '42', timestamp: 4000);
  }
  navOf(tester).setHistoryOpen(true);
  await settle(tester);
  return h;
}

/// The chips scroll sideways and the list scrolls down, like on the phone: bring the control into view first.
Future<void> tapVisible(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pump();
  await tester.tap(find.byKey(key));
}

void main() {
  group('helpers', () {
    test('calculator and physics entries', () {
      HistoryItem item(String? mode) => HistoryItem(id: 'x', expression: '1', result: '1', timestamp: 0, mode: mode);
      for (final m in ['calc', 'standard', 'scientific', null]) {
        expect(isCalcHistoryItem(item(m)), true, reason: '$m');
        expect(isPhysicsHistoryItem(item(m)), false, reason: '$m');
      }
      expect(isCalcHistoryItem(item('physics')), false);
      expect(isPhysicsHistoryItem(item('physics')), true);
      expect(isCalcHistoryItem(item('converter')), false);
    });

    test('time is HH:mm:ss and the export has one line per entry', () {
      final ts = DateTime(2026, 1, 2, 3, 4, 5).millisecondsSinceEpoch;
      expect(historyTimeText(ts), '03:04:05');
      final items = [
        HistoryItem(id: 'a', expression: '1+1', result: '2', timestamp: ts, mode: 'calc'),
        HistoryItem(id: 'b', expression: '2×2', result: '4', timestamp: ts),
      ];
      expect(historyExportText(items), '[03:04:05] 1+1 = 2 (calc)\n[03:04:05] 2×2 = 4 (calc)');
      expect(historyExportText(const []), '');
    });
  });

  group('sheet', () {
    testWidgets('closed until opened, then lists newest first with the counts', (tester) async {
      final h = await pumpApp(tester);
      h.history.add(id: 'a', expression: '2+3', result: '5', mode: 'calc');
      await settle(tester);
      expect(find.text('Recent Calculations'), findsNothing);
      navOf(tester).setHistoryOpen(true);
      await settle(tester);
      expect(find.text('Recent Calculations'), findsOneWidget);
      expect(find.text('1 saved on this device'), findsOneWidget);
      expect(find.byKey(const ValueKey('history-item-a')), findsOneWidget);
    });

    testWidgets('filters: All, Calculator and Physics', (tester) async {
      await openHistory(tester);
      expect(find.text('4 saved on this device'), findsOneWidget);
      for (final id in ['a', 'b', 'c', 'd']) {
        expect(find.byKey(ValueKey('history-item-$id')), findsOneWidget, reason: id);
      }
      await tapVisible(tester, const ValueKey('history-filter-physics'));
      await settle(tester);
      expect(find.byKey(const ValueKey('history-item-b')), findsOneWidget);
      expect(find.byKey(const ValueKey('history-item-a')), findsNothing);
      await tapVisible(tester, const ValueKey('history-filter-calc'));
      await settle(tester);
      expect(find.byKey(const ValueKey('history-item-b')), findsNothing);
      for (final id in ['a', 'c', 'd']) {
        expect(find.byKey(ValueKey('history-item-$id')), findsOneWidget, reason: id);
      }
      await tapVisible(tester, const ValueKey('history-filter-all'));
      await settle(tester);
      expect(find.byKey(const ValueKey('history-item-b')), findsOneWidget);
    });

    testWidgets('an empty filter shows the empty state', (tester) async {
      final h = await openHistory(tester, seed: false);
      h.history.add(id: 'a', expression: '1+1', result: '2', mode: 'calc');
      await settle(tester);
      await tapVisible(tester, const ValueKey('history-filter-physics'));
      await settle(tester);
      expect(find.text('No calculations here yet'), findsOneWidget);
    });

    testWidgets('nothing saved: no export and no clear buttons', (tester) async {
      await openHistory(tester, seed: false);
      expect(find.byKey(const ValueKey('history-export')), findsNothing);
      expect(find.byKey(const ValueKey('history-clear')), findsNothing);
      expect(find.text('No calculations here yet'), findsOneWidget);
    });

    testWidgets('copy puts "expression = result" on the clipboard', (tester) async {
      await openHistory(tester);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tapVisible(tester, const ValueKey('history-copy-a'));
      await tester.pump();
      expect(copied, '2+3 = 5');
      await tester.pump(const Duration(milliseconds: 2000)); // the "copied" tick goes away
    });

    testWidgets('Use sends the result to the calculator and closes the sheet', (tester) async {
      await openHistory(tester);
      await tapVisible(tester, const ValueKey('history-use-a'));
      await settle(tester);
      final nav = navOf(tester);
      expect(nav.externalExpression, '5');
      expect(nav.mode, CalculatorMode.standard);
      expect(nav.isHistoryOpen, false);
    });

    testWidgets('Formula sends the expression and closes the sheet', (tester) async {
      await openHistory(tester);
      await tapVisible(tester, const ValueKey('history-formula-a'));
      await settle(tester);
      final nav = navOf(tester);
      expect(nav.externalExpression, '2+3');
      expect(nav.isHistoryOpen, false);
    });

    testWidgets('export hands the text to the exporter', (tester) async {
      await openHistory(tester);
      // the real sheet uses the clipboard exporter: make sure it does not throw
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.tap(find.byKey(const ValueKey('history-export')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('clear asks for confirmation, then empties the tape', (tester) async {
      // 630 wide: the test font (Ahem) is far wider than the real one, and with the "Clear All?" pill the title would be
      // squeezed to one letter per line at 400 (the web header does the same, it has no truncation either)
      final h = await openHistory(tester, size: const Size(630, 800));
      await tester.tap(find.byKey(const ValueKey('history-clear')));
      await settle(tester);
      expect(find.byKey(const ValueKey('history-clear-confirm')), findsOneWidget);
      expect(h.history.items.length, 4);
      await tester.tap(find.byKey(const ValueKey('history-clear-confirm')));
      await settle(tester);
      expect(h.history.items, isEmpty);
      expect(find.text('0 saved on this device'), findsOneWidget);
    });

    testWidgets('the X and the Close button close the sheet', (tester) async {
      await openHistory(tester);
      await tester.tap(find.byKey(const ValueKey('history-close-x')));
      await settle(tester);
      expect(navOf(tester).isHistoryOpen, false);
      navOf(tester).setHistoryOpen(true);
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('history-close')));
      await settle(tester);
      expect(navOf(tester).isHistoryOpen, false);
    });

    testWidgets('back closes the sheet', (tester) async {
      await openHistory(tester);
      expect(navOf(tester).handleBack(), BackAction.closedHistory);
      await settle(tester);
      expect(find.text('Recent Calculations'), findsNothing);
    });
  });
}
