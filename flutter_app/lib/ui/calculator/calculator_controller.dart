import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../engine/calc_error.dart';
import '../../engine/evaluator.dart';
import '../../engine/types.dart';
import '../../services/feedback_service.dart';
import '../../state/history_store.dart';

/// `AdvancedTab` of CalculatorScreen.tsx.
enum AdvancedTab { calculus, trig, powers, prob, constants }

/// `ADVANCED_TABS` (id, label, badge).
const List<({AdvancedTab id, String label, String badge})> advancedTabDefs = [
  (id: AdvancedTab.calculus, label: 'Calculus', badge: '∫'),
  (id: AdvancedTab.trig, label: 'Trig & Hyp', badge: 'sin'),
  (id: AdvancedTab.powers, label: 'Powers', badge: 'xʸ'),
  (id: AdvancedTab.prob, label: 'Probability', badge: 'nCr'),
  (id: AdvancedTab.constants, label: 'Constants', badge: 'π'),
];

/// Memory ribbon actions (`handleMemory`).
enum MemoryAction { mc, mr, mPlus, mMinus, ms }

/// Receives a finished calculation (`onAddHistory`).
typedef AddHistory = void Function({required String expression, required String result, required String mode});

/// Writes text to the clipboard (`navigator.clipboard.writeText`).
typedef ClipboardWriter = Future<void> Function(String text);

Future<void> _systemClipboard(String text) => Clipboard.setData(ClipboardData(text: text));

const List<String> _operatorChars = ['+', '−', '×', '÷', '(', '^', ',', ' '];

/// Tokens that Backspace removes as one piece, in the order CalculatorScreen.tsx tests them.
const List<String> _multiCharTokens = [
  'integrate(', 'randInt(', 'diff(', 'limit(', 'y=', 'y(', 'sum(', 'prod(', 'nCr(', 'nPr(',
  'gcd(', 'lcm(', 'mod(', 'root(', 'logb(', 'rand()',
  'asinh(', 'acosh(', 'atanh(', 'sech(', 'csch(', 'coth(',
  'sinh(', 'cosh(', 'tanh(', 'asin(', 'acos(', 'atan(',
  'sec(', 'csc(', 'cot(',
  'sin(', 'cos(', 'tan(', 'log2(', 'log(', 'ln(', 'exp(',
  'sqrt(', 'cbrt(', 'round(', 'floor(', 'ceil(', 'sign(', 'abs(',
];

final RegExp _reYDef = RegExp(r'^\s*y\s*=\s*(.+)$', caseSensitive: false);
final RegExp _reYStart = RegExp(r'^\s*y\s*=', caseSensitive: false);
final RegExp _rePlainNumber = RegExp(r'^[−-]?\d+(\.\d+)?$');
final RegExp _reErrorResult = RegExp(r'^[−-]?(\d[\d.,]*(e[+-]?\d+)?|Infinity)$', caseSensitive: false);
final RegExp _reHyperbolicNames =
    RegExp(r'\b(asinh|acosh|atanh|sinh|cosh|tanh|sech|csch|coth|sqrt|cbrt|log2)\b', caseSensitive: false);
final RegExp _reAnyY = RegExp('y', caseSensitive: false);
final RegExp _reSegmentSplit = RegExp(r'[\+\−\×\÷\^\(\)\%,]');
final RegExp _rePasteAllowed = RegExp(r'^[0-9+\-*/÷×^().,%!a-zA-Z_]+$');

String _lastChar(String s) => s.isEmpty ? '' : s.substring(s.length - 1);
int _count(String s, String ch) => ch.allMatches(s).length;

/// The state and the key handlers of CalculatorScreen.tsx, without any drawing.
///
/// Every handler is a line-by-line port of the React callback of the same name. The screen only forwards taps.
class CalculatorController extends ChangeNotifier {
  CalculatorController({
    required this.feedback,
    this.onAddHistory,
    ClipboardWriter? clipboard,
    AngleMode angleMode = AngleMode.deg,
    int decimalPrecision = -1,
    bool soundEnabled = true,
    bool hapticEnabled = true,
  })  : _clipboard = clipboard ?? _systemClipboard,
        _angleMode = angleMode,
        _decimalPrecision = decimalPrecision,
        _soundEnabled = soundEnabled,
        _hapticEnabled = hapticEnabled,
        _equation = MathEvaluator.getYDefinition();

  final FeedbackService feedback;
  AddHistory? onAddHistory;
  final ClipboardWriter _clipboard;

  // -- Settings that come from outside (props of the React component) --------------------------------------------
  AngleMode _angleMode;
  int _decimalPrecision;
  bool _soundEnabled;
  bool _hapticEnabled;
  List<HistoryItem> _history = const [];

  AngleMode get angleMode => _angleMode;
  int get decimalPrecision => _decimalPrecision;
  List<HistoryItem> get history => _history;

  /// Called by the screen whenever a prop changes. Does not notify while building.
  void updateProps({
    required AngleMode angleMode,
    required int decimalPrecision,
    required bool soundEnabled,
    required bool hapticEnabled,
    required List<HistoryItem> history,
  }) {
    final changed = angleMode != _angleMode ||
        decimalPrecision != _decimalPrecision ||
        !identical(history, _history);
    _angleMode = angleMode;
    _decimalPrecision = decimalPrecision;
    _soundEnabled = soundEnabled;
    _hapticEnabled = hapticEnabled;
    _history = history;
    if (changed) _livePreviewKey = null;
  }

  // -- State ------------------------------------------------------------------------------------------------------
  String _expression = '0';
  String _lastQuestion = '';
  String _lastAnswer = '';

  /// Equation saved with y = ... ; while it is set, typing a number and pressing = gives y at that x.
  String? _equation;
  double _memory = 0;
  bool _isScientific = false;
  AdvancedTab _advancedTab = AdvancedTab.calculus;
  bool _copied = false;
  bool _hasEvaluated = false;
  bool _isEqualsPressed = false;
  int _historyIndex = -1;
  Timer? _copiedTimer;
  Timer? _equalsTimer;

  String get expression => _expression;
  String get lastQuestion => _lastQuestion;
  String get lastAnswer => _lastAnswer;
  String? get equation => _equation;
  double get memory => _memory;
  bool get isScientific => _isScientific;
  AdvancedTab get advancedTab => _advancedTab;
  bool get copied => _copied;
  bool get hasEvaluated => _hasEvaluated;
  bool get isEqualsPressed => _isEqualsPressed;
  int get historyIndex => _historyIndex;

  /// JavaScript truthiness of `equation` (a string): null and '' are falsy.
  bool get hasEquation => _equation != null && _equation!.isNotEmpty;

  /// Unmatched open parentheses (`getOpenParensCount`).
  int get openParensCount {
    var count = 0;
    for (final unit in _expression.codeUnits) {
      if (unit == 0x28) {
        count++;
      } else if (unit == 0x29) {
        count--;
      }
    }
    return count < 0 ? 0 : count;
  }

  /// After pressing = the display holds either a number or an error message; messages are shown small and in full.
  bool get isErrorResult => _hasEvaluated && !_reErrorResult.hasMatch(_expression.trim());

  /// `playSound`: click sound and haptic tick, each only when enabled.
  void playSound([ClickType type = ClickType.num]) {
    if (_soundEnabled) feedback.playClick(type);
    if (_hapticEnabled) feedback.triggerHaptic();
  }

  // -- External expression (history tape, deep link) --------------------------------------------------------------
  /// The `useEffect` on `externalExpression` / `externalSeq`: loads text from outside; empty text is ignored.
  void loadExternal(String expression) {
    if (expression.isEmpty) return;
    _expression = expression;
    _lastQuestion = '';
    _lastAnswer = '';
    _hasEvaluated = false;
    notifyListeners();
  }

  // -- Handlers ---------------------------------------------------------------------------------------------------
  void handleInput(String token) {
    playSound(ClickType.num);
    final prev = _expression;
    if (_hasEvaluated) {
      _hasEvaluated = false;
      _lastQuestion = '';
      _lastAnswer = '';
      if (const ['+', '−', '×', '÷', '^', '%'].contains(token) || token.startsWith('^')) {
        _expression = prev + token;
      } else {
        _expression = token;
      }
      notifyListeners();
      return;
    }

    if (prev == '0' &&
        !const ['.', '+', '−', '×', '÷', '^', '%', '!', ')'].contains(token) &&
        !token.startsWith('^')) {
      _expression = token;
      notifyListeners();
      return;
    }

    if (token == '.') {
      final segments = prev.split(_reSegmentSplit);
      final lastSegment = segments.last;
      if (lastSegment.contains('.')) {
        notifyListeners();
        return;
      }
    }

    _expression = prev + token;
    notifyListeners();
  }

  /// Insert a function such as `sin(`.
  void handleFunction(String fnName) {
    playSound(ClickType.op);
    final prev = _expression;
    if (_hasEvaluated) {
      _hasEvaluated = false;
      _lastQuestion = '';
      _lastAnswer = '';
      _expression = '$fnName($prev)';
      notifyListeners();
      return;
    }
    if (prev == '0') {
      _expression = '$fnName(';
    } else if (_operatorChars.contains(_lastChar(prev))) {
      _expression = '$prev$fnName(';
    } else {
      _expression = '$prev×$fnName(';
    }
    notifyListeners();
  }

  /// Insert a template such as `diff(`, `integrate(`, `sum(`.
  void handleInsertTemplate(String template) {
    playSound(ClickType.op);
    final prev = _expression;
    if (_hasEvaluated || prev == '0') {
      _hasEvaluated = false;
      _lastQuestion = '';
      _lastAnswer = '';
      _expression = template;
      notifyListeners();
      return;
    }
    if (_operatorChars.contains(_lastChar(prev))) {
      _expression = '$prev$template';
    } else {
      _expression = '$prev×$template';
    }
    notifyListeners();
  }

  void handleParentheses() {
    playSound(ClickType.op);
    final prev = _expression;
    if (_hasEvaluated) {
      _hasEvaluated = false;
      _expression = '(';
      notifyListeners();
      return;
    }
    final openCount = _count(prev, '(');
    final closeCount = _count(prev, ')');
    final last = _lastChar(prev);

    if (openCount > closeCount && !_operatorChars.contains(last)) {
      _expression = '$prev)';
    } else if (const ['+', '−', '×', '÷', '(', '^', '%', ',', ' '].contains(last) || prev == '0') {
      _expression = prev == '0' ? '(' : '$prev(';
    } else {
      _expression = '$prev×(';
    }
    notifyListeners();
  }

  void handleClear() {
    playSound(ClickType.clear);
    // AC on an already empty display also forgets the saved y = ... equation
    if (_expression == '0' && !_hasEvaluated && hasEquation) {
      MathEvaluator.setYDefinition(null);
      _equation = null;
    }
    _expression = '0';
    _lastQuestion = '';
    _lastAnswer = '';
    _hasEvaluated = false;
    notifyListeners();
  }

  void handleBackspace() {
    playSound(ClickType.op);
    final prev = _expression;
    if (_hasEvaluated) {
      _hasEvaluated = false;
      _expression = '0';
      notifyListeners();
      return;
    }
    if (prev.length <= 1) {
      _expression = '0';
      notifyListeners();
      return;
    }
    for (final token in _multiCharTokens) {
      if (prev.endsWith(token)) {
        final cut = prev.substring(0, prev.length - token.length);
        _expression = cut.isEmpty ? '0' : cut;
        notifyListeners();
        return;
      }
    }
    _expression = prev.substring(0, prev.length - 1);
    notifyListeners();
  }

  // -- Live preview -------------------------------------------------------------------------------------------------
  String? _livePreviewKey;
  String _livePreviewValue = '';

  /// Small answer under the expression while typing; mirrors what = would calculate (`livePreview`).
  String get livePreview {
    final key = '$_hasEvaluated|$_expression|$_equation|${_angleMode.id}|$_decimalPrecision';
    if (key == _livePreviewKey) return _livePreviewValue;
    _livePreviewKey = key;
    _livePreviewValue = _computeLivePreview();
    return _livePreviewValue;
  }

  String _computeLivePreview() {
    if (_hasEvaluated) return '';
    final trimmed = _expression.trim();
    if (trimmed.isEmpty || _reYStart.hasMatch(trimmed)) return '';
    final isPlainNumber = _rePlainNumber.hasMatch(trimmed);
    if (isPlainNumber && !hasEquation) return '';
    try {
      var exprToEval = trimmed;
      final openCount = _count(exprToEval, '(');
      final closeCount = _count(exprToEval, ')');
      if (openCount > closeCount) exprToEval += ')' * (openCount - closeCount);
      if (hasEquation && isPlainNumber) exprToEval = 'y($trimmed)';
      final formatted = MathEvaluator.formatResult(MathEvaluator.evaluate(exprToEval, _angleMode), _decimalPrecision);
      return formatted == trimmed ? '' : formatted;
    } catch (_) {
      return '';
    }
  }

  // -- Evaluate -----------------------------------------------------------------------------------------------------
  void handleEvaluate() {
    playSound(ClickType.eval);
    try {
      var exprToEval = _expression;
      final openCount = _count(exprToEval, '(');
      final closeCount = _count(exprToEval, ')');
      if (openCount > closeCount) {
        exprToEval = exprToEval + ')' * (openCount - closeCount);
      }

      // y = f(x): save the equation (nothing is calculated yet)
      final defMatch = _reYDef.firstMatch(exprToEval);
      if (defMatch != null) {
        final def = defMatch.group(1)!.trim();
        if (_reAnyY.hasMatch(def.replaceAll(_reHyperbolicNames, ''))) {
          throw const CalcError('Use only x on the right of y =');
        }
        final probes = <double>[1, 2, 0.5, -1].map((x) => MathEvaluator.evaluateFunction(def, x, _angleMode));
        if (probes.every((v) => v.isNaN)) {
          throw const CalcError('Could not read that equation. Example: y=x^2−5x+6');
        }
        MathEvaluator.setYDefinition(def);
        _equation = def;
        _lastQuestion = '';
        _lastAnswer = '';
        _expression = '0';
        _hasEvaluated = false;
        notifyListeners();
        return;
      }

      // With an equation saved, a plain number means "give me y at this x"
      var shown = _expression;
      if (hasEquation && !_hasEvaluated && _rePlainNumber.hasMatch(exprToEval.trim())) {
        exprToEval = 'y(${exprToEval.trim()})';
        shown = exprToEval;
      }

      final result = MathEvaluator.evaluate(exprToEval, _angleMode);
      final formatted = MathEvaluator.formatResult(result, _decimalPrecision);

      _lastQuestion = shown;
      _lastAnswer = formatted;

      onAddHistory?.call(expression: shown, result: formatted, mode: _isScientific ? 'scientific' : 'standard');

      _expression = formatted;
      _hasEvaluated = true;
    } catch (err) {
      final msg = err is CalcError ? err.message : 'Error';
      _lastQuestion = _expression;
      _lastAnswer = msg;
      _expression = msg;
      _hasEvaluated = true;
    }
    notifyListeners();
  }

  // -- Memory -------------------------------------------------------------------------------------------------------
  void handleMemory(MemoryAction action) {
    playSound(ClickType.op);
    try {
      // The expression is evaluated first, whatever the action: when it does not evaluate nothing happens.
      final currentVal = MathEvaluator.evaluate(_expression, _angleMode);
      switch (action) {
        case MemoryAction.mc:
          _memory = 0;
        case MemoryAction.mr:
          _expression = MathEvaluator.formatResult(_memory, _decimalPrecision);
          _hasEvaluated = true;
        case MemoryAction.ms:
          _memory = currentVal;
        case MemoryAction.mPlus:
          _memory = _memory + currentVal;
        case MemoryAction.mMinus:
          _memory = _memory - currentVal;
      }
    } catch (_) {
      // ignore
    }
    notifyListeners();
  }

  // -- Copy ---------------------------------------------------------------------------------------------------------
  Future<void> handleCopy() async {
    final textToCopy = _hasEvaluated ? _lastAnswer : _expression;
    try {
      await _clipboard(textToCopy);
    } catch (_) {
      // navigator.clipboard.writeText failing does not stop the check mark either
    }
    _copied = true;
    playSound(ClickType.toggle);
    notifyListeners();
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      _copied = false;
      notifyListeners();
    });
  }

  // -- History tape stepping (Arrow Up / Down) ----------------------------------------------------------------------
  void handleHistoryStep(int direction) {
    if (_history.isEmpty) return;
    final nextIdx = _historyIndex + direction;
    if (nextIdx >= 0 && nextIdx < _history.length) {
      _historyIndex = nextIdx;
      _expression = _history[nextIdx].expression;
      _lastQuestion = '';
      _lastAnswer = _history[nextIdx].result;
      _hasEvaluated = false;
      playSound(ClickType.toggle);
      notifyListeners();
    } else if (nextIdx < 0) {
      _historyIndex = -1;
      _expression = '0';
      _lastQuestion = '';
      _lastAnswer = '';
      _hasEvaluated = false;
      notifyListeners();
    }
  }

  // -- Drawer and tabs -----------------------------------------------------------------------------------------------
  void toggleScientific() {
    playSound(ClickType.toggle);
    _isScientific = !_isScientific;
    notifyListeners();
  }

  void hideScientific() {
    playSound(ClickType.toggle);
    _isScientific = false;
    notifyListeners();
  }

  void selectTab(AdvancedTab tab) {
    playSound(ClickType.toggle);
    _advancedTab = tab;
    notifyListeners();
  }

  /// The y / y= key of the Calculus tab.
  void handleYKey() {
    if (_expression == '0' || _hasEvaluated) {
      handleInsertTemplate('y=');
    } else {
      handleInsertTemplate('y(');
    }
  }

  /// Flashes the = key for 160 ms (hardware Enter / =).
  void flashEquals() {
    _isEqualsPressed = true;
    notifyListeners();
    _equalsTimer?.cancel();
    _equalsTimer = Timer(const Duration(milliseconds: 160), () {
      _isEqualsPressed = false;
      notifyListeners();
    });
  }

  // -- Paste --------------------------------------------------------------------------------------------------------
  /// The `paste` listener: plain-looking maths replaces the expression; anything else is ignored (returns false).
  bool handlePaste(String? pastedText) {
    if (pastedText == null || pastedText.isEmpty) return false;
    final cleaned = pastedText.trim().replaceAll(RegExp(r'\s+'), '');
    if (!_rePasteAllowed.hasMatch(cleaned)) return false;
    final mapped = cleaned.replaceAll('*', '×').replaceAll('/', '÷').replaceAll('-', '−');
    _expression = mapped;
    _hasEvaluated = false;
    playSound(ClickType.num);
    notifyListeners();
    return true;
  }

  // -- Physical keyboard ---------------------------------------------------------------------------------------------
  /// The `keydown` listener. [key] follows `KeyboardEvent.key` ('1', '+', 'Enter', 'Backspace', 'Escape', 'Delete',
  /// 'ArrowUp', 'ArrowDown', letters in their typed case); [numpadMultiply] / [numpadDivide] follow `e.code`.
  /// Returns true when the key was used.
  bool handleKeyDown(
    String key, {
    bool ctrl = false,
    bool meta = false,
    bool numpadMultiply = false,
    bool numpadDivide = false,
  }) {
    // Ctrl / Cmd combinations
    if (ctrl || meta) {
      if (key == 'c' || key == 'C') {
        handleCopy();
        return true;
      }
      if (key == 'z' || key == 'Z') {
        handleBackspace();
        return true;
      }
      return false;
    }

    if (key.length == 1 && key.compareTo('0') >= 0 && key.compareTo('9') <= 0) {
      handleInput(key);
      return true;
    }

    if (key == '.' || key == ',') {
      if (key == ',' && _expression.contains('(')) {
        handleInput(',');
      } else {
        handleInput('.');
      }
      return true;
    }

    if (key == '+') {
      handleInput('+');
      return true;
    }
    if (key == '-') {
      handleInput('−');
      return true;
    }
    if (key == '*' || numpadMultiply) {
      handleInput('×');
      return true;
    }
    if (key == '/' || numpadDivide) {
      handleInput('÷');
      return true;
    }
    if (key == '%') {
      handleInput('%');
      return true;
    }
    if (key == '^') {
      handleInput('^');
      return true;
    }
    if (key == '!') {
      handleInput('!');
      return true;
    }
    if (key == '(') {
      handleInput('(');
      return true;
    }
    if (key == ')') {
      handleInput(')');
      return true;
    }

    // [ and ] switch the advanced tab
    if (key == '[' || key == ']') {
      final curIdx = AdvancedTab.values.indexOf(_advancedTab);
      final n = AdvancedTab.values.length;
      final target = key == '['
          ? AdvancedTab.values[curIdx > 0 ? curIdx - 1 : n - 1]
          : AdvancedTab.values[curIdx < n - 1 ? curIdx + 1 : 0];
      _advancedTab = target;
      playSound(ClickType.toggle);
      notifyListeners();
      return true;
    }

    if (key == 'Enter' || key == '=') {
      flashEquals();
      handleEvaluate();
      return true;
    }
    if (key == 'Backspace') {
      handleBackspace();
      return true;
    }
    if (key == 'Escape' || key == 'Delete') {
      handleClear();
      return true;
    }
    if (key == 'ArrowUp') {
      handleHistoryStep(1);
      return true;
    }
    if (key == 'ArrowDown') {
      handleHistoryStep(-1);
      return true;
    }

    // Mathematical letter shortcuts
    final lower = key.toLowerCase();
    if (lower == 'x') {
      final last = _lastChar(_expression);
      if (_operatorChars.contains(last) || _expression == '0') {
        handleInput('x');
      } else {
        handleInput('×');
      }
      return true;
    }
    if (lower == 'y') {
      handleInput('y');
      return true;
    }
    if (lower == 's') {
      handleFunction('sin');
      return true;
    }
    if (lower == 'c') {
      handleFunction('cos');
      return true;
    }
    if (lower == 't') {
      handleFunction('tan');
      return true;
    }
    if (lower == 'l') {
      handleFunction('ln');
      return true;
    }
    if (lower == 'p') {
      handleInput('PI');
      return true;
    }
    if (lower == 'e' && !RegExp(r'[0-9]').hasMatch(_lastChar(_expression))) {
      handleInput('E');
      return true;
    }
    if (lower == 'r' || lower == 'q') {
      handleFunction('sqrt');
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _equalsTimer?.cancel();
    super.dispose();
  }
}
