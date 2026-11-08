@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/main.dart';
import 'package:omnicalc/services/feedback_service.dart';
import 'package:omnicalc/state/app_settings.dart';
import 'package:omnicalc/state/history_store.dart';
import 'package:omnicalc/state/settings_store.dart';
import 'package:omnicalc/theme/dynamic_colors.dart';

// Shell screenshot goldens: the gate of Phase 3. Baselines are rendered from the TypeScript app in Chrome at the same
// logical size (see PHASE3_NOTES.md) and stored in test/goldens/shell/. Compare with:
//   flutter test --tags golden
// Baselines that are not committed yet are reported as skipped, not as passed.
Future<void> shot(WidgetTester tester, String name, AppSettings settings, {Size size = const Size(390, 844)}) async {
  if (!File('test/goldens/shell/$name.png').existsSync()) {
    markTestSkipped('no baseline test/goldens/shell/$name.png yet');
    return;
  }
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(OmniCalcApp(
    settings: SettingsStore.memory(settings, true),
    history: HistoryStore.memory(),
    systemColorsSource: const FakeSystemColorsSource(null),
    feedback: SilentFeedbackService(),
  ));
  await tester.pump(const Duration(milliseconds: 1500));
  await expectLater(find.byType(OmniCalcApp), matchesGoldenFile('../goldens/shell/$name.png'));
}

void main() {
  final cases = <String, AppSettings>{
    'iris_dark_solid': const AppSettings(colorMode: ColorMode.dark, theme: ThemeIds.iris),
    'iris_light_solid': const AppSettings(colorMode: ColorMode.light, theme: ThemeIds.iris),
    'ocean_dark_glass': const AppSettings(colorMode: ColorMode.dark, theme: ThemeIds.ocean, barStyle: BarStyle.glass),
    'forest_light_solid': const AppSettings(colorMode: ColorMode.light, theme: ThemeIds.forest),
    'sunset_dark_solid': const AppSettings(colorMode: ColorMode.dark, theme: ThemeIds.sunset),
    'amoled_dark_glass': const AppSettings(colorMode: ColorMode.dark, theme: ThemeIds.amoled, barStyle: BarStyle.glass),
  };
  for (final e in cases.entries) {
    testWidgets(e.key, (tester) => shot(tester, e.key, e.value));
  }
}
