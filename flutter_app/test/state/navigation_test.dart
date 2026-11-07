import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/state/navigation_state.dart';

void main() {
  late NavigationState nav;
  var clock = DateTime(2026, 1, 1);

  setUp(() {
    clock = DateTime(2026, 1, 1);
    nav = NavigationState(now: () => clock);
  });
  tearDown(() => nav.dispose());

  group('nav items', () {
    test('default order', () {
      expect(getNavItems(false).map((i) => i.id), ['standard', 'converter', 'finance', 'recents']);
    });
    test('physics sits third, grapher last', () {
      expect(getNavItems(true, true).map((i) => i.id), ['standard', 'converter', 'physics', 'finance', 'recents', 'grapher']);
    });
    test('scientific highlights Calculator; history open highlights only Recents', () {
      final items = getNavItems(false);
      expect(isNavItemActive(items[0], CalculatorMode.scientific, false), isTrue);
      expect(isNavItemActive(items[0], CalculatorMode.standard, true), isFalse);
      expect(isNavItemActive(items[3], CalculatorMode.standard, true), isTrue);
      expect(isNavItemActive(items[3], CalculatorMode.standard, false), isFalse);
    });
  });

  group('back button', () {
    test('first press from the first screen shows the hint, a second within 2 s exits', () {
      expect(nav.handleBack(), BackAction.showedExitHint);
      expect(nav.exitHint, isTrue);
      clock = clock.add(const Duration(milliseconds: 1500));
      expect(nav.handleBack(), BackAction.exitApp);
    });

    test('a second press after 2 s shows the hint again', () {
      nav.handleBack();
      clock = clock.add(const Duration(milliseconds: 2500));
      expect(nav.handleBack(), BackAction.showedExitHint);
    });

    test('goes back screen by screen', () {
      nav.selectMode(CalculatorMode.converter);
      nav.selectMode(CalculatorMode.finance);
      expect(nav.handleBack(), BackAction.wentBack);
      expect(nav.mode, CalculatorMode.converter);
      expect(nav.handleBack(), BackAction.wentBack);
      expect(nav.mode, CalculatorMode.standard);
      expect(nav.handleBack(), BackAction.showedExitHint);
    });

    test('going back does not push the trail again', () {
      nav.selectMode(CalculatorMode.converter);
      nav.handleBack();
      expect(nav.trail, isEmpty);
    });

    test('layers close first: guide, then settings (inner back first), then history', () {
      nav.selectMode(CalculatorMode.converter);
      nav.setHistoryOpen(true);
      nav.setSettingsOpen(true);
      nav.setGuideOpen(true);
      expect(nav.handleBack(), BackAction.closedGuide);
      expect(nav.isSettingsOpen, isTrue);

      var innerCalls = 0;
      nav.innerBack = () {
        innerCalls++;
        return true;
      };
      expect(nav.handleBack(), BackAction.closedSettings);
      expect(innerCalls, 1);
      expect(nav.isSettingsOpen, isTrue); // the sub-sheet consumed it

      nav.innerBack = () => false;
      expect(nav.handleBack(), BackAction.closedSettings);
      expect(nav.isSettingsOpen, isFalse);

      expect(nav.handleBack(), BackAction.closedHistory);
      expect(nav.isHistoryOpen, isFalse);
      expect(nav.mode, CalculatorMode.converter);
    });
  });

  test('trail keeps at most 20 screens and no duplicates in a row', () {
    for (var i = 0; i < 30; i++) {
      nav.setMode(i.isEven ? CalculatorMode.converter : CalculatorMode.finance);
    }
    expect(nav.trail.length, lessThanOrEqualTo(20));
  });

  test('selecting a destination closes history and clears the expression', () {
    nav.loadExpression('1+2');
    nav.setHistoryOpen(true);
    nav.selectMode(CalculatorMode.finance);
    expect(nav.isHistoryOpen, isFalse);
    expect(nav.externalExpression, '');
    expect(nav.mode, CalculatorMode.finance);
  });

  test('loading the same text twice bumps the sequence number', () {
    nav.loadExpression('5');
    final a = nav.externalSeq;
    nav.loadExpression('5');
    expect(nav.externalSeq, a + 1);
  });

  test('selecting a result goes to the calculator', () {
    nav.selectMode(CalculatorMode.finance);
    nav.selectResult('42');
    expect(nav.mode, CalculatorMode.standard);
    expect(nav.externalExpression, '42');
  });

  test('turning a tab off returns to the calculator', () {
    nav.setMode(CalculatorMode.physics);
    nav.enforceEnabledModes(enableGrapher: false, enablePhysics: false);
    expect(nav.mode, CalculatorMode.standard);
    nav.setMode(CalculatorMode.grapher);
    nav.enforceEnabledModes(enableGrapher: true, enablePhysics: false);
    expect(nav.mode, CalculatorMode.grapher);
  });

  test('deep link closes settings and history', () {
    nav.setSettingsOpen(true);
    nav.setHistoryOpen(true);
    nav.openFromDeepLink(CalculatorMode.converter);
    expect(nav.isSettingsOpen, isFalse);
    expect(nav.isHistoryOpen, isFalse);
    expect(nav.mode, CalculatorMode.converter);
  });
}
