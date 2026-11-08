import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show TextField;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/main.dart';
import 'package:omnicalc/services/feedback_service.dart';
import 'package:omnicalc/state/app_settings.dart';
import 'package:omnicalc/state/history_store.dart';
import 'package:omnicalc/state/navigation_state.dart';
import 'package:omnicalc/state/settings_store.dart';
import 'package:omnicalc/theme/dynamic_colors.dart';
import 'package:omnicalc/theme/tokens.dart';
import 'package:omnicalc/ui/icons/lucide_icon.dart';
import 'package:omnicalc/ui/screens/graph_screen.dart';
import 'package:omnicalc/ui/shell/app_shell.dart';
import 'package:provider/provider.dart';

import '../../support/fake_currency.dart';

/// Opens the Grapher at [size] (never resized afterwards: a layout change remounts the screen).
Future<SilentFeedbackService> pumpGrapher(WidgetTester tester, {Size size = const Size(400, 1400)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final feedback = SilentFeedbackService();
  await tester.pumpWidget(OmniCalcApp(
    settings: SettingsStore.memory(const AppSettings(enableGrapher: true), true),
    history: HistoryStore.memory(),
    systemColorsSource: const FakeSystemColorsSource(null),
    feedback: feedback,
    currencyService: offlineCurrencyService(),
  ));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 1500));
  Provider.of<NavigationState>(tester.element(find.byType(AppShell)), listen: false).setMode(CalculatorMode.grapher);
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 1500));
  // the page measures its natural height on the first frame and lays out once more; wait for that so positions are final
  await tester.pump(const Duration(milliseconds: 100));
  feedback.log.clear();
  return feedback;
}

final Finder canvas = find.byKey(const ValueKey('graph-canvas'));

GraphPainter painterOf(WidgetTester tester) => tester.widget<CustomPaint>(canvas).painter! as GraphPainter;

/// The pixels-per-unit of the current view.
double scaleOf(WidgetTester tester) => painterOf(tester).frame.scale;

/// The origin offset of the current view (`origin` of the component).
Offset originOf(WidgetTester tester) {
  final f = painterOf(tester).frame;
  return Offset(f.ox - f.width / 2, f.oy - f.height / 2);
}

String textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;

String inputText(WidgetTester tester) => tester.widget<TextField>(find.byKey(const ValueKey('graph-input'))).controller!.text;

Color presetColor(WidgetTester tester, String label) {
  final box = tester.widget<AnimatedContainer>(
    find.descendant(of: find.byKey(ValueKey('graph-preset-$label')), matching: find.byType(AnimatedContainer)),
  );
  return (box.decoration! as BoxDecoration).color!;
}

M3Tokens tokensOf(WidgetTester tester) => M3Theme.of(tester.element(canvas));

Future<TestGesture> mouseAt(WidgetTester tester, Offset p) async {
  final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await g.addPointer(location: Offset.zero);
  addTearDown(g.removePointer);
  await g.moveTo(p);
  await tester.pump();
  return g;
}

void main() {
  testWidgets('first view: sin(x) in the box, nine presets with sin(x) active, scale 40, nothing under the cursor', (tester) async {
    await pumpGrapher(tester);
    expect(inputText(tester), 'sin(x)');
    expect(find.text('f(x) ='), findsOneWidget);
    expect(find.text('Plot Function'), findsOneWidget);
    expect(find.text('Function Presets:'), findsOneWidget);
    for (final label in ['sin(x)', 'cos(x)', 'tan(x)', 'x²', 'x³', '√x', '1/x', 'eˣ', 'ln(x)']) {
      expect(find.byKey(ValueKey('graph-preset-$label')), findsOneWidget, reason: label);
    }
    final t = tokensOf(tester);
    expect(presetColor(tester, 'sin(x)'), t.primaryContainer);
    expect(presetColor(tester, 'cos(x)'), t.surfaceContainer);
    expect(scaleOf(tester), 40);
    expect(originOf(tester), Offset.zero);
    expect(painterOf(tester).mouse, isNull);
    expect(find.byKey(const ValueKey('graph-tooltip-x')), findsNothing);
    // the curve is drawn: one piece, a point every 2 px
    final f = painterOf(tester).frame;
    expect(f.curve.length, 1);
    expect(f.curve.first.length, (f.width / 2).floor() + 1);
  });

  testWidgets('the canvas is 360 tall on a phone and the plane is centred on it', (tester) async {
    await pumpGrapher(tester);
    expect(tester.getSize(canvas).height, 360);
    final f = painterOf(tester).frame;
    expect(f.height, 360);
    expect(f.width, tester.getSize(canvas).width.floorToDouble());
    expect(f.ox, f.width / 2);
    expect(f.oy, 180);
  });

  testWidgets('icons: reset, zoom in, zoom out; the crosshair icon only with the tooltip', (tester) async {
    await pumpGrapher(tester);
    Set<LucideIconId> icons() => tester.widgetList<LucideIcon>(find.byType(LucideIcon)).map((i) => i.id).toSet();
    expect(icons(), containsAll([LucideIconId.rotateCcw, LucideIconId.zoomIn, LucideIconId.zoomOut]));
    expect(icons().contains(LucideIconId.crosshair), isFalse);
    await mouseAt(tester, tester.getTopLeft(canvas) + const Offset(100, 100));
    expect(icons().contains(LucideIconId.crosshair), isTrue);
  });

  group('function bar', () {
    testWidgets('Plot Function plots what is in the box and plays the op click', (tester) async {
      final fb = await pumpGrapher(tester);
      await tester.enterText(find.byKey(const ValueKey('graph-input')), 'x^2');
      await tester.pump();
      // typing alone does not plot
      expect(painterOf(tester).frame.curve.first[painterOf(tester).frame.curve.first.length ~/ 2].dy, closeTo(180, 1e-9)); // sin(0) = 0
      await tester.tap(find.byKey(const ValueKey('graph-plot')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(fb.log, ['click:op', 'haptic:medium']);
      final f = painterOf(tester).frame;
      // x^2 at the centre column is 0 and at 2 units either side is 4 * 40 px above the axis
      final centre = f.curve.first.firstWhere((p) => p.dx == (f.width / 2).floorToDouble() || p.dx == (f.width / 2).floorToDouble() + 1);
      expect(centre.dy, closeTo(180, 0.5));
      final right = f.curve.first.firstWhere((p) => p.dx >= f.ox + 80);
      expect(right.dy, lessThan(180 - 150)); // about 4 * 40 = 160 px up
      // no preset matches x^2 typed by hand... it does: the preset is active when the expression equals its text
      expect(presetColor(tester, 'x²'), tokensOf(tester).primaryContainer);
      expect(presetColor(tester, 'sin(x)'), tokensOf(tester).surfaceContainer);
    });

    testWidgets('Enter in the box plots like the form submit does', (tester) async {
      final fb = await pumpGrapher(tester);
      await tester.enterText(find.byKey(const ValueKey('graph-input')), 'cos(x)');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pump(const Duration(milliseconds: 300));
      expect(fb.log, ['click:op', 'haptic:medium']);
      expect(presetColor(tester, 'cos(x)'), tokensOf(tester).primaryContainer);
    });

    testWidgets('an unplottable expression leaves an empty curve (and keeps the grid)', (tester) async {
      await pumpGrapher(tester);
      await tester.enterText(find.byKey(const ValueKey('graph-input')), 'bad((');
      await tester.tap(find.byKey(const ValueKey('graph-plot')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(painterOf(tester).frame.curve, isEmpty);
      expect(painterOf(tester).frame.vertical, isNotEmpty);
    });

    testWidgets('a preset fills the box, plots at once and plays the toggle click', (tester) async {
      final fb = await pumpGrapher(tester);
      await tester.tap(find.byKey(const ValueKey('graph-preset-√x')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(fb.log, ['click:toggle', 'haptic:medium']);
      expect(inputText(tester), 'sqrt(x)');
      final t = tokensOf(tester);
      expect(presetColor(tester, '√x'), t.primaryContainer);
      expect(presetColor(tester, 'sin(x)'), t.surfaceContainer);
      // sqrt(x) has nothing left of the y axis
      final f = painterOf(tester).frame;
      expect(f.curve.every((piece) => piece.every((p) => p.dx >= f.ox - 1)), isTrue);
    });
  });

  group('view controls', () {
    testWidgets('zoom in x1.25 and zoom out /1.25, clamped to 10..250, with the toggle click', (tester) async {
      final fb = await pumpGrapher(tester);
      await tester.tap(find.byKey(const ValueKey('graph-zoom-in')));
      await tester.pump();
      expect(scaleOf(tester), closeTo(50, 1e-9));
      expect(fb.log, ['click:toggle', 'haptic:medium']);
      await tester.tap(find.byKey(const ValueKey('graph-zoom-out')));
      await tester.tap(find.byKey(const ValueKey('graph-zoom-out')));
      await tester.pump();
      expect(scaleOf(tester), closeTo(32, 1e-9));
      for (var i = 0; i < 12; i++) {
        await tester.tap(find.byKey(const ValueKey('graph-zoom-out')));
      }
      await tester.pump();
      expect(scaleOf(tester), 10);
      for (var i = 0; i < 20; i++) {
        await tester.tap(find.byKey(const ValueKey('graph-zoom-in')));
      }
      await tester.pump();
      expect(scaleOf(tester), 250);
    });

    testWidgets('Reset View restores scale 40 and the centred origin (toggle click)', (tester) async {
      final fb = await pumpGrapher(tester);
      await tester.tap(find.byKey(const ValueKey('graph-zoom-in')));
      await tester.dragFrom(tester.getCenter(canvas), const Offset(60, 30));
      await tester.pump();
      expect(originOf(tester), isNot(Offset.zero));
      fb.log.clear();
      await tester.tap(find.byKey(const ValueKey('graph-reset')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(fb.log, ['click:toggle', 'haptic:medium']);
      expect(scaleOf(tester), 40);
      expect(originOf(tester), Offset.zero);
    });

    testWidgets('mouse wheel: scroll up zooms in x1.15, down (or sideways) zooms out x0.85, clamped', (tester) async {
      await pumpGrapher(tester);
      final p = TestPointer(1, PointerDeviceKind.mouse);
      final at = tester.getCenter(canvas);
      await tester.sendEventToBinding(p.hover(at));
      await tester.sendEventToBinding(p.scroll(const Offset(0, -120)));
      await tester.pump();
      expect(scaleOf(tester), closeTo(46, 1e-9));
      await tester.sendEventToBinding(p.scroll(const Offset(0, 120)));
      await tester.pump();
      expect(scaleOf(tester), closeTo(46 * 0.85, 1e-9));
      // a sideways tick has deltaY 0, which is not < 0: zooms out
      await tester.sendEventToBinding(p.scroll(const Offset(120, 0)));
      await tester.pump();
      expect(scaleOf(tester), closeTo(46 * 0.85 * 0.85, 1e-9));
      for (var i = 0; i < 40; i++) {
        await tester.sendEventToBinding(p.scroll(const Offset(0, -120)));
      }
      await tester.pump();
      expect(scaleOf(tester), 250);
    });

    testWidgets('dragging pans the plane by the finger movement', (tester) async {
      await pumpGrapher(tester);
      final start = tester.getCenter(canvas);
      final g = await tester.startGesture(start);
      await g.moveBy(const Offset(30, 0));
      await g.moveBy(const Offset(20, -40));
      await tester.pump();
      expect(originOf(tester), const Offset(50, -40));
      await g.up();
      await tester.pump();
      // a second drag continues from where the first one stopped
      final g2 = await tester.startGesture(start);
      await g2.moveBy(const Offset(-10, 15));
      await g2.up();
      await tester.pump();
      expect(originOf(tester), const Offset(40, -25));
    });

    testWidgets('a drag that starts on the plot pans it and does not scroll the page', (tester) async {
      await pumpGrapher(tester, size: const Size(400, 560));
      await tester.ensureVisible(canvas);
      await tester.pump(const Duration(milliseconds: 1500));
      // the first press on the plot makes the page settle from the scroll position ensureVisible left it at
      await tester.tapAt(tester.getCenter(canvas));
      await tester.pump(const Duration(milliseconds: 1500));
      final topBefore = tester.getTopLeft(canvas).dy;
      final g = await tester.startGesture(tester.getCenter(canvas));
      await g.moveBy(const Offset(0, -80));
      await g.up();
      await tester.pump();
      expect(originOf(tester), const Offset(0, -80));
      expect(tester.getTopLeft(canvas).dy, topBefore);
    });

    testWidgets('a second finger is ignored while two fingers are down', (tester) async {
      await pumpGrapher(tester);
      final c = tester.getCenter(canvas);
      final a = await tester.startGesture(c);
      await a.moveBy(const Offset(10, 0));
      final b = await tester.startGesture(c + const Offset(50, 0));
      await a.moveBy(const Offset(40, 0));
      await b.moveBy(const Offset(40, 40));
      await tester.pump();
      expect(originOf(tester), const Offset(10, 0));
      await a.up();
      await b.up();
      await tester.pump();
      // both fingers are up: a new single touch pans again
      final g = await tester.startGesture(c);
      await g.moveBy(const Offset(5, 5));
      await g.up();
      await tester.pump();
      expect(originOf(tester), const Offset(15, 5));
    });
  });

  group('cursor and coordinates tooltip', () {
    testWidgets('hovering shows x and y with two decimals, the point and the dashed cross', (tester) async {
      await pumpGrapher(tester);
      final w = tester.getSize(canvas).width;
      final tl = tester.getTopLeft(canvas);
      await mouseAt(tester, tl + const Offset(100.3, 150));
      final x = (100.3 - w.roundToDouble() / 2) / 40;
      expect(textOf(tester, 'graph-tooltip-x'), 'x: ${x.toStringAsFixed(2)}');
      final y = (x.abs() < 1e-12) ? 0 : _sin(x);
      expect(textOf(tester, 'graph-tooltip-y'), 'y: ${y.toStringAsFixed(2)}');
      final p = painterOf(tester);
      expect(p.mouse!.dx, closeTo(100.3, 1e-9));
      expect(p.cursorPoint!.dx, closeTo(100.3, 1e-9));
      expect(p.cursorPoint!.dy, closeTo(180 - _sin(x) * 40, 1e-9));
    });

    testWidgets('the tooltip follows the pan (x is measured from the moved origin)', (tester) async {
      await pumpGrapher(tester);
      final tl = tester.getTopLeft(canvas);
      final w = tester.getSize(canvas).width;
      final g = await tester.startGesture(tl + const Offset(200, 200));
      await g.moveBy(const Offset(40, 0));
      await tester.pump();
      // the finger is now at 240: x = (240 - (w / 2 + 40)) / 40
      final x = (240 - (w.roundToDouble() / 2 + 40)) / 40;
      expect(textOf(tester, 'graph-tooltip-x'), 'x: ${x.toStringAsFixed(2)}');
      await g.up();
    });

    testWidgets('no point where f is not defined: sqrt(x) left of the axis shows y: NaN', (tester) async {
      await pumpGrapher(tester);
      await tester.tap(find.byKey(const ValueKey('graph-preset-√x')));
      await tester.pump(const Duration(milliseconds: 300));
      await mouseAt(tester, tester.getTopLeft(canvas) + const Offset(20, 100));
      expect(textOf(tester, 'graph-tooltip-y'), 'y: NaN');
      expect(painterOf(tester).mouse, isNotNull);
      expect(painterOf(tester).cursorPoint, isNull);
    });

    testWidgets('the cursor leaving the plot hides the tooltip', (tester) async {
      await pumpGrapher(tester);
      final g = await mouseAt(tester, tester.getTopLeft(canvas) + const Offset(100, 100));
      expect(find.byKey(const ValueKey('graph-tooltip-x')), findsOneWidget);
      await g.moveTo(const Offset(5, 5));
      await tester.pump();
      expect(find.byKey(const ValueKey('graph-tooltip-x')), findsNothing);
      expect(painterOf(tester).mouse, isNull);
    });

    testWidgets('a touch leaves the cursor where the finger lifted', (tester) async {
      await pumpGrapher(tester);
      final at = tester.getTopLeft(canvas) + const Offset(120, 90);
      final g = await tester.startGesture(at);
      await g.up();
      await tester.pump();
      expect(painterOf(tester).mouse!.dx, closeTo(120, 1e-9));
      expect(find.byKey(const ValueKey('graph-tooltip-x')), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('phone: input above, Plot and Reset side by side below it', (tester) async {
      await pumpGrapher(tester);
      final input = tester.getRect(find.byKey(const ValueKey('graph-input')));
      final plot = tester.getRect(find.byKey(const ValueKey('graph-plot')));
      final reset = tester.getRect(find.byKey(const ValueKey('graph-reset')));
      expect(plot.top, greaterThan(input.bottom));
      expect(reset.top, closeTo(plot.top, 4));
      expect(reset.size, const Size(44, 44));
      expect(plot.height, 40);
    });

    testWidgets('sm and wider: input, Plot and Reset on one row; canvas 420 / 500 / 560 tall', (tester) async {
      await pumpGrapher(tester, size: const Size(700, 1400));
      final input = tester.getRect(find.byKey(const ValueKey('graph-input')));
      final plot = tester.getRect(find.byKey(const ValueKey('graph-plot')));
      expect(plot.left, greaterThan(input.right));
      expect(plot.center.dy, closeTo(input.center.dy, 4));
      expect(tester.getSize(canvas).height, 420);
    });

    testWidgets('md: 500 tall', (tester) async {
      await pumpGrapher(tester, size: const Size(800, 1400));
      expect(tester.getSize(canvas).height, 500);
    });

    testWidgets('lg: 560 tall, and the page is at most 1024 wide (1152 from xl)', (tester) async {
      await pumpGrapher(tester, size: const Size(1100, 1400));
      expect(tester.getSize(canvas).height, 560);
      await pumpGrapher(tester, size: const Size(1500, 1400));
      expect(tester.getSize(canvas).width, lessThanOrEqualTo(1152 - 56));
    });
  });
}

double _sin(double x) => math.sin(x);
