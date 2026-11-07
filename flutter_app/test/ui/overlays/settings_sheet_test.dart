import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/types.dart';
import 'package:omnicalc/services/link_service.dart';
import 'package:omnicalc/state/app_settings.dart';
import 'package:omnicalc/state/navigation_state.dart';
import 'package:omnicalc/ui/overlays/settings_sheet.dart';

import '../shell_test.dart' show Harness, navOf, pumpApp, settle;

Future<Harness> openSettings(WidgetTester tester, {AppSettings settings = const AppSettings(), RecordingLinkService? links}) async {
  final h = await pumpApp(tester, size: const Size(630, 1000), settings: settings, linkService: links ?? RecordingLinkService());
  navOf(tester).setSettingsOpen(true);
  await settle(tester);
  return h;
}

Finder k(String key) => find.byKey(ValueKey(key));

/// The settings list scrolls: bring a row into view, then tap it.
Future<void> tapRow(WidgetTester tester, String key) async {
  await tester.ensureVisible(k(key));
  await tester.pump();
  await tester.tap(k(key));
  await settle(tester);
}

void main() {
  group('labels and helpers', () {
    test('precision and colour mode labels', () {
      expect(precisionLabel(-1), 'Auto (Full precision)');
      expect(precisionLabel(4), '4 decimal places');
      expect(colorModeLabel(ColorMode.system), 'System default (auto)');
      expect(colorModeLabel(ColorMode.light), 'Light mode');
      expect(colorModeLabel(ColorMode.dark), 'Dark mode');
    });

    test('eight themes; an unknown id falls back to the second one', () {
      expect(kThemeOptions.length, 8);
      expect(themeOptionFor('nope').id, ThemeIds.iris);
      expect(themeOptionFor(ThemeIds.sunset).name, 'Sunset Terracotta');
    });

    test('reset restores the defaults and leaves the currency alone', () {
      const messy = AppSettings(
        soundEnabled: false,
        hapticEnabled: false,
        vibrationIntensity: VibrationIntensity.intense,
        angleMode: AngleMode.rad,
        decimalPrecision: 3,
        theme: ThemeIds.sunset,
        colorMode: ColorMode.dark,
        enableGrapher: true,
        enablePhysics: true,
        edgeEffect: EdgeEffect.blur,
        fadeHeight: FadeHeight.tall,
        barStyle: BarStyle.glass,
        glassTransparency: 10,
        glassBlur: GlassBlur.strong,
        glassEdge: false,
        currencyCode: 'EUR',
        currencySymbol: '€',
      );
      final r = resetSettings(messy);
      const d = AppSettings();
      expect(r.soundEnabled, d.soundEnabled);
      expect(r.hapticEnabled, d.hapticEnabled);
      expect(r.vibrationIntensity, VibrationIntensity.medium);
      expect(r.angleMode, AngleMode.deg);
      expect(r.decimalPrecision, -1);
      expect(r.theme, ThemeIds.dynamic);
      expect(r.colorMode, ColorMode.system);
      expect(r.enableGrapher, false);
      expect(r.enablePhysics, false);
      expect(r.edgeEffect, EdgeEffect.fade);
      expect(r.fadeHeight, FadeHeight.medium);
      expect(r.barStyle, BarStyle.solid);
      expect(r.glassTransparency, 70);
      expect(r.glassBlur, GlassBlur.medium);
      expect(r.glassEdge, true);
      expect(r.currencyCode, 'EUR');
      expect(r.currencySymbol, '€');
    });
  });

  group('sheet', () {
    testWidgets('opens with the rows and their current values', (tester) async {
      await openSettings(tester);
      expect(find.text('Choose theme'), findsNothing);
      for (final row in ['row-theme', 'row-color-mode', 'row-amoled', 'row-angle', 'row-precision', 'row-sound', 'row-haptic']) {
        expect(k(row), findsOneWidget, reason: row);
      }
      expect(find.text('Auto (Full precision)'), findsOneWidget);
      expect(find.text('Degrees (DEG)'), findsOneWidget);
    });

    testWidgets('Done and back close the sheet', (tester) async {
      await openSettings(tester);
      await tapRow(tester, 'settings-done');
      expect(navOf(tester).isSettingsOpen, false);
      navOf(tester).setSettingsOpen(true);
      await settle(tester);
      expect(navOf(tester).handleBack(), BackAction.closedSettings);
      expect(navOf(tester).isSettingsOpen, false);
    });

    testWidgets('sound, haptic, physics and grapher switches persist', (tester) async {
      final h = await openSettings(tester);
      await tapRow(tester, 'row-sound');
      expect(h.settings.settings.soundEnabled, false);
      await tapRow(tester, 'row-haptic');
      expect(h.settings.settings.hapticEnabled, false);
      await tapRow(tester, 'row-physics');
      expect(h.settings.settings.enablePhysics, true);
      await tapRow(tester, 'row-grapher');
      expect(h.settings.settings.enableGrapher, true);
      await tapRow(tester, 'row-sound');
      expect(h.settings.settings.soundEnabled, true);
    });

    testWidgets('AMOLED switch: on forces dark, off goes back to dynamic, and the pick counts as the user\'s', (tester) async {
      final h = await openSettings(tester);
      await tapRow(tester, 'row-amoled');
      expect(h.settings.settings.theme, ThemeIds.amoled);
      expect(h.settings.settings.colorMode, ColorMode.dark);
      await tapRow(tester, 'row-amoled');
      expect(h.settings.settings.theme, ThemeIds.dynamic);
      expect(h.settings.settings.colorMode, ColorMode.dark); // the colour mode is left as it was
    });

    testWidgets('theme list: choosing a theme saves it and closes the list', (tester) async {
      final h = await openSettings(tester);
      await tapRow(tester, 'row-theme');
      expect(find.text('Choose theme'), findsOneWidget);
      await tester.tap(k('choice-${ThemeIds.ocean}'));
      await settle(tester);
      expect(h.settings.settings.theme, ThemeIds.ocean);
      expect(find.text('Choose theme'), findsNothing);
    });

    testWidgets('colour mode, angle unit and precision lists', (tester) async {
      final h = await openSettings(tester);
      await tapRow(tester, 'row-color-mode');
      await tester.tap(k('choice-${ColorMode.dark}'));
      await settle(tester);
      expect(h.settings.settings.colorMode, ColorMode.dark);
      await tapRow(tester, 'row-angle');
      await tester.tap(k('choice-${AngleMode.rad}'));
      await settle(tester);
      expect(h.settings.settings.angleMode, AngleMode.rad);
      expect(find.text('Radians (RAD)'), findsOneWidget);
      await tapRow(tester, 'row-precision');
      await tester.tap(k('choice-4'));
      await settle(tester);
      expect(h.settings.settings.decimalPrecision, 4);
      expect(find.text('4 decimal places'), findsOneWidget);
    });

    testWidgets('vibration list: the strength is saved', (tester) async {
      final h = await openSettings(tester);
      await tapRow(tester, 'row-vibration');
      await tester.tap(k('choice-${VibrationIntensity.strong}'));
      await settle(tester);
      expect(h.settings.settings.vibrationIntensity, VibrationIntensity.strong);
    });

    testWidgets('back closes the open list first, then Settings', (tester) async {
      await openSettings(tester);
      await tapRow(tester, 'row-angle');
      expect(k('choice-${AngleMode.rad}'), findsOneWidget);
      navOf(tester).handleBack();
      await settle(tester);
      expect(navOf(tester).isSettingsOpen, true);
      expect(find.text('Radians (RAD)'), findsNothing);
      navOf(tester).handleBack();
      await settle(tester);
      expect(navOf(tester).isSettingsOpen, false);
    });

    testWidgets('bar style: Glass reveals the glass options, Solid hides them', (tester) async {
      final h = await openSettings(tester);
      await tester.ensureVisible(k('seg-Bar style-Glass'));
      await tester.pump();
      expect(find.text('70%'), findsNothing);
      await tester.tap(k('seg-Bar style-Glass'));
      await settle(tester);
      expect(h.settings.settings.barStyle, BarStyle.glass);
      expect(k('glass-options'), findsOneWidget);
      expect(find.text('70%'), findsOneWidget);
      await tester.tap(k('glass-edge'));
      await settle(tester);
      expect(h.settings.settings.glassEdge, false);
      await tester.ensureVisible(k('seg-Bar style-Solid'));
      await tester.pump();
      await tester.tap(k('seg-Bar style-Solid'));
      await settle(tester);
      expect(h.settings.settings.barStyle, BarStyle.solid);
    });

    testWidgets('scroll edge effect and fade height', (tester) async {
      final h = await openSettings(tester);
      await tester.ensureVisible(k('seg-Scroll edge effect-Off'));
      await tester.pump();
      await tester.tap(k('seg-Scroll edge effect-Off'));
      await settle(tester);
      expect(h.settings.settings.edgeEffect, EdgeEffect.off);
      // Fade height is disabled while the effect is off
      await tester.tap(k('seg-Fade height-Tall'), warnIfMissed: false);
      await settle(tester);
      expect(h.settings.settings.fadeHeight, FadeHeight.medium);
      await tester.tap(k('seg-Scroll edge effect-Fade + blur'));
      await settle(tester);
      await tester.tap(k('seg-Fade height-Tall'));
      await settle(tester);
      expect(h.settings.settings.edgeEffect, EdgeEffect.blur);
      expect(h.settings.settings.fadeHeight, FadeHeight.tall);
    });

    testWidgets('reset: cancel keeps everything, Reset restores and shows the toast', (tester) async {
      final h = await openSettings(
        tester,
        settings: const AppSettings(theme: ThemeIds.sunset, angleMode: AngleMode.rad, decimalPrecision: 2, soundEnabled: false),
      );
      await tapRow(tester, 'row-reset');
      expect(find.text('Reset all settings?'), findsOneWidget);
      await tester.tap(k('reset-cancel'));
      await settle(tester);
      expect(h.settings.settings.theme, ThemeIds.sunset);
      await tapRow(tester, 'row-reset');
      await tester.tap(k('reset-confirm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(h.settings.settings.theme, ThemeIds.dynamic);
      expect(h.settings.settings.angleMode, AngleMode.deg);
      expect(h.settings.settings.decimalPrecision, -1);
      expect(h.settings.settings.soundEnabled, true);
      expect(k('reset-toast'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 3500));
      expect(k('reset-toast'), findsNothing);
    });

    testWidgets('GitHub opens the repository', (tester) async {
      final links = RecordingLinkService();
      await openSettings(tester, links: links);
      await tapRow(tester, 'row-github');
      expect(links.opened, [kRepoUrl]);
    });

    testWidgets('privacy sheet: the standalone policy link opens, Close closes', (tester) async {
      final links = RecordingLinkService();
      await openSettings(tester, links: links);
      await tapRow(tester, 'row-privacy');
      expect(k('privacy-standalone'), findsOneWidget);
      await tester.tap(k('privacy-standalone'));
      await settle(tester);
      expect(links.opened.length, 1);
      expect(links.opened.single, contains('PRIVACY.md'));
      await tester.tap(k('privacy-close'));
      await settle(tester);
      expect(k('privacy-standalone'), findsNothing);
    });

    testWidgets('the user guide row closes Settings and opens the guide', (tester) async {
      await openSettings(tester);
      await tapRow(tester, 'row-guide');
      expect(navOf(tester).isSettingsOpen, false);
      expect(navOf(tester).isGuideOpen, true);
    });
  });
}
