import 'package:flutter/material.dart' show MaterialApp, Scaffold, TextField;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/theme/tokens.dart';
import 'package:omnicalc/ui/shell/swipeable_tab_container.dart';

const _tabs = [
  TabItem(id: 'a', label: 'Alpha'),
  TabItem(id: 'b', label: 'Beta'),
  TabItem(id: 'c', label: 'Gamma', badge: '3'),
];

Future<ValueNotifier<String>> pumpTabs(WidgetTester tester, {Widget content = const SizedBox(key: ValueKey('content'), height: 300)}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final active = ValueNotifier<String>('a');
  await tester.pumpWidget(M3Theme(
    tokens: staticTokens('m3-iris', isDark: true),
    child: MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<String>(
          valueListenable: active,
          builder: (context, id, _) => SwipeableTabContainer(
            tabs: _tabs,
            activeTabId: id,
            onSelectTab: (v) => active.value = v,
            child: content,
          ),
        ),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 400));
  return active;
}

/// Drags the content by [dx] / [dy] over [ms] milliseconds, in 10 steps.
Future<void> drag(WidgetTester tester, Offset from, double dx, {double dy = 0, int ms = 600}) async {
  final g = await tester.startGesture(from, kind: PointerDeviceKind.touch);
  var t = 0;
  for (var i = 1; i <= 10; i++) {
    t += ms ~/ 10;
    await g.moveBy(Offset(dx / 10, dy / 10), timeStamp: Duration(milliseconds: t));
  }
  await g.up(timeStamp: Duration(milliseconds: t));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  const start = Offset(180, 200);

  testWidgets('tapping a tab selects it', (tester) async {
    final active = await pumpTabs(tester);
    await tester.tap(find.text('Beta'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(active.value, 'b');
  });

  testWidgets('the badge is shown', (tester) async {
    await pumpTabs(tester);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('a slow drag past 22% of the width goes to the next tab', (tester) async {
    final active = await pumpTabs(tester);
    await drag(tester, start, -120);
    expect(active.value, 'b');
  });

  testWidgets('a slow drag under 22% stays', (tester) async {
    final active = await pumpTabs(tester);
    await drag(tester, start, -40, ms: 1000);
    expect(active.value, 'a');
  });

  testWidgets('a fast flick (> 0.35 px/ms) switches even when short', (tester) async {
    final active = await pumpTabs(tester);
    await drag(tester, start, -40, ms: 40);
    expect(active.value, 'b');
  });

  testWidgets('dragging right goes to the previous tab', (tester) async {
    final active = await pumpTabs(tester);
    active.value = 'b';
    await tester.pump(const Duration(milliseconds: 400));
    await drag(tester, start, 120);
    expect(active.value, 'a');
  });

  testWidgets('first and last tab: no wrap-around', (tester) async {
    final active = await pumpTabs(tester);
    await drag(tester, start, 200);
    expect(active.value, 'a');
    active.value = 'c';
    await tester.pump(const Duration(milliseconds: 400));
    await drag(tester, start, -200);
    expect(active.value, 'c');
  });

  testWidgets('a mostly vertical drag is left alone', (tester) async {
    final active = await pumpTabs(tester);
    await drag(tester, start, -60, dy: 120);
    expect(active.value, 'a');
  });

  testWidgets('a drag that starts in a text field is ignored', (tester) async {
    final active = await pumpTabs(tester, content: const SizedBox(height: 300, child: Align(alignment: Alignment.topCenter, child: TextField())));
    await drag(tester, tester.getCenter(find.byType(TextField)), -150);
    expect(active.value, 'a');
  });

  testWidgets('NoSwipe areas are ignored', (tester) async {
    final active = await pumpTabs(tester, content: const NoSwipe(child: SizedBox(height: 300, width: double.infinity)));
    await drag(tester, start, -150);
    expect(active.value, 'a');
  });

  testWidgets('a horizontally scrollable child keeps its own drag', (tester) async {
    final active = await pumpTabs(
      tester,
      content: SizedBox(
        height: 300,
        child: ListView(scrollDirection: Axis.horizontal, children: [for (var i = 0; i < 10; i++) const SizedBox(width: 200, height: 50)]),
      ),
    );
    await drag(tester, start, -150);
    expect(active.value, 'a');
  });

  testWidgets('content returns to rest after the gesture', (tester) async {
    await pumpTabs(tester);
    final before = tester.getTopLeft(find.byKey(const ValueKey('content')));
    await drag(tester, start, -40, ms: 1000);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getTopLeft(find.byKey(const ValueKey('content'))), before);
  });
}
