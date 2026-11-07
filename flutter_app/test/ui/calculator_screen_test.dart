import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/main.dart';
import 'package:omnicalc/services/feedback_service.dart';
import 'package:omnicalc/state/app_settings.dart';
import 'package:omnicalc/state/history_store.dart';
import 'package:omnicalc/state/settings_store.dart';
import 'package:omnicalc/theme/dynamic_colors.dart';
import 'package:omnicalc/ui/calculator/auto_fit_text.dart';

Future<({SettingsStore settings, HistoryStore history})> pumpApp(
  WidgetTester tester, {
  // tall on purpose: the keypad is taller than the screen minus the bottom bar on a 400x800 view, so the lowest rows
  // sit under the bar until the page is scrolled
  Size size = const Size(400, 1200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = SettingsStore.memory(const AppSettings(), true);
  final history = HistoryStore.memory();
  await tester.pumpWidget(OmniCalcApp(
    settings: store,
    history: history,
    systemColorsSource: const FakeSystemColorsSource(null),
    feedback: SilentFeedbackService(),
  ));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 1500));
  return (settings: store, history: history);
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 600));
}

/// The text the big display currently shows.
String shown(WidgetTester tester) => tester.renderObject<RenderAutoFitText>(find.byType(AutoFitText)).text;

Future<void> tapKey(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('portrait phone', () {
    testWidgets('the answer card is pinned and the keypad is there', (tester) async {
      await pumpApp(tester);
      await settle(tester);
      expect(find.byType(AutoFitText), findsOneWidget);
      expect(shown(tester), '0');
      for (final k in ['AC', '%', '÷', '7', '8', '9', '×', '4', '5', '6', '−', '1', '2', '3', '+', '0', '.', 'fx ADV', 'MC', 'MR', 'M+', 'M-', 'DEG']) {
        expect(find.text(k), findsWidgets, reason: k);
      }
    });

    testWidgets('7 + 3 = shows 10 and the question line', (tester) async {
      await pumpApp(tester);
      await settle(tester);
      await tapKey(tester, '7');
      await tapKey(tester, '+');
      await tapKey(tester, '3');
      expect(shown(tester), '7+3');
      expect(find.text('= 10'), findsOneWidget); // live preview
      // the = key is the one with the enter icon next to the equals sign
      await tester.tap(find.text('=').last);
      await settle(tester);
      expect(shown(tester), '10');
      expect(find.text('7+3 ='), findsOneWidget);
    });

    testWidgets('AC clears and backspace deletes', (tester) async {
      await pumpApp(tester);
      await settle(tester);
      await tapKey(tester, '1');
      await tapKey(tester, '2');
      await tapKey(tester, '3');
      expect(shown(tester), '123');
      await tester.tap(find.bySemanticsLabel('Backspace'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(shown(tester), '12');
      await tapKey(tester, 'AC');
      expect(shown(tester), '0');
    });

    testWidgets('fx ADV opens the drawer with the five tabs, Hide closes it', (tester) async {
      await pumpApp(tester);
      await settle(tester);
      await tapKey(tester, 'fx ADV');
      await settle(tester);
      expect(find.text('fx ON'), findsOneWidget);
      expect(find.text('Advanced Scientific Operations'), findsOneWidget);
      for (final tab in ['Calculus', 'Trig & Hyp', 'Powers', 'Probability', 'Constants']) {
        expect(find.text(tab), findsWidgets, reason: tab);
      }
      expect(find.text('d/dx'), findsOneWidget);
      await tester.tap(find.text('Hide'));
      await settle(tester);
      expect(find.text('Advanced Scientific Operations'), findsNothing);
      expect(find.text('fx ADV'), findsOneWidget);
    });

    testWidgets('a hardware keyboard types and evaluates', (tester) async {
      await pumpApp(tester);
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit6, character: '6');
      await tester.sendKeyEvent(LogicalKeyboardKey.numpadMultiply);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit7, character: '7');
      await tester.pump();
      expect(shown(tester), '6×7');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(shown(tester), '42');
    });

    testWidgets('the angle badge toggles DEG and RAD in the settings', (tester) async {
      final h = await pumpApp(tester);
      await settle(tester);
      await tester.tap(find.text('DEG').first);
      await settle(tester);
      expect(h.settings.settings.angleMode.name, 'rad');
      expect(find.text('RAD'), findsWidgets);
    });

    testWidgets('a finished calculation lands in the history', (tester) async {
      final h = await pumpApp(tester);
      await settle(tester);
      await tapKey(tester, '2');
      await tapKey(tester, '+');
      await tapKey(tester, '2');
      await tester.tap(find.text('=').last);
      await settle(tester);
      expect(h.history.count, 1);
      expect(h.history.items.first.expression, '2+2');
      expect(h.history.items.first.result, '4');
    });
  });

  group('landscape', () {
    testWidgets('display pane and keypad pane build without layout errors', (tester) async {
      await pumpApp(tester, size: const Size(900, 420));
      await settle(tester);
      for (final k in ['AC', '÷', '7', '0', '.', 'MC', 'MR', 'Calculus', 'd/dx']) {
        expect(find.text(k), findsWidgets, reason: k);
      }
      await tapKey(tester, '8');
      await tapKey(tester, '×');
      await tapKey(tester, '8');
      expect(find.text('8×8'), findsOneWidget);
    });

    testWidgets('a tablet in portrait builds', (tester) async {
      await pumpApp(tester, size: const Size(820, 1180));
      await settle(tester);
      expect(find.byType(AutoFitText), findsOneWidget);
      await tapKey(tester, 'fx ADV');
      await settle(tester);
      expect(find.text('Advanced Scientific Operations'), findsOneWidget);
    });
  });
}
