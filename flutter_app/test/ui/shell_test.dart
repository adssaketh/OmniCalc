import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/main.dart';
import 'package:omnicalc/services/feedback_service.dart';
import 'package:omnicalc/state/app_settings.dart';
import 'package:omnicalc/state/history_store.dart';
import 'package:omnicalc/state/navigation_state.dart';
import 'package:omnicalc/state/settings_store.dart';
import 'package:omnicalc/theme/dynamic_colors.dart';
import 'package:omnicalc/ui/shell/app_shell.dart';
import 'package:omnicalc/ui/shell/header.dart';
import 'package:provider/provider.dart';

typedef Harness = ({SettingsStore settings, HistoryStore history, SilentFeedbackService feedback});

Future<Harness> pumpApp(
  WidgetTester tester, {
  Size size = const Size(400, 800),
  AppSettings settings = const AppSettings(),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = SettingsStore.memory(settings, true);
  final history = HistoryStore.memory();
  final feedback = SilentFeedbackService();
  await tester.pumpWidget(OmniCalcApp(
    settings: store,
    history: history,
    systemColorsSource: const FakeSystemColorsSource(null),
    feedback: feedback,
  ));
  // the bar's entrance spring starts on the frame after the first one, so it needs two pumps
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 1500));
  return (settings: store, history: history, feedback: feedback);
}

NavigationState navOf(WidgetTester tester) =>
    Provider.of<NavigationState>(tester.element(find.byType(AppShell)), listen: false);

/// Two frames: effects that run after a frame (scroll reset, mode checks) rebuild on the next one.
Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 1500));
}

void main() {
  group('phone layout', () {
    testWidgets('bottom bar shows the destinations and the calculator', (tester) async {
      await pumpApp(tester);
      for (final label in ['Calculator', 'Converter', 'Finance', 'Recents']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Physics Lab'), findsNothing);
      expect(find.text('fx ADV'), findsOneWidget); // the calculator keypad (Phase 4)
      expect(find.text('Calc'), findsNothing); // the rail's short label is not used here
    });

    testWidgets('tapping a destination switches screen, plays feedback', (tester) async {
      final h = await pumpApp(tester);
      await tester.tap(find.text('Converter'));
      await settle(tester);
      expect(navOf(tester).mode, CalculatorMode.converter);
      expect(find.text('Converter (Phase 5)'), findsOneWidget);
      expect(h.feedback.log, ['click:toggle', 'haptic:medium']);
      await tester.tap(find.text('Finance'));
      await settle(tester);
      expect(navOf(tester).mode, CalculatorMode.finance);
    });

    testWidgets('sound off and haptic off silence navFeedback', (tester) async {
      final h = await pumpApp(
        tester,
        settings: const AppSettings(soundEnabled: false, hapticEnabled: false),
      );
      await tester.tap(find.text('Converter'));
      await settle(tester);
      expect(h.feedback.log, isEmpty);
    });

    testWidgets('Recents toggles the history layer and shows the badge', (tester) async {
      final h = await pumpApp(tester);
      h.history.add(expression: '1+1', result: '2');
      await tester.pump();
      // the keypad's "1" key, the bottom bar badge and the calculator header's history badge
      expect(find.text('1'), findsNWidgets(3));
      await tester.tap(find.text('Recents'));
      await settle(tester);
      expect(navOf(tester).isHistoryOpen, isTrue);
      await tester.tap(find.text('Recents'));
      await settle(tester);
      expect(navOf(tester).isHistoryOpen, isFalse);
    });

    testWidgets('badge caps at 99+', (tester) async {
      final h = await pumpApp(tester);
      for (var i = 0; i < 120; i++) {
        h.history.add(expression: '$i', result: '$i');
      }
      await tester.pump();
      expect(find.text('99+'), findsWidgets);
    });

    testWidgets('physics and grapher tabs follow the settings', (tester) async {
      await pumpApp(tester, settings: const AppSettings(enablePhysics: true, enableGrapher: true));
      expect(find.text('Physics Lab'), findsOneWidget);
      expect(find.text('Grapher'), findsOneWidget);
    });

    testWidgets('the calculator keeps the header merged (no separate Header pill)', (tester) async {
      await pumpApp(tester);
      expect(find.byType(Header), findsOneWidget);
      expect(tester.widget<Header>(find.byType(Header)).embedded, isTrue);
      await tester.tap(find.text('Converter'));
      await settle(tester);
      expect(find.byType(Header), findsOneWidget);
      expect(tester.widget<Header>(find.byType(Header)).embedded, isFalse);
    });

    testWidgets('the header collapses past 36 px and expands under 10 px', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Converter'));
      await settle(tester);
      expect(tester.widget<Header>(find.byType(Header)).collapsed, isFalse);

      final scroll = find.byType(CustomScrollView);
      await tester.drag(scroll, const Offset(0, -60));
      await settle(tester);
      expect(tester.widget<Header>(find.byType(Header)).collapsed, isTrue);

      // 20 px from the top: between the thresholds, stays collapsed
      await tester.drag(scroll, const Offset(0, 40));
      await settle(tester);
      expect(tester.widget<Header>(find.byType(Header)).collapsed, isTrue);

      await tester.drag(scroll, const Offset(0, 100));
      await settle(tester);
      expect(tester.widget<Header>(find.byType(Header)).collapsed, isFalse);
    });

    testWidgets('changing screen scrolls back to the top and expands the header', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Converter'));
      await settle(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await settle(tester);
      expect(tester.widget<Header>(find.byType(Header)).collapsed, isTrue);
      await tester.tap(find.text('Finance'));
      await settle(tester);
      expect(tester.widget<Header>(find.byType(Header)).collapsed, isFalse);
    });
  });

  group('large layout', () {
    testWidgets('tablet landscape uses the rail with short labels', (tester) async {
      await pumpApp(tester, size: const Size(1280, 800));
      expect(find.text('Calc'), findsOneWidget);
      expect(find.text('Convert'), findsOneWidget);
      expect(find.text('Calculator'), findsNothing);
    });

    testWidgets('width 960 is large; 959 on a phone-sized height is not', (tester) async {
      expect(ShellLayout.of(const Size(960, 500)).isLargeScreen, isTrue);
      expect(ShellLayout.of(const Size(959, 500)).isLargeScreen, isFalse);
      expect(ShellLayout.of(const Size(800, 1280)).isLargeScreen, isTrue); // tablet portrait >= 720
      expect(ShellLayout.of(const Size(700, 1280)).isLargeScreen, isFalse);
      expect(ShellLayout.of(const Size(844, 390)).isLandscape, isTrue);
      expect(ShellLayout.of(const Size(500, 300)).isLandscape, isFalse); // under 540 wide
      expect(ShellLayout.of(const Size(900, 560)).isTablet, isTrue);
    });
  });

  group('keyboard and back', () {
    testWidgets('Alt+2 opens the converter, Alt+S toggles settings, Escape closes', (tester) async {
      await pumpApp(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await settle(tester);
      expect(navOf(tester).mode, CalculatorMode.converter);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await settle(tester);
      expect(navOf(tester).isSettingsOpen, isTrue);
      expect(find.text('Settings (Phase 3 preview)'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(navOf(tester).isSettingsOpen, isFalse);
    });

    testWidgets('Alt+3 and Alt+5 only work when the tab is enabled', (tester) async {
      await pumpApp(tester);
      for (final k in [LogicalKeyboardKey.digit3, LogicalKeyboardKey.digit5]) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(k);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      }
      await settle(tester);
      expect(navOf(tester).mode, CalculatorMode.standard);
    });

    testWidgets('back from the first screen asks to press again', (tester) async {
      await pumpApp(tester);
      expect(find.text('Press back again to exit'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Press back again to exit'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2200)); // the hint hides itself after 2 s
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Press back again to exit'), findsNothing);
    });

    testWidgets('back goes to the previous screen', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Converter'));
      await settle(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(navOf(tester).mode, CalculatorMode.standard);
    });
  });

  group('settings reach the shell', () {
    testWidgets('turning Physics Lab off while on it returns to the calculator', (tester) async {
      final h = await pumpApp(tester, settings: const AppSettings(enablePhysics: true));
      await tester.tap(find.text('Physics Lab'));
      await settle(tester);
      expect(navOf(tester).mode, CalculatorMode.physics);
      h.settings.update((s) => s.copyWith(enablePhysics: false));
      await settle(tester);
      expect(navOf(tester).mode, CalculatorMode.standard);
    });

    testWidgets('settings render in every theme, both colour modes and both bar styles', (tester) async {
      final h = await pumpApp(tester);
      for (final theme in [ThemeIds.dynamic, ThemeIds.ocean, ThemeIds.forest, ThemeIds.sunset, ThemeIds.amoled]) {
        for (final mode in ColorMode.values) {
          for (final bar in BarStyle.values) {
            for (final edge in EdgeEffect.values) {
              h.settings.update((s) => s.copyWith(theme: theme, colorMode: mode, barStyle: bar, edgeEffect: edge));
              await tester.pump(const Duration(milliseconds: 50));
              expect(tester.takeException(), isNull, reason: '$theme $mode $bar $edge');
            }
          }
        }
      }
    });
  });
}
