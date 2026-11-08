import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/services/feedback_service.dart';
import 'package:omnicalc/state/drawer_layout.dart';
import 'package:omnicalc/theme/tokens.dart';
import 'package:omnicalc/ui/calculator/advanced_keys.dart';
import 'package:omnicalc/ui/calculator/calculator_controller.dart';
import 'package:omnicalc/ui/calculator/customize_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late CalculatorController c;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DrawerLayout.instance.load();
    DrawerLayout.instance.resetAll();
    c = CalculatorController(feedback: SilentFeedbackService(), clipboard: (_) async {});
  });

  test('default order is the built-in order; reordering tabs and keys is remembered and reset restores it', () async {
    final l = DrawerLayout.instance;
    expect(l.tabs, [for (final d in advancedTabDefs) d.id]);
    l.setTabOrder([AdvancedTab.data, ...l.tabs.where((t) => t != AdvancedTab.data)]);
    expect(l.tabs.first, AdvancedTab.data);
    expect(l.tabs.length, advancedTabDefs.length);

    final entries = advancedKeyEntries(AdvancedTab.calculus, c);
    final ids = [for (final e in entries) e.id];
    expect(ids.toSet().length, ids.length);
    l.setKeyOrder(AdvancedTab.calculus, [ids.last, ...ids.take(ids.length - 1)]);
    expect(l.keyIndexes(AdvancedTab.calculus, ids).first, ids.length - 1);

    // saved on the phone and read back
    final prefs = await SharedPreferences.getInstance();
    await l.load(prefs);
    expect(l.tabs.first, AdvancedTab.data);
    expect(l.keyIndexes(AdvancedTab.calculus, ids).first, ids.length - 1);

    // a key missing from the saved order is appended, an unknown one is ignored
    l.setKeyOrder(AdvancedTab.calculus, ['nope|x', ids[2]]);
    final idx = l.keyIndexes(AdvancedTab.calculus, ids);
    expect(idx.first, 2);
    expect(idx.length, ids.length);

    l.resetAll();
    expect(l.tabs, [for (final d in advancedTabDefs) d.id]);
    expect(l.keyIndexes(AdvancedTab.calculus, ids), List.generate(ids.length, (i) => i));
  });

  test('[ and ] move through the pills in the user\'s order', () {
    DrawerLayout.instance.setTabOrder([AdvancedTab.data, AdvancedTab.calculus, AdvancedTab.trig]);
    c.selectTab(AdvancedTab.data);
    c.handleKeyDown(']');
    expect(c.advancedTab, AdvancedTab.calculus);
    c.handleKeyDown('[');
    expect(c.advancedTab, AdvancedTab.data);
  });

  testWidgets('dragging a pill handle in the Customize sheet reorders the pills', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: M3Theme(tokens: staticTokens('iris', isDark: false), child: Scaffold(body: CustomizeDrawerSheet(controller: c)))));
    final first = DrawerLayout.instance.tabs.first;
    final second = DrawerLayout.instance.tabs[1];
    final handle = find.byKey(ValueKey('customize-tab-handle-${first.name}'));
    final g = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    await g.moveBy(const Offset(0, 120));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(DrawerLayout.instance.tabs[1], first);
    expect(DrawerLayout.instance.tabs.first, second);
    expect(find.byKey(const ValueKey('customize-reset-all')), findsOneWidget);
  });
}
