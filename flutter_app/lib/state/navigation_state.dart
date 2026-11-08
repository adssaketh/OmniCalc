import 'dart:async';

import 'package:flutter/foundation.dart';

/// `CalculatorMode` (src/types/index.ts).
enum CalculatorMode { standard, scientific, converter, finance, physics, chemistry, grapher }

/// `NavItem` (src/navigation.ts). `id` is a CalculatorMode name or 'recents'.
class NavItem {
  const NavItem(this.id, this.label, this.railLabel);

  final String id;
  final String label;

  /// Shorter label for the navigation rail.
  final String railLabel;

  bool get isRecents => id == 'recents';

  CalculatorMode get mode => CalculatorMode.values.firstWhere((m) => m.name == id);
}

/// `getNavItems`: destinations in display order. Physics Lab and Chemistry (optional, off by default) sit after the
/// Converter, in that order.
List<NavItem> getNavItems(bool enableGrapher, [bool enablePhysics = false, bool enableChemistry = false]) {
  final items = <NavItem>[
    const NavItem('standard', 'Calculator', 'Calc'),
    const NavItem('converter', 'Converter', 'Convert'),
    const NavItem('finance', 'Finance', 'Finance'),
    const NavItem('recents', 'Recents', 'Recents'),
  ];
  if (enablePhysics) items.insert(2, const NavItem('physics', 'Physics Lab', 'Physics'));
  if (enableChemistry) items.insert(enablePhysics ? 3 : 2, const NavItem('chemistry', 'Chemistry', 'Chem'));
  if (enableGrapher) items.add(const NavItem('grapher', 'Grapher', 'Graph'));
  return items;
}

/// `isNavItemActive`.
bool isNavItemActive(NavItem item, CalculatorMode currentMode, bool isHistoryOpen) {
  if (item.isRecents) return isHistoryOpen;
  return !isHistoryOpen &&
      (currentMode.name == item.id || (currentMode == CalculatorMode.scientific && item.id == 'standard'));
}

/// What the back button / back gesture did (App.tsx, the Capacitor `backButton` listener).
enum BackAction { closedGuide, closedSettings, closedHistory, wentBack, showedExitHint, exitApp }

/// Navigation and overlay state of App.tsx: current screen, which layer is open, the trail of visited screens
/// (so back returns to the previous screen instead of leaving the app), and the text handed to the calculator.
class NavigationState extends ChangeNotifier {
  NavigationState({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  CalculatorMode _mode = CalculatorMode.standard;
  bool _isHistoryOpen = false;
  bool _isSettingsOpen = false;
  bool _isGuideOpen = false;
  String _externalExpression = '';
  int _externalSeq = 0;
  bool _exitHint = false;

  final List<CalculatorMode> _trail = <CalculatorMode>[];
  DateTime? _lastBackPress;
  Timer? _exitHintTimer;

  /// Settings registers a callback here that closes its own sub-sheet first; it returns true if it handled the press.
  bool Function()? innerBack;

  CalculatorMode get mode => _mode;
  bool get isHistoryOpen => _isHistoryOpen;
  bool get isSettingsOpen => _isSettingsOpen;
  bool get isGuideOpen => _isGuideOpen;
  String get externalExpression => _externalExpression;
  int get externalSeq => _externalSeq;

  /// "Press back again to exit" hint is showing.
  bool get exitHint => _exitHint;

  /// For tests.
  List<CalculatorMode> get trail => List.unmodifiable(_trail);

  /// `setCurrentMode` plus the trail effect of App.tsx: leaving a screen pushes it (max 20, oldest dropped) unless the
  /// move is a "back" step. Every path that changes the screen goes through here, including the automatic return to
  /// Calculator when Physics Lab or the Grapher is switched off (which also records the screen it left, as in the TS).
  void setMode(CalculatorMode next, {bool goingBack = false}) {
    if (next == _mode) return;
    if (!goingBack) {
      if (_trail.isEmpty || _trail.last != _mode) _trail.add(_mode);
      if (_trail.length > 20) _trail.removeAt(0);
    }
    _mode = next;
    notifyListeners();
  }

  /// A destination chosen from the bottom bar or the rail: `setIsHistoryOpen(false); setCurrentMode(mode);
  /// setExternalExpression('')`.
  void selectMode(CalculatorMode mode) {
    _isHistoryOpen = false;
    _externalExpression = '';
    setMode(mode);
    notifyListeners();
  }

  /// A launcher shortcut or deep link: same as [selectMode] and it also closes Settings.
  void openFromDeepLink(CalculatorMode mode) {
    _isSettingsOpen = false;
    selectMode(mode);
  }

  void toggleHistory() {
    _isHistoryOpen = !_isHistoryOpen;
    notifyListeners();
  }

  void setHistoryOpen(bool open) {
    if (_isHistoryOpen == open) return;
    _isHistoryOpen = open;
    notifyListeners();
  }

  void setSettingsOpen(bool open) {
    if (_isSettingsOpen == open) return;
    _isSettingsOpen = open;
    notifyListeners();
  }

  void toggleSettings() => setSettingsOpen(!_isSettingsOpen);

  void setGuideOpen(bool open) {
    if (_isGuideOpen == open) return;
    _isGuideOpen = open;
    notifyListeners();
  }

  /// `loadExpression`: the sequence number makes loading the same text twice work.
  void loadExpression(String expr) {
    _externalExpression = expr;
    _externalSeq++;
    notifyListeners();
  }

  /// `handleSelectResult`: a result picked from history or Physics goes into the calculator.
  void selectResult(String value) {
    loadExpression(value);
    setMode(CalculatorMode.standard);
  }

  /// A history entry's expression goes into the calculator (HistoryTapeModal `onSelectExpression`).
  void selectExpression(String expr) => selectResult(expr);

  /// `handleTryExample` without the angle change (the caller updates the setting): closes the guide and history,
  /// goes to the calculator and loads the example.
  void tryExample(String expr) {
    _isGuideOpen = false;
    _isHistoryOpen = false;
    setMode(CalculatorMode.standard);
    loadExpression(expr);
  }

  /// Settings or Grapher switched off while it is the current screen: back to the calculator.
  void enforceEnabledModes({required bool enableGrapher, required bool enablePhysics, bool enableChemistry = false}) {
    if (!enableGrapher && _mode == CalculatorMode.grapher) setMode(CalculatorMode.standard);
    if (!enablePhysics && _mode == CalculatorMode.physics) setMode(CalculatorMode.standard);
    if (!enableChemistry && _mode == CalculatorMode.chemistry) setMode(CalculatorMode.standard);
  }

  /// Android back button / back gesture: close the top layer first (guide, settings sub-sheet, settings, history),
  /// then go back screen by screen. Only from the very first screen does it ask to press back twice to leave.
  BackAction handleBack() {
    if (_isGuideOpen) {
      _isGuideOpen = false;
      notifyListeners();
      return BackAction.closedGuide;
    }
    if (_isSettingsOpen) {
      if (innerBack?.call() != true) _isSettingsOpen = false;
      notifyListeners();
      return BackAction.closedSettings;
    }
    if (_isHistoryOpen) {
      _isHistoryOpen = false;
      notifyListeners();
      return BackAction.closedHistory;
    }
    if (_trail.isNotEmpty) {
      final previous = _trail.removeLast();
      _externalExpression = '';
      setMode(previous, goingBack: true);
      notifyListeners();
      return BackAction.wentBack;
    }
    final now = _now();
    final last = _lastBackPress;
    if (last != null && now.difference(last) < const Duration(milliseconds: 2000)) {
      return BackAction.exitApp;
    }
    _lastBackPress = now;
    _exitHint = true;
    _exitHintTimer?.cancel();
    _exitHintTimer = Timer(const Duration(milliseconds: 2000), () {
      _exitHint = false;
      notifyListeners();
    });
    notifyListeners();
    return BackAction.showedExitHint;
  }

  @override
  void dispose() {
    _exitHintTimer?.cancel();
    super.dispose();
  }
}
