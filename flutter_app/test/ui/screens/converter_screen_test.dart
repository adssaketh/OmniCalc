import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/units.dart';
import 'package:omnicalc/main.dart';
import 'package:omnicalc/services/feedback_service.dart';
import 'package:omnicalc/state/app_settings.dart';
import 'package:omnicalc/state/history_store.dart';
import 'package:omnicalc/state/navigation_state.dart';
import 'package:omnicalc/state/settings_store.dart';
import 'package:omnicalc/theme/dynamic_colors.dart';
import 'package:omnicalc/ui/icons/lucide_icon.dart';
import 'package:omnicalc/ui/screens/converter_screen.dart';
import 'package:omnicalc/ui/shell/app_shell.dart';
import 'package:provider/provider.dart';

Future<SilentFeedbackService> pumpConverter(WidgetTester tester, {Size size = const Size(400, 1000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final feedback = SilentFeedbackService();
  await tester.pumpWidget(OmniCalcApp(
    settings: SettingsStore.memory(const AppSettings(), true),
    history: HistoryStore.memory(),
    systemColorsSource: const FakeSystemColorsSource(null),
    feedback: feedback,
  ));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 1500));
  Provider.of<NavigationState>(tester.element(find.byType(AppShell)), listen: false).setMode(CalculatorMode.converter);
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 1500));
  feedback.log.clear();
  return feedback;
}

String convertedText(WidgetTester tester) =>
    (tester.widget<Text>(find.byKey(const ValueKey('converted-value'))).textSpan! as TextSpan).children!.whereType<TextSpan>().first.text!;

void main() {
  test('formatting follows ConverterScreen.tsx', () {
    expect(formatConverted(0.001), '0.001');
    expect(formatConverted(1234.5678912), '1234.568');
    expect(formatConverted(1e9), '1.0000e+9');
    expect(formatConverted(0.00001), '1.0000e-5');
    expect(formatConverted(0), '0');
    expect(formatComparison(1e7), '1.000e+7');
    expect(formatComparison(3.28084), '3.2808');
  });

  test('every category has an icon', () {
    for (final c in unitCategories) {
      expect(() => converterIconFor(c.iconName), returnsNormally, reason: c.id);
    }
  });

  testWidgets('first render: 1 m to km, formula and comparison tiles', (tester) async {
    await pumpConverter(tester);
    expect(find.text('FROM UNIT'), findsOneWidget);
    expect(find.text('CONVERTED VALUE'), findsOneWidget);
    expect(convertedText(tester), '0.001');
    expect(find.textContaining('1 m = 0.001 km', findRichText: true), findsOneWidget);
    expect(find.text('ALL UNITS COMPARISON FOR 1 M'), findsOneWidget);
    // every other unit of length has a tile, the from unit has none
    expect(find.byKey(const ValueKey('compare-m')), findsNothing);
    expect(find.byKey(const ValueKey('compare-ft')), findsOneWidget);
  });

  testWidgets('every category tab carries an icon', (tester) async {
    await pumpConverter(tester);
    // 13 tab icons + 2 unit pickers' chevrons + swap + copy + clear
    final iconIds = tester.widgetList<LucideIcon>(find.byType(LucideIcon)).map((i) => i.id).toList();
    for (final c in unitCategories) {
      expect(iconIds, contains(converterIconFor(c.iconName)), reason: c.name);
    }
    expect(find.text('Length'), findsOneWidget);
  });

  testWidgets('typing a value and a preset', (tester) async {
    final fb = await pumpConverter(tester);
    await tester.enterText(find.byKey(const ValueKey('converter-input')), '2500');
    await tester.pump();
    expect(convertedText(tester), '2.5');
    await tester.tap(find.byKey(const ValueKey('preset-50')));
    await tester.pump();
    expect(convertedText(tester), '0.05');
    expect(fb.log, ['click:num', 'haptic:medium']);
  });

  testWidgets('clear button empties the input and the result is 0', (tester) async {
    final fb = await pumpConverter(tester);
    await tester.tap(find.byKey(const ValueKey('clear-input')));
    await tester.pump();
    expect(convertedText(tester), '0');
    expect(find.byKey(const ValueKey('clear-input')), findsNothing);
    expect(fb.log, ['click:clear', 'haptic:medium']);
  });

  testWidgets('swap exchanges the units', (tester) async {
    final fb = await pumpConverter(tester);
    await tester.tap(find.byKey(const ValueKey('swap-units')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(convertedText(tester), '1000');
    expect(find.textContaining('1 km = 1000 m', findRichText: true), findsOneWidget);
    expect(fb.log, ['click:op', 'haptic:medium']);
  });

  testWidgets('swap button: the whole 40 px circle takes touches on a phone (top edge swaps)', (tester) async {
    await pumpConverter(tester);
    final rect = tester.getRect(find.byKey(const ValueKey('swap-units')));
    expect(rect.height, 40);
    expect(rect.width, 40);
    // 2 px inside the top edge: this was outside the old 24 px hit box
    await tester.tapAt(Offset(rect.center.dx, rect.top + 2));
    await tester.pump(const Duration(milliseconds: 400));
    expect(convertedText(tester), '1000');
    // 2 px inside the bottom edge swaps back
    final rect2 = tester.getRect(find.byKey(const ValueKey('swap-units')));
    await tester.tapAt(Offset(rect2.center.dx, rect2.bottom - 2));
    await tester.pump(const Duration(milliseconds: 400));
    expect(convertedText(tester), '0.001');
  });

  testWidgets('tapping a comparison tile selects the target unit', (tester) async {
    await pumpConverter(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('compare-ft')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('compare-ft')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(convertedText(tester), '3.28084');
    expect(find.textContaining('1 m = 3.28084 ft', findRichText: true), findsOneWidget);
  });

  testWidgets('unit picker opens a list and applies the choice', (tester) async {
    final fb = await pumpConverter(tester);
    await tester.tap(find.byKey(const ValueKey('to-unit-select')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('option-mi')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('1 m = 0.000621371 mi', findRichText: true), findsOneWidget);
    expect(fb.log, ['click:toggle', 'haptic:medium']);
  });

  testWidgets('temperature tab resets the units and shows the text formula', (tester) async {
    // wide enough that the whole tab strip is on screen
    final fb = await pumpConverter(tester, size: const Size(1300, 1000));
    await tester.tap(find.text('Temperature'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(convertedText(tester), '33.8');
    expect(find.textContaining('(°C × 9/5) + 32 = °F', findRichText: true), findsOneWidget);
    expect(fb.log.take(2), ['click:toggle', 'haptic:medium']);
  });

  testWidgets('copy puts the converted value on the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final fb = await pumpConverter(tester);
    await tester.tap(find.byKey(const ValueKey('copy-result')));
    await tester.pump();
    expect(copied, '0.001');
    expect(fb.log, ['click:op', 'haptic:medium']);
    await tester.pump(const Duration(milliseconds: 2000)); // the tick goes back to the copy icon
  });

  testWidgets('two columns on a tablet, still one swap button', (tester) async {
    await pumpConverter(tester, size: const Size(900, 900));
    expect(find.byKey(const ValueKey('swap-units')), findsOneWidget);
    expect(convertedText(tester), '0.001');
  });
}
