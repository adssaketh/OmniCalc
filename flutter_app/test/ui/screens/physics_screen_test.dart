import 'package:flutter/material.dart' show TextField;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/physics.dart';
import 'package:omnicalc/main.dart';
import 'package:omnicalc/services/feedback_service.dart';
import 'package:omnicalc/state/app_settings.dart';
import 'package:omnicalc/state/history_store.dart';
import 'package:omnicalc/state/navigation_state.dart';
import 'package:omnicalc/state/settings_store.dart';
import 'package:omnicalc/theme/dynamic_colors.dart';
import 'package:omnicalc/ui/icons/lucide_icon.dart';
import 'package:omnicalc/ui/screens/physics_screen.dart';
import 'package:omnicalc/ui/shell/app_shell.dart';
import 'package:provider/provider.dart';

import '../../support/fake_currency.dart';

/// Opens Physics Lab at [size] (a tall window, so the whole page is laid out) and, when given, switches to [tabLabel]. The
/// window is never resized afterwards: a layout change remounts the screen and resets the active tab.
Future<SilentFeedbackService> pumpPhysics(
  WidgetTester tester, {
  String? tabLabel,
  Size size = const Size(400, 3600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final feedback = SilentFeedbackService();
  await tester.pumpWidget(OmniCalcApp(
    settings: SettingsStore.memory(const AppSettings(enablePhysics: true), true),
    history: HistoryStore.memory(),
    systemColorsSource: const FakeSystemColorsSource(null),
    feedback: feedback,
    currencyService: offlineCurrencyService(),
  ));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 1500));
  navOf(tester).setMode(CalculatorMode.physics);
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 1500));
  if (tabLabel != null) {
    // `.first`: the tab strip comes before the page (and "Electromagnetism" is also a category chip)
    await tester.ensureVisible(find.text(tabLabel).first);
    await tester.tap(find.text(tabLabel).first);
    await tester.pump(const Duration(milliseconds: 600));
  }
  feedback.log.clear();
  return feedback;
}

NavigationState navOf(WidgetTester tester) =>
    Provider.of<NavigationState>(tester.element(find.byType(AppShell)), listen: false);

String textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;

String fieldText(WidgetTester tester, String key) => tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

Future<void> typeInto(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey(key)), text);
  await tester.pump(const Duration(milliseconds: 100));
}

/// Mocks the clipboard and returns what was last copied.
String? Function() mockClipboard(WidgetTester tester) {
  String? copied;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return () => copied;
}

Finder rowOf(String id) => find.byKey(ValueKey('constant-row-$id'));

void main() {
  // Expected strings below come from running the TypeScript engine (src/engine/physics.ts and the formulas of
  // PhysicsScreen.tsx) with tsx.
  group('formulas of PhysicsScreen.tsx', () {
    test('constants value column: toExponential(6) above 1e4 and at or below 1e-3, the plain number otherwise', () {
      expect(formatConstantValue(299792458), '2.997925e+8');
      expect(formatConstantValue(6.6743e-11), '6.674300e-11');
      expect(formatConstantValue(9.80665), '9.80665');
      expect(formatConstantValue(0.0072973525693), '0.0072973525693');
      expect(formatConstantValue(0.00000125663706212), '1.256637e-6');
      expect(formatConstantValue(376.730313668), '376.730313668');
      expect(formatConstantValue(8.314462618), '8.314462618');
      expect(formatConstantValue(0.002897771955), '2.897772e-3');
      expect(formatConstantValue(6371000), '6.371000e+6');
      expect(formatConstantValue(0), '0');
    });

    test('constants filter: category and case-insensitive match on name, symbol, id and unit', () {
      List<String> ids(String q, String cat) => [for (final c in filterConstants(q, cat)) c.id];
      expect(physicalConstants.length, 29);
      expect(ids('', 'All').length, 29);
      expect(ids('planck', 'All'), ['h', 'hbar']);
      expect(ids('PLANCK', 'All'), ['h', 'hbar']);
      expect(ids('gas', 'All'), ['R']);
      expect(ids('', 'Electromagnetism'), ['e', 'eps0', 'mu0', 'ke', 'Z0']);
      expect(ids('electron', 'Quantum & Atomic'), ['me']);
      expect(ids('zzz', 'All'), isEmpty);
      // symbol and unit are searched too
      expect(ids('ℏ', 'All'), ['hbar']);
      expect(ids('kg²', 'All'), ['G']);
    });

    test('trajectory path and apex in the 400 x 120 SVG space', () {
      final r = PhysicsSolver.solveProjectile(30, 45, 0, 9.80665);
      final pts = trajectorySvgPoints(r);
      expect(pts.length, 41);
      expect(pts.first.dx, 10);
      expect(pts.first.dy, 115);
      expect(pts[20].dx, closeTo(200, 1e-9));
      expect(pts[20].dy, closeTo(23.695652173913047, 1e-9));
      expect(pts.last.dx, closeTo(390, 1e-9));
      expect(pts.last.dy, closeTo(115, 1e-9));
      final apex = trajectoryApex(r);
      expect(apex.dx, closeTo(200, 1e-9));
      expect(apex.dy, closeTo(115 - 105 / 1.15, 1e-12));
    });

    test('trajectory with no range sits at x = 10 and a flat shot stays on the ground line', () {
      final r = PhysicsSolver.solveProjectile(0, 45, 0, 9.80665);
      final pts = trajectorySvgPoints(r);
      expect(pts.every((p) => p.dx == 10), isTrue);
      expect(pts.every((p) => p.dy == 115), isTrue);
      expect(trajectoryApex(r).dx, 10);
    });
  });

  testWidgets('tab strip: five tabs with their icons, constants first', (tester) async {
    await pumpPhysics(tester);
    for (final label in ['Constants', 'Kinematics & Projectiles', 'Special Relativity', 'Quantum & Waves', 'Electromagnetism']) {
      expect(find.text(label), findsWidgets, reason: label); // "Electromagnetism" is also a category chip
    }
    final ids = tester.widgetList<LucideIcon>(find.byType(LucideIcon)).map((i) => i.id).toSet();
    expect(ids, containsAll([LucideIconId.atom, LucideIconId.orbit, LucideIconId.sparkles, LucideIconId.flame, LucideIconId.zap]));
    expect(find.byKey(const ValueKey('constants-table')), findsOneWidget);
  });

  group('constants tab', () {
    testWidgets('all 29 rows, with the formatted value', (tester) async {
      await pumpPhysics(tester);
      expect(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('constant-row-')), findsNWidgets(29));
      expect(textOf(tester, 'constant-value-c'), '2.997925e+8');
      expect(textOf(tester, 'constant-value-g'), '9.80665');
      expect(textOf(tester, 'constant-value-mu0'), '1.256637e-6');
      expect(find.text('Speed of Light in Vacuum'), findsOneWidget);
      expect(find.text('m / s'), findsWidgets);
    });

    testWidgets('search narrows the table', (tester) async {
      await pumpPhysics(tester);
      await typeInto(tester, 'constants-search', 'planck');
      expect(rowOf('h'), findsOneWidget);
      expect(rowOf('hbar'), findsOneWidget);
      expect(rowOf('c'), findsNothing);
      await typeInto(tester, 'constants-search', 'zzz');
      expect(rowOf('h'), findsNothing);
      await typeInto(tester, 'constants-search', '');
      expect(rowOf('c'), findsOneWidget);
    });

    testWidgets('category chips filter, play the toggle click, and combine with the search', (tester) async {
      final fb = await pumpPhysics(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('constants-category-Electromagnetism')));
      await tester.tap(find.byKey(const ValueKey('constants-category-Electromagnetism')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(fb.log, ['click:toggle', 'haptic:medium']);
      expect(rowOf('e'), findsOneWidget);
      expect(rowOf('Z0'), findsOneWidget);
      expect(rowOf('c'), findsNothing);
      expect(rowOf('me'), findsNothing);

      await tester.ensureVisible(find.byKey(const ValueKey('constants-category-Quantum & Atomic')));
      await tester.tap(find.byKey(const ValueKey('constants-category-Quantum & Atomic')));
      await tester.pump(const Duration(milliseconds: 300));
      await typeInto(tester, 'constants-search', 'electron');
      expect(rowOf('me'), findsOneWidget);
      expect(rowOf('h'), findsNothing);

      await tester.ensureVisible(find.byKey(const ValueKey('constants-category-All')));
      await tester.tap(find.byKey(const ValueKey('constants-category-All')));
      await tester.pump(const Duration(milliseconds: 300));
      await typeInto(tester, 'constants-search', '');
      expect(rowOf('c'), findsOneWidget);
    });

    testWidgets('copy puts the JS string of the number on the clipboard and shows a tick for 1.8 s', (tester) async {
      final copied = mockClipboard(tester);
      final fb = await pumpPhysics(tester);
      Iterable<LucideIconId> iconsIn(String id) => tester
          .widgetList<LucideIcon>(find.descendant(of: find.byKey(ValueKey('constant-copy-$id')), matching: find.byType(LucideIcon)))
          .map((i) => i.id);

      await tester.ensureVisible(find.byKey(const ValueKey('constant-copy-c')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('constant-copy-c')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(copied(), '299792458');
      expect(fb.log, ['click:op', 'haptic:medium']);
      expect(iconsIn('c'), [LucideIconId.check]);
      await tester.pump(const Duration(milliseconds: 2000));
      expect(iconsIn('c'), [LucideIconId.copy]);

      // numbers that JavaScript prints without an exponent below 1e-6 keep the long form
      await tester.ensureVisible(find.byKey(const ValueKey('constant-copy-mu0')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('constant-copy-mu0')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(copied(), '0.00000125663706212');
      await tester.pump(const Duration(milliseconds: 2000));
    });

    testWidgets('Calc sends the value to the calculator', (tester) async {
      final fb = await pumpPhysics(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('constant-insert-c')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('constant-insert-c')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(fb.log.take(2), ['click:op', 'haptic:medium']);
      expect(navOf(tester).mode, CalculatorMode.standard);
      expect(navOf(tester).externalExpression, '299792458');
    });

    testWidgets('empty result list leaves just the header', (tester) async {
      await pumpPhysics(tester);
      await typeInto(tester, 'constants-search', 'zzz');
      expect(find.text('Constant Name'), findsOneWidget);
      expect(find.text('Actions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('projectile tab', () {
    testWidgets('defaults: 30 m/s at 45 degrees', (tester) async {
      final fb = await pumpPhysics(tester, tabLabel: 'Kinematics & Projectiles');
      expect(fieldText(tester, 'proj-v0'), '30');
      expect(fieldText(tester, 'proj-angle'), '45');
      expect(fieldText(tester, 'proj-h0'), '0');
      expect(fieldText(tester, 'proj-g'), '9.80665');
      expect(textOf(tester, 'proj-range'), '91.77 m');
      expect(textOf(tester, 'proj-max-height'), '22.94 m');
      expect(textOf(tester, 'proj-time'), '4.33 s');
      expect(textOf(tester, 'proj-impact'), '30.00 m/s');
      expect(textOf(tester, 'proj-stats'), 'Max H: 22.94 m · Range: 91.77 m');
      expect(find.text('Trajectory Curve y(x)'), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('trajectory-svg'))).height, 144);
      expect(fb.log, isEmpty);
    });

    testWidgets('typing updates every result', (tester) async {
      await pumpPhysics(tester, tabLabel: 'Kinematics & Projectiles');
      await typeInto(tester, 'proj-v0', '20');
      await typeInto(tester, 'proj-angle', '30');
      await typeInto(tester, 'proj-h0', '10');
      await typeInto(tester, 'proj-g', '9.81');
      expect(textOf(tester, 'proj-range'), '48.04 m');
      expect(textOf(tester, 'proj-max-height'), '15.10 m');
      expect(textOf(tester, 'proj-time'), '2.77 s');
      expect(textOf(tester, 'proj-impact'), '24.42 m/s');
    });

    testWidgets('clearing a field reads 0, clearing gravity falls back to 9.81', (tester) async {
      await pumpPhysics(tester, tabLabel: 'Kinematics & Projectiles');
      await typeInto(tester, 'proj-v0', '');
      expect(fieldText(tester, 'proj-v0'), '0');
      expect(textOf(tester, 'proj-range'), '0.00 m');
      await typeInto(tester, 'proj-g', '');
      expect(fieldText(tester, 'proj-g'), '9.81');
    });

    testWidgets('a half-typed number keeps its text while the state follows parseFloat', (tester) async {
      await pumpPhysics(tester, tabLabel: 'Kinematics & Projectiles');
      await typeInto(tester, 'proj-v0', '2.');
      expect(fieldText(tester, 'proj-v0'), '2.');
      await typeInto(tester, 'proj-v0', '2.5e');
      // '2.5e' is not a valid number for the browser, so the field reports '' and the state is 0
      expect(fieldText(tester, 'proj-v0'), '0');
    });
  });

  group('relativity tab', () {
    testWidgets('defaults: beta 0.8', (tester) async {
      await pumpPhysics(tester, tabLabel: 'Special Relativity');
      expect(fieldText(tester, 'rel-beta'), '0.8');
      expect(textOf(tester, 'rel-gamma'), '1.6667');
      expect(textOf(tester, 'rel-time'), '16.667 s');
      expect(textOf(tester, 'rel-length'), '60.000 m');
      expect(textOf(tester, 'rel-momentum'), '3.997e+8 kg·m/s');
      expect(textOf(tester, 'rel-rest-energy'), '8.9876e+16 J');
      expect(textOf(tester, 'rel-kinetic-energy'), '5.9917e+16 J');
      expect(textOf(tester, 'rel-total-energy'), '1.4979e+17 J');
      expect(find.text('Kinetic Energy K = (γ - 1)m₀c²'), findsOneWidget);
    });

    testWidgets('beta 0.6, 5 s, 50 m, 2 kg', (tester) async {
      await pumpPhysics(tester, tabLabel: 'Special Relativity');
      await typeInto(tester, 'rel-beta', '0.6');
      await typeInto(tester, 'rel-t0', '5');
      await typeInto(tester, 'rel-l0', '50');
      await typeInto(tester, 'rel-m0', '2');
      expect(textOf(tester, 'rel-gamma'), '1.2500');
      expect(textOf(tester, 'rel-time'), '6.250 s');
      expect(textOf(tester, 'rel-length'), '40.000 m');
      expect(textOf(tester, 'rel-momentum'), '4.497e+8 kg·m/s');
    });
  });

  group('quantum tab', () {
    testWidgets('defaults: 550 nm, sodium work function', (tester) async {
      await pumpPhysics(tester, tabLabel: 'Quantum & Waves');
      expect(fieldText(tester, 'q-input'), '550');
      expect(fieldText(tester, 'q-phi'), '2.3');
      expect(find.text('Value (nm)'), findsOneWidget);
      expect(textOf(tester, 'q-wavelength'), '550.00 nm');
      expect(textOf(tester, 'q-frequency'), '5.451e+14 Hz');
      expect(textOf(tester, 'q-energy'), '2.254 eV');
      expect(textOf(tester, 'q-momentum'), '1.205e-27 kg·m/s');
      expect(textOf(tester, 'q-cutoff'), '5.561e+14 Hz');
      expect(textOf(tester, 'q-kmax'), '0.000 eV');
      expect(textOf(tester, 'q-stopping'), '0.000 V');
      expect(find.text('Photoelectric Effect Evaluation'), findsOneWidget);
    });

    testWidgets('the mode picker switches the input unit, plays the toggle click and applies its choice', (tester) async {
      final fb = await pumpPhysics(tester, tabLabel: 'Quantum & Waves');
      await tester.tap(find.byKey(const ValueKey('q-mode')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('option-frequency')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(fb.log.take(2), ['click:toggle', 'haptic:medium']);
      expect(find.text('Value (Hz)'), findsOneWidget);
      await typeInto(tester, 'q-input', '1e15');
      expect(fieldText(tester, 'q-input'), '1e15');
      expect(textOf(tester, 'q-wavelength'), '299.79 nm');
      expect(textOf(tester, 'q-frequency'), '1.000e+15 Hz');
      expect(textOf(tester, 'q-energy'), '4.136 eV');
      expect(textOf(tester, 'q-momentum'), '2.210e-27 kg·m/s');
      expect(textOf(tester, 'q-kmax'), '1.836 eV');

      await tester.tap(find.byKey(const ValueKey('q-mode')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('option-energyEv')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Value (eV)'), findsOneWidget);
      await typeInto(tester, 'q-input', '3');
      expect(textOf(tester, 'q-wavelength'), '413.28 nm');
      expect(textOf(tester, 'q-frequency'), '7.254e+14 Hz');
      expect(textOf(tester, 'q-energy'), '3.000 eV');
      expect(textOf(tester, 'q-momentum'), '1.603e-27 kg·m/s');
      expect(textOf(tester, 'q-kmax'), '0.700 eV');
      expect(textOf(tester, 'q-stopping'), '0.700 V');
    });
  });

  group('electromagnetism tab', () {
    testWidgets('defaults: 1 uC and 2 uC at 5 cm', (tester) async {
      await pumpPhysics(tester, tabLabel: 'Electromagnetism');
      expect(fieldText(tester, 'em-q1'), '0.000001');
      expect(fieldText(tester, 'em-q2'), '0.000002');
      expect(fieldText(tester, 'em-dist'), '0.05');
      expect(fieldText(tester, 'em-b'), '0.5');
      expect(fieldText(tester, 'em-vel'), '2000000');
      expect(textOf(tester, 'em-force'), '7.190e+0 N');
      expect(textOf(tester, 'em-radius'), '3.644e-18 m');
      expect(textOf(tester, 'em-freq'), '8.736e+22 Hz');
    });

    testWidgets('q1 = 0 gives no force and the electron charge is used for the cyclotron motion', (tester) async {
      await pumpPhysics(tester, tabLabel: 'Electromagnetism');
      await typeInto(tester, 'em-q1', '0');
      expect(fieldText(tester, 'em-q1'), '0');
      expect(textOf(tester, 'em-force'), '0.000e+0 N');
      expect(textOf(tester, 'em-radius'), '2.274e-5 m');
      expect(textOf(tester, 'em-freq'), '1.400e+10 Hz');
    });

    testWidgets('clearing the distance falls back to 0.01 m', (tester) async {
      await pumpPhysics(tester, tabLabel: 'Electromagnetism');
      await typeInto(tester, 'em-dist', '');
      expect(fieldText(tester, 'em-dist'), '0.01');
    });
  });

  group('layout', () {
    testWidgets('tab switching plays the toggle click', (tester) async {
      final fb = await pumpPhysics(tester);
      await tester.ensureVisible(find.text('Special Relativity'));
      await tester.tap(find.text('Special Relativity'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(fb.log.take(2), ['click:toggle', 'haptic:medium']);
      expect(find.byKey(const ValueKey('rel-gamma')), findsOneWidget);
    });

    testWidgets('tablet width: search box and chip strip share one row, no layout errors', (tester) async {
      await pumpPhysics(tester, size: const Size(900, 2400));
      final search = tester.getSize(find.byKey(const ValueKey('constants-search')));
      expect(search.width, greaterThan(0));
      final chips = tester.getRect(find.byKey(const ValueKey('constants-chips')));
      final field = tester.getRect(find.byKey(const ValueKey('constants-search')));
      expect(chips.left, greaterThan(field.right));
      expect(tester.takeException(), isNull);
    });

    testWidgets('tablet width: the solver tabs build', (tester) async {
      await pumpPhysics(tester, tabLabel: 'Kinematics & Projectiles', size: const Size(900, 2400));
      expect(textOf(tester, 'proj-range'), '91.77 m');
      expect(tester.takeException(), isNull);
    });

    testWidgets('phone width: chip strip sits under the search box', (tester) async {
      await pumpPhysics(tester);
      final chips = tester.getRect(find.byKey(const ValueKey('constants-chips')));
      final field = tester.getRect(find.byKey(const ValueKey('constants-search')));
      expect(chips.top, greaterThan(field.bottom));
      expect(tester.takeException(), isNull);
    });
  });
}
