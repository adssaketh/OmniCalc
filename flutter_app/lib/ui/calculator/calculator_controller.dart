import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../editor/expr_doc.dart';
import '../../editor/linear.dart';
import '../../editor/nodes.dart';
import '../../editor/rich_layout.dart' show CaretHit;
import '../../engine/calc_error.dart';
import '../../engine/chemistry/calc_functions.dart';
import '../../engine/evaluator.dart';
import '../../engine/types.dart';
import '../../services/feedback_service.dart';
import '../../state/history_store.dart';

/// `AdvancedTab` of CalculatorScreen.tsx.
enum AdvancedTab { calculus, trig, powers, prob, constants, chemistry, es }

/// `ADVANCED_TABS` (id, label, badge).
const List<({AdvancedTab id, String label, String badge})> advancedTabDefs = [
  (id: AdvancedTab.calculus, label: 'Calculus', badge: '∫'),
  (id: AdvancedTab.trig, label: 'Trig & Hyp', badge: 'sin'),
  (id: AdvancedTab.powers, label: 'Powers', badge: 'xʸ'),
  (id: AdvancedTab.prob, label: 'Probability', badge: 'nCr'),
  (id: AdvancedTab.constants, label: 'Constants', badge: 'π'),
  // Phase 6: appended last so the order of the existing tabs does not change.
  (id: AdvancedTab.chemistry, label: 'Chemistry', badge: 'mol'),
  // Phase 8a: the natural-display keys (fraction, roots, SHIFT / ALPHA, arrows), again appended last.
  (id: AdvancedTab.es, label: 'ES', badge: 'a/b'),
];

/// Memory ribbon actions (`handleMemory`).
enum MemoryAction { mc, mr, mPlus, mMinus, ms }

/// Receives a finished calculation (`onAddHistory`).
typedef AddHistory = void Function({required String expression, required String result, required String mode});

/// `onAddHistory` plus the rich node tree of the expression (null when it has no superscripts or subscripts).
typedef AddHistoryRich = void Function({
  required String expression,
  required String result,
  required String mode,
  List<Object>? rich,
});

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
    this.onAddHistoryRich,
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

  /// When set it is used instead of [onAddHistory] and also receives the rich tree.
  AddHistoryRich? onAddHistoryRich;
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
  /// The expression as a node tree with a caret. [_expression] is its engine string: reading it serializes the tree
  /// (cached), assigning it parses the text back (lossless, see editor/linear.dart), so every handler below that works
  /// on the text keeps working unchanged.
  ExprDoc _doc = ExprDoc.plain('0');
  String get _expression => _doc.linear;
  set _expression(String v) => _doc = ExprDoc.fromLinear(v);

  void _clearModifiers() {
    _shift = false;
    _alpha = false;
    _insArmed = false;
    _lastWasPower = false;
  }

  /// Results and messages are shown exactly as they are: no `^` or `_` in them is read as a superscript.
  void _setPlain(String v) => _doc = ExprDoc.plain(v);

  /// What a handler that appends text to the old string decided: when the caret is at the end of the tree only the
  /// new tail is added to it (so a group the user has just left stays closed), otherwise the text is read afresh.
  void _set(String prev, String next) {
    if (_doc.atRootEnd && next.length >= prev.length && next.startsWith(prev)) {
      _doc.insertLinear(next.substring(prev.length));
    } else {
      _expression = next;
    }
  }

  /// Typing happens inside the tree (not at the end of the text): the caret is in a group or was moved.
  bool get _treeMode => !_hasEvaluated && !_doc.atRootEnd;

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
  // Phase 8a: the SHIFT / ALPHA / INS prefixes of the ES keys and the Syntax ERROR line
  bool _shift = false;
  bool _alpha = false;
  bool _insArmed = false;
  bool _lastWasPower = false;
  String? _syntaxError;
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
  bool get shiftOn => _shift;
  bool get alphaOn => _alpha;
  bool get insArmed => _insArmed;

  /// "Syntax ERROR" while an unfilled placeholder is blocking the calculation (the caret stands on it), else null.
  String? get syntaxError => _syntaxError;

  /// The status-bar annunciators that are on, in the order the display lists them (Part 9, section 9.2). The angle unit
  /// has its own badge, so D / R / G are not repeated here; the ones for modes that do not exist yet (STAT, CMPLX, MAT,
  /// VCT, FIX, SCI, STO, RCL, Disp) join in the phases that add those modes.
  List<String> get annunciators => [
        if (_shift) 'S',
        if (_alpha) 'A',
        if (_memory != 0) 'M',
        if (_insArmed) 'INS',
        if (!_hasEvaluated && _doc.hasStructure) 'Math',
      ];
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
    _clearModifiers();
    _syntaxError = null;
    if (_treeMode) {
      _treeInput(token);
      return;
    }
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

    _set(prev, prev + token);
    notifyListeners();
  }

  // -- Typing inside the tree (caret in a superscript / subscript, or moved away from the end) ------------------------
  /// Inserts text at the caret. Opening another group deeper than [kMaxNesting] levels is refused.
  void _treeInsert(String text) {
    if (text.contains('^') && _doc.scriptDepth >= kMaxNesting) {
      notifyListeners();
      return;
    }
    _doc.insertLinear(text);
    notifyListeners();
  }

  void _treeInput(String token) {
    if (token == '.') {
      final lastSegment = _doc.textBeforeCaret.split(_reSegmentSplit).last;
      if (lastSegment.contains('.')) {
        notifyListeners();
        return;
      }
    }
    _treeInsert(token);
  }

  /// `×` is added before a function or template unless the caret is at the start of its list or after an operator.
  void _treeCall(String text) {
    final pc = _doc.prevChar;
    final glue = pc.isEmpty || _operatorChars.contains(pc) ? '' : '×';
    _treeInsert('$glue$text');
  }

  void _treeParentheses() {
    final pc = _doc.prevChar;
    // inside a fraction, root... only the parentheses typed in that slot count; elsewhere the whole line, as before
    final prev = _doc.structDepth > 0 ? serializeNodes(_doc.current.sublist(0, _doc.offset)) : _expression;
    if (_count(prev, '(') > _count(prev, ')') && pc.isNotEmpty && !_operatorChars.contains(pc)) {
      _treeInsert(')');
    } else if (pc.isEmpty || const ['+', '−', '×', '÷', '(', '^', '%', ',', ' '].contains(pc)) {
      _treeInsert('(');
    } else {
      _treeInsert('×(');
    }
  }

  /// Insert a function such as `sin(`.
  void handleFunction(String fnName) {
    playSound(ClickType.op);
    _clearModifiers();
    _syntaxError = null;
    if (_treeMode) {
      _treeCall('$fnName(');
      return;
    }
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
      _set(prev, '$prev$fnName(');
    } else {
      _set(prev, '$prev×$fnName(');
    }
    notifyListeners();
  }

  /// Insert a template such as `diff(`, `integrate(`, `sum(`.
  void handleInsertTemplate(String template) {
    playSound(ClickType.op);
    _clearModifiers();
    _syntaxError = null;
    if (_treeMode) {
      _treeCall(template);
      return;
    }
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
      _set(prev, '$prev$template');
    } else {
      _set(prev, '$prev×$template');
    }
    notifyListeners();
  }

  void handleParentheses() {
    playSound(ClickType.op);
    _clearModifiers();
    _syntaxError = null;
    if (_treeMode) {
      _treeParentheses();
      return;
    }
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
      _set(prev, '$prev)');
    } else if (const ['+', '−', '×', '÷', '(', '^', '%', ',', ' '].contains(last) || prev == '0') {
      if (prev == '0') {
        _expression = '(';
      } else {
        _set(prev, '$prev(');
      }
    } else {
      _set(prev, '$prev×(');
    }
    notifyListeners();
  }

  void handleClear() {
    playSound(ClickType.clear);
    _clearModifiers();
    _syntaxError = null;
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
    _clearModifiers();
    _syntaxError = null;
    if (_hasEvaluated) {
      _hasEvaluated = false;
      _expression = '0';
      notifyListeners();
      return;
    }
    // On the tree: one character or token before the caret; an empty group goes away; a group with content is entered
    // first. For text without groups this removes exactly what the old string handler removed.
    _doc.backspace(_multiCharTokens);
    if (_doc.root.isEmpty) _expression = '0';
    notifyListeners();
  }

  // -- Rich editor: caret and groups --------------------------------------------------------------------------------
  /// The expression tree the display draws.
  ExprDoc get doc => _doc;

  /// The caret is inside a superscript or subscript (the exit chip shows).
  bool get caretInGroup => !_hasEvaluated && _doc.inGroup;

  /// The display draws the caret while the user is editing the structure: inside a group, away from the end, or when
  /// the expression has groups. Plain arithmetic shows no caret, as before.
  bool get caretVisible => !_hasEvaluated && (_doc.inGroup || !_doc.atRootEnd || _doc.hasGroups);

  /// Subscript key (hardware `_`): a lowered group at the caret, caret inside. After a result it continues from the
  /// result, like `^` does.
  void handleSub() {
    playSound(ClickType.num);
    if (_hasEvaluated) {
      _hasEvaluated = false;
      _lastQuestion = '';
      _lastAnswer = '';
    }
    _doc.insertGroup(sup: false);
    notifyListeners();
  }

  /// Arrow keys and taps. Not while a result is shown (it is a result, not something being edited).
  bool moveCaretLeft() {
    if (_hasEvaluated || !_doc.moveLeft()) return false;
    _clearModifiers();
    _syntaxError = null;
    notifyListeners();
    return true;
  }

  bool moveCaretRight() {
    if (_hasEvaluated || !_doc.moveRight()) return false;
    _clearModifiers();
    _syntaxError = null;
    notifyListeners();
    return true;
  }

  /// ▼ / ▲ of the replay pad: numerator <-> denominator of the fraction around the caret.
  bool moveCaretDown() {
    if (_hasEvaluated || !_doc.moveDown()) return false;
    _clearModifiers();
    _syntaxError = null;
    notifyListeners();
    return true;
  }

  bool moveCaretUp() {
    if (_hasEvaluated || !_doc.moveUp()) return false;
    _clearModifiers();
    _syntaxError = null;
    notifyListeners();
    return true;
  }

  /// The exit key: leave the superscript / subscript and carry on in the line it belongs to.
  bool exitGroup() {
    if (_hasEvaluated || !_doc.exitGroup()) return false;
    playSound(ClickType.op);
    notifyListeners();
    return true;
  }

  /// A tap on the display.
  void placeCaret(CaretHit hit) {
    if (_hasEvaluated) return;
    if (_doc.setCaret(hit.path, hit.offset)) notifyListeners();
  }

  // -- ES keys (Phase 8a): SHIFT / ALPHA / INS and the natural-display structures ---------------------------------------
  void toggleShift() {
    playSound(ClickType.toggle);
    final on = !_shift;
    _clearModifiers();
    _shift = on;
    notifyListeners();
  }

  void toggleAlpha() {
    playSound(ClickType.toggle);
    final on = !_alpha;
    _clearModifiers();
    _alpha = on;
    notifyListeners();
  }

  /// INS: the next function key takes the value or expression to the right of the caret as its argument.
  void toggleIns() {
    playSound(ClickType.toggle);
    final on = !_insArmed;
    _clearModifiers();
    _insArmed = on;
    notifyListeners();
  }

  /// Gets the line ready for a structure: a result on screen or the initial `0` is replaced by an empty line.
  void _prepareStructInsert() {
    if (_hasEvaluated) {
      _hasEvaluated = false;
      _lastQuestion = '';
      _lastAnswer = '';
      _doc = ExprDoc.fromNodes(const []);
    } else if (_doc.path.isEmpty && _doc.root.length == 1 && _doc.root.first == const CharNode('0')) {
      _doc = ExprDoc.fromNodes(const []);
    }
  }

  void _insertStruct(StructNode Function() make, {int focus = 0, int? wrapSlot}) {
    playSound(ClickType.op);
    final wrap = _insArmed && wrapSlot != null;
    _clearModifiers();
    _syntaxError = null;
    _prepareStructInsert();
    final node = make();
    if (wrap) {
      _doc.insertStructWrapping(node, argSlot: wrapSlot);
    } else {
      _doc.insertStruct(node, focus: focus);
    }
    notifyListeners();
  }

  /// The fraction key: an empty stacked fraction, caret in the numerator.
  void esFraction() => _insertStruct(FracNode.new);

  /// SHIFT + fraction: mixed fraction (whole part, numerator, denominator).
  void esMixedFraction() => _insertStruct(MixedFracNode.new);

  /// √ with its overbar. With INS armed it takes what is to the right of the caret.
  void esSqrt() => _insertStruct(SqrtNode.new, wrapSlot: 0);

  /// ∛ : a root whose index is already 3.
  void esCbrt() => _insertStruct(
        () => RootNode([SlotNode([const CharNode('3')]), SlotNode()]),
        focus: 1,
        wrapSlot: 1,
      );

  /// ⁿ√ : index first, then the radicand.
  void esRoot() => _insertStruct(RootNode.new, wrapSlot: 1);

  /// |x| (Abs).
  void esAbs() => _insertStruct(AbsNode.new, wrapSlot: 0);

  /// log with a lowered base: base first, then the argument.
  void esLogBase() => _insertStruct(LogBaseNode.new, wrapSlot: 1);

  /// `x²`, `x³`, `x⁻¹` of the ES tab: a raised group with the caret INSIDE it, so the next key stays in the exponent
  /// until the right arrow leaves it (video frame: `X` then `x²`). Pressed twice in a row the second press is ignored,
  /// as the manual says for these three.
  void esPower(String chars) {
    playSound(ClickType.num);
    final repeated = _lastWasPower;
    _clearModifiers();
    _syntaxError = null;
    if (repeated) {
      _lastWasPower = true;
      notifyListeners();
      return;
    }
    if (_hasEvaluated) {
      _hasEvaluated = false;
      _lastQuestion = '';
      _lastAnswer = '';
    }
    if (_doc.scriptDepth < kMaxNesting) {
      _doc.insertNode(SupNode([for (final u in chars.codeUnits) CharNode(String.fromCharCode(u))]));
      _doc.moveLeft(); // into the group, at its end
      _lastWasPower = true;
    }
    notifyListeners();
  }

  /// A key whose function arrives in a later phase (CALC and SOLVE: 8c): it only lets go of SHIFT / ALPHA / INS.
  void esNotYet() {
    _clearModifiers();
    notifyListeners();
  }

  /// ALPHA + CALC types `=` (an equation such as `(X²−6)/(X+3)=10`; SOLVE reads it in Phase 8c).
  void esEquals() => handleInput('=');

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
    _clearModifiers();
    _syntaxError = null;
    // an unfilled placeholder (an empty numerator, radicand, ...) is a Syntax ERROR and the caret goes to it
    final placeholder = _hasEvaluated ? null : _doc.firstPlaceholderPath;
    if (placeholder != null) {
      _doc.setCaret(placeholder, 0);
      _syntaxError = 'Syntax ERROR';
      notifyListeners();
      return;
    }
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

      // atomicsym(26) is the one chemistry function whose answer is text (Phase 6); it only works as the whole expression
      final formatted = ChemCalcFunctions.textResult(exprToEval) ??
          MathEvaluator.formatResult(MathEvaluator.evaluate(exprToEval, _angleMode), _decimalPrecision);

      _lastQuestion = shown;
      _lastAnswer = formatted;

      final mode = _isScientific ? 'scientific' : 'standard';
      // the rich tree is kept with the entry only when it is exactly what was calculated
      final rich = (shown == _expression && _doc.hasGroups) ? _doc.toJson() : null;
      if (onAddHistoryRich != null) {
        onAddHistoryRich!.call(expression: shown, result: formatted, mode: mode, rich: rich);
      } else {
        onAddHistory?.call(expression: shown, result: formatted, mode: mode);
      }

      _setPlain(formatted);
      _hasEvaluated = true;
    } catch (err) {
      final msg = err is CalcError ? err.message : 'Error';
      _lastQuestion = _expression;
      _lastAnswer = msg;
      _setPlain(msg);
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
          _setPlain(MathEvaluator.formatResult(_memory, _decimalPrecision));
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

  /// The tree of a history entry: the saved rich tree when it still matches the entry's text, otherwise the text read
  /// afresh (entries from before the editor have no tree).
  ExprDoc _docOf(HistoryItem item) {
    final rich = item.rich == null ? null : ExprDoc.fromJson(item.rich);
    if (rich != null && rich.linear == item.expression) return rich;
    return ExprDoc.fromLinear(item.expression);
  }

  // -- History tape stepping (Arrow Up / Down) ----------------------------------------------------------------------
  void handleHistoryStep(int direction) {
    if (_history.isEmpty) return;
    final nextIdx = _historyIndex + direction;
    if (nextIdx >= 0 && nextIdx < _history.length) {
      _historyIndex = nextIdx;
      _doc = _docOf(_history[nextIdx]);
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
    // x², x⁻¹, H₂O: Unicode superscript / subscript digits become `^` / `_` groups before the usual check
    final cleaned = normalizeUnicodeScripts(pastedText.trim().replaceAll(RegExp(r'\s+'), ''));
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
    if (key == 'ArrowLeft') return moveCaretLeft();
    if (key == 'ArrowRight') return moveCaretRight();
    if (key == '_') {
      handleSub();
      return true;
    }
    if (key == 'ArrowUp') {
      if (moveCaretUp()) return true; // inside a fraction: denominator -> numerator
      handleHistoryStep(1);
      return true;
    }
    if (key == 'ArrowDown') {
      if (moveCaretDown()) return true;
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
