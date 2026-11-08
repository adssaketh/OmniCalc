// Phase 8b: every main screen lays out without an overflow at 360 wide, at the normal and at twice the system font size.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/main.dart';
import 'package:omnicalc/services/feedback_service.dart';
import 'package:omnicalc/state/app_settings.dart';
import 'package:omnicalc/state/history_store.dart';
import 'package:omnicalc/state/settings_store.dart';
import 'package:omnicalc/theme/dynamic_colors.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final tab in ['Converter', 'Finance', 'Physics Lab', 'Chemistry', 'Grapher', 'Recents']) {
      testWidgets('$tab at 360, scale $scale', (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final msgs = <String>[];
        final old = FlutterError.onError;
        FlutterError.onError = (d) => msgs.add(d.exceptionAsString().split('\n').first);
        final store = SettingsStore.memory(const AppSettings(enableGrapher: true, enablePhysics: true, enableChemistry: true), true);
        await tester.pumpWidget(OmniCalcApp(
          settings: store,
          history: HistoryStore.memory(),
          systemColorsSource: const FakeSystemColorsSource(null),
          feedback: SilentFeedbackService(),
        ));
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.tap(find.text(tab).last, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 1500));
        FlutterError.onError = old;
        expect(msgs, isEmpty, reason: '$tab @ $scale: ${msgs.toSet().join(' / ')}');
      });
    }
  }
}
