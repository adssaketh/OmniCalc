import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../editor/expr_doc.dart';
import '../../editor/linear.dart';
import '../../editor/nodes.dart';
import '../../editor/result_doc.dart';
import '../../editor/rich_layout.dart' show CaretHit;
import '../../engine/calc_error.dart';
import '../../engine/casio/base_n.dart';
import '../../engine/casio/complex.dart';
import '../../engine/casio/config.dart';
import '../../engine/casio/cval.dart' show CVal, CasioError, CasioErrorKind;
import '../../engine/casio/engine.dart';
import '../../engine/casio/recurring_input.dart';
import '../../engine/casio/format.dart';
import '../../engine/casio/matrix.dart';
import '../../engine/casio/stat.dart';
import '../../engine/casio/verif.dart';
import '../../engine/casio/solve_calc.dart';
import '../../engine/chemistry/calc_functions.dart';
import '../../engine/evaluator.dart';
import '../../engine/types.dart';
import '../../services/feedback_service.dart';
import '../../state/history_store.dart';

/// Runs one Casio calculation in a background isolate (∫, d/dx, Σ, ∏ can take seconds). Message:
/// [SendPort, expression, CasioConfig, CasioMemory, continuesAns, AngleMode index]. Reply:
/// ['ok', CasioOutcome, CasioMemory] or ['err', kindIndex (-1 = other), message].
void _casioWorker(List<Object?> msg) {
  final port = msg[0]! as SendPort;
  final engine = CasioEngine(config: msg[2]! as CasioConfig, memory: msg[3]! as CasioMemory);
  try {
    final out = engine.evaluate(msg[1]! as String,
        continuesAns: msg[4]! as bool, legacyAngle: AngleMode.values[msg[5]! as int]);
    port.send(<Object?>['ok', out, engine.memory]);
  } on CasioError catch (e) {
    port.send(<Object?>['err', e.kind.index, e.message]);
  } catch (e) {
    port.send(<Object?>['err', -1, CasioEngine.messageOf(e)]);
  }
}

enum _SessionStage { none, prompt, continueScreen, result, error }

/// `AdvancedTab` of CalculatorScreen.tsx.
enum AdvancedTab { calculus, trig, powers, prob, constants, chemistry, es, modes, data }

/// The calculation mode of the MODE menu (manual p.9). EQN is a separate screen (a dialog), so it is not listed here.
enum CasioMode { comp, cmplx, baseN, stat, matrix, vector, table, verif }

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
  // Phase 7d: MODE menu, CMPLX keys, BASE-N keys, again appended last.
  (id: AdvancedTab.modes, label: 'Modes', badge: 'MODE'),
  // Phase 7d-2: STAT, MATRIX, VECTOR and TABLE keys (they depend on the current mode), again appended last.
  (id: AdvancedTab.data, label: 'Data', badge: 'STAT'),
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
    CasioEngine? engine,
    CasioMode initialMode = CasioMode.comp,
    BaseMode initialBaseMode = BaseMode.dec,
    StatType initialStatType = StatType.oneVar,
    this.onPersist,
  })  : engine = engine ?? CasioEngine(),
        _mode = initialMode,
        _baseMode = initialBaseMode,
        _statType = initialStatType,
        _clipboard = clipboard ?? _systemClipboard,
        _angleMode = angleMode,
        _decimalPrecision = decimalPrecision,
        _soundEnabled = soundEnabled,
        _hapticEnabled = hapticEnabled,
        _equation = MathEvaluator.getYDefinition();

  final FeedbackService feedback;

  /// The Casio calculation engine (shared with the rest of the app so that Ans and the variables persist).
  final CasioEngine engine;
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
    CasioConfig? casio,
  }) {
    final cfg = casio ?? engine.config.copyWith(angle: angleMode == AngleMode.rad ? CasioAngle.rad : CasioAngle.deg, legacyPrecision: decimalPrecision);
    final changed = cfg != engine.config ||
        angleMode != _angleMode ||
        decimalPrecision != _decimalPrecision ||
        !identical(history, _history);
    _angleMode = angleMode;
    _decimalPrecision = decimalPrecision;
    _soundEnabled = soundEnabled;
    _hapticEnabled = hapticEnabled;
    _history = history;
    if (cfg.displayFormat != engine.config.displayFormat) _clearReplay();
    engine.config = cfg;
    if (changed) {
      _livePreviewKey = null;
      _forms = const <CasioShown>[];
    }
  }

  // -- State ------------------------------------------------------------------------------------------------------
  /// The expression as a node tree with a caret. [_expression] is its engine string: reading it serializes the tree
  /// (cached), assigning it parses the text back (lossless, see editor/linear.dart), so every handler below that works
  /// on the text keeps working unchanged.
  ExprDoc _doc = ExprDoc.plain('0');
  String get _expression => _doc.linear;
  set _expression(String v) => _doc = ExprDoc.fromLinear(v);

  /// Row A41: after the recurring key every digit typed is marked as part of the period.
  bool _recurMode = false;

  void _clearModifiers() {
    _recurMode = false;
    _shift = false;
    _alpha = false;
    _insArmed = false;
    _sto = false;
    _rcl = false;
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
  /// The OmniCalc memory keys (MC MR MS M+ M−) and the Casio independent memory M are one store (manual p.35: M is the
  /// variable that M+ and M− change), so the value also survives a restart with the other variables.
  double get _memory => engine.memory.vars['M']!.v;
  set _memory(double v) => engine.memory.vars['M'] = v == 0 ? CVal.zero : CVal.dec(v);
  bool _isScientific = false;
  AdvancedTab _advancedTab = AdvancedTab.calculus;

  // -- MODE (Phase 7d) ------------------------------------------------------------------------------------------------
  CasioMode _mode;
  BaseMode _baseMode;
  CasioComplexEngine? _cx;
  final CasioBaseN _bn = CasioBaseN();
  BaseNOutcome? _bnResult;

  /// Called after a result, a mode change or a clear, so that Ans, the variables and the mode survive a restart (Part 9, R).
  VoidCallback? onPersist;

  void _persist() => onPersist?.call();

  /// Set by the screen: opens the MODE menu.
  VoidCallback? onOpenModeMenu;

  CasioMode get mode => _mode;
  BaseMode get baseMode => _baseMode;
  CasioComplexEngine get complexEngine => _cx ??= CasioComplexEngine(engine.memory);

  /// MODE ▸ COMP / CMPLX / BASE-N. Ans and the variables stay; the entry line starts over (manual p.9, p.35).
  void setMode(CasioMode m) {
    playSound(ClickType.toggle);
    _clearModifiers();
    _syntaxError = null;
    if (_busy) return;
    if (_mode == CasioMode.stat && m != CasioMode.stat) _statData = null;
    _mode = m;
    _clearReplay();
    _bnResult = null;
    _setPlain('0');
    _forms = const <CasioShown>[];
    _formIndex = 0;
    _answerDisplay = '';
    _lastQuestion = '';
    _lastAnswer = '';
    _resultError = false;
    _hasEvaluated = false;
    _continuesAns = false;
    _persist();
    notifyListeners();
  }

  /// DEC / HEX / BIN / OCT of BASE-N: later entries are read in that base, and a result on screen is shown in it (manual p.66-68).
  void setBaseMode(BaseMode b) {
    playSound(ClickType.toggle);
    if (_mode != CasioMode.baseN) return;
    _baseMode = b;
    final r = _bnResult;
    if (_hasEvaluated && !_resultError && r != null) {
      try {
        final text = r.textIn(b);
        _setPlain(text);
        _answerDisplay = '';
        _lastAnswer = text;
      } catch (e) {
        _commitError(e);
      }
    }
    _persist();
    notifyListeners();
  }

  void openModeMenu() {
    playSound(ClickType.toggle);
    onOpenModeMenu?.call();
  }

  // -- STAT / MATRIX / VECTOR / TABLE (Phase 7d-2) --------------------------------------------------------------------
  StatType _statType;
  StatData? _statData;
  final MatVecStore matVec = MatVecStore();
  CasioMatVec? _mv;
  CMatrix? _matResult;
  CVector? _vecResult;
  String _tableF = '';
  String _tableG = '';

  /// Set by the screen: open the editors and the result sheet.
  VoidCallback? onOpenStatEditor;
  VoidCallback? onOpenStatTypeMenu;
  VoidCallback? onOpenMatrixEditor;
  VoidCallback? onOpenVectorEditor;
  VoidCallback? onOpenTable;
  VoidCallback? onShowMatVecResult;

  CasioMatVec get _matvec => _mv ??= CasioMatVec(matVec, engine.memory);
  StatType get statType => _statType;
  CMatrix? get matrixResult => _matResult;
  CVector? get vectorResult => _vecResult;
  String get tableF => _tableF;
  String get tableG => _tableG;

  /// What the MODE key shows under its label.
  String get modeName => switch (_mode) {
        CasioMode.comp => 'COMP',
        CasioMode.cmplx => 'CMPLX',
        CasioMode.baseN => 'BASE-N',
        CasioMode.stat => 'STAT',
        CasioMode.matrix => 'MATRIX',
        CasioMode.vector => 'VECTOR',
        CasioMode.table => 'TABLE',
        CasioMode.verif => 'VERIF',
      };

  /// The Statistics Editor data. A change of the STAT format (FREQ column) starts it over (manual p.59).
  StatData get statData {
    var d = _statData;
    if (d == null || d.type != _statType || d.freqColumn != engine.config.statFreq) {
      d = StatData(_statType, engine.config.statFreq);
      _statData = d;
    }
    return d;
  }

  /// MODE ▸ STAT ▸ a type: enters STAT mode and opens the Statistics Editor.
  void enterStat(StatType t) {
    _statData = null;
    _statType = t;
    setMode(CasioMode.stat);
    onOpenStatEditor?.call();
  }

  /// STAT/DIST ▸ Type: data stays when the change is between paired types, and is cleared between 1-VAR and paired (manual p.59).
  void changeStatType(StatType t) {
    if (t.paired != _statType.paired) {
      _statData = null;
    } else if (_statData != null) {
      _statData = statData.withType(t);
    }
    _statType = t;
    notifyListeners();
  }

  void enterMatrix() {
    setMode(CasioMode.matrix);
    onOpenMatrixEditor?.call();
  }

  void enterVector() {
    setMode(CasioMode.vector);
    onOpenVectorEditor?.call();
  }

  void enterTable() {
    setMode(CasioMode.table);
    onOpenTable?.call();
  }

  /// MODE ▸ VERIF (manual p.85): the calculation line takes `=`, `≠`, `>`, `<`, `≥`, `≤`; `=` answers TRUE or FALSE.
  void enterVerif() => setMode(CasioMode.verif);

  // -- INEQ, DIST, CLR and power (Phase 7e) -----------------------------------------------------------------------------
  /// Set by the screen: the INEQ and DIST dialogs, the CLR menu.
  VoidCallback? onOpenIneq;
  VoidCallback? onOpenDist;
  VoidCallback? onOpenClr;

  /// Set by the screen: puts the SETUP choices back to the defaults (CLR ▸ Setup).
  VoidCallback? onResetSetup;

  void openClrMenu() {
    playSound(ClickType.toggle);
    onOpenClr?.call();
  }

  /// CLR ▸ Setup (manual p.12): the SETUP choices and the mode go back to the defaults; memory stays.
  void clearSetup() {
    onResetSetup?.call();
    _clearReplay();
    _baseMode = BaseMode.dec;
    _statType = StatType.oneVar;
    _statData = null;
    setMode(CasioMode.comp);
  }

  /// CLR ▸ Memory: Ans, PreAns, the variables A–F, X, Y and the independent memory M.
  void clearMemory() {
    engine.memory.clearVariables();
    _memory = 0;
    _persist();
    notifyListeners();
  }

  /// CLR ▸ All: setup and memory.
  void clearAll() {
    engine.memory.clearVariables();
    _memory = 0;
    clearSetup();
  }

  bool _off = false;

  /// The unit is switched off (SHIFT AC, or ten idle minutes): the screen is dark, memory is kept (manual p.7).
  bool get isOff => _off;

  void powerOff() {
    if (_off) return;
    playSound(ClickType.toggle);
    _clearModifiers();
    _off = true;
    _persist();
    notifyListeners();
  }

  /// ON wakes the unit. The display starts in the same mode with an empty line.
  void powerOn() {
    if (!_off) return;
    _off = false;
    _clearReplay();
    notifyListeners();
  }

  /// The table function entered on the calculation line, kept for the Table sheet.
  void setTableFunctions(String f, String g) {
    _tableF = f;
    _tableG = g;
  }

  void openStatTypeMenu() {
    playSound(ClickType.toggle);
    onOpenStatTypeMenu?.call();
  }

  void openStatEditor() {
    playSound(ClickType.toggle);
    if (_mode == CasioMode.stat) onOpenStatEditor?.call();
  }

  void openMatVecEditor() {
    playSound(ClickType.toggle);
    if (_mode == CasioMode.matrix) onOpenMatrixEditor?.call();
    if (_mode == CasioMode.vector) onOpenVectorEditor?.call();
  }

  void openTableSheet() {
    playSound(ClickType.toggle);
    if (_mode == CasioMode.table) onOpenTable?.call();
  }

  /// Re-shows the last matrix / vector result (MatAns / VctAns screen).
  void showMatVecResult() {
    if (_mode == CasioMode.matrix && matVec.matAns != null || _mode == CasioMode.vector && matVec.vctAns != null) {
      _matResult = matVec.matAns;
      _vecResult = matVec.vctAns;
      onShowMatVecResult?.call();
    }
  }
  bool _copied = false;
  bool _hasEvaluated = false;

  /// The last `=` came from the Casio engine; its forms (S⇔D cycles through them) and whether it was an error.
  List<CasioShown> _forms = const <CasioShown>[];
  int _formIndex = 0;
  bool _resultError = false;
  bool _continuesAns = false;
  String? _resultRemainder;
  Map<String, String> _resultExtra = const <String, String>{};

  /// Linear Display lines of each form of a CMPLX result (`a` and `bi`, or `r` and `∠θ`), parallel to [_forms].
  List<List<String>> _formLines = const <List<String>>[];
  bool _resultFactorable = false;
  String _answerDisplay = '';
  bool _isEqualsPressed = false;
  // Phase 8a: the SHIFT / ALPHA / INS prefixes of the ES keys and the Syntax ERROR line
  bool _shift = false;
  bool _alpha = false;
  bool _sto = false;
  bool _rcl = false;
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
  bool get stoOn => _sto;
  bool get rclOn => _rcl;

  /// "Syntax ERROR" while an unfilled placeholder is blocking the calculation (the caret stands on it), else null.
  String? get syntaxError => _syntaxError;

  /// The status-bar annunciators that are on, in the order the display lists them (Part 9, section 9.2). The angle unit
  /// has its own badge, so D / R / G are not repeated here; the ones for modes that do not exist yet (STAT, CMPLX, MAT,
  /// VCT, FIX, SCI, STO, RCL, Disp) join in the phases that add those modes.
  List<String> get annunciators => [
        if (_mode == CasioMode.cmplx) 'CMPLX',
        if (_mode == CasioMode.baseN) ...['BASE', _baseMode.label],
        if (_mode == CasioMode.stat) 'STAT',
        if (_mode == CasioMode.matrix) 'MAT',
        if (_mode == CasioMode.vector) 'VCT',
        if (_shift) 'S',
        if (_alpha) 'A',
        if (_sto) 'STO',
        if (_rcl) 'RCL',
        if (_memory != 0) 'M',
        if (_insArmed) 'INS',
        if (replayAvailable) '▼▲',
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
  bool get isErrorResult =>
      _hasEvaluated && (_resultError || (_forms.isEmpty && !_reErrorResult.hasMatch(_expression.trim())));

  /// What the answer line shows after `=` (fractions as `7⌟6`, √ and π forms, DMS, recurring decimals, `3 R 2`).
  ExprDoc get resultDoc => _answerDisplay.isEmpty
      ? _doc
      : resultDocFor(_answerDisplay, stacked: engine.config.displayFormat == CasioDisplayFormat.mathO);

  /// `Pol` / `Rec` give two values: `r = 2, θ = 45` (manual p.44). With SETUP > Disp > Comma the separator is `;`.
  String _withExtra(String firstDisplay) {
    if (_resultExtra.isEmpty) return firstDisplay;
    final sep = engine.config.commaDecimal ? ';' : ',';
    final b = StringBuffer('${_resultExtra.containsKey('θ') ? 'r' : 'X'} = $firstDisplay');
    for (final e in _resultExtra.entries) {
      b.write('$sep ${e.key} = ${e.value}');
    }
    return b.toString();
  }

  /// The other forms of the last result exist (S⇔D has something to switch to).
  bool get canToggleForm => _hasEvaluated && _forms.length > 1;

  /// `Pol`/`Rec` second outputs, for example {'θ': '45'} (empty for other results).
  Map<String, String> get resultExtra => _resultExtra;

  /// Phase 8c (row H10): with Linear Display (LineIO) a CMPLX result is written as `a` and `bi` (or `r` and `∠θ`) on
  /// separate lines (manual p.56 note) and `Pol` / `Rec` as `r = 2` over `θ = 45` (manual p.44). Empty means one line.
  List<String> get resultLines {
    if (!_hasEvaluated || _resultError || engine.config.displayFormat != CasioDisplayFormat.lineIO) return const <String>[];
    if (_formLines.isNotEmpty) {
      final l = _formLines[_formIndex.clamp(0, _formLines.length - 1)];
      return l.length > 1 ? l : const <String>[];
    }
    if (_resultExtra.isNotEmpty) {
      return <String>[
        '${_resultExtra.containsKey('θ') ? 'r' : 'X'} = $_lastAnswer',
        for (final e in _resultExtra.entries) '${e.key} = ${e.value}',
      ];
    }
    return const <String>[];
  }

  /// The result is a positive integer of at most 10 digits that FACT may factor.
  bool get canFactor => _hasEvaluated && _resultFactorable;

  /// `playSound`: click sound and haptic tick, each only when enabled.
  void playSound([ClickType type = ClickType.num]) {
    if (_soundEnabled) feedback.playClick(type);
    if (_hapticEnabled) feedback.triggerHaptic();
  }

  // -- External expression (history tape, deep link) --------------------------------------------------------------
  /// The `useEffect` on `externalExpression` / `externalSeq`: loads text from outside; empty text is ignored.
  void loadExternal(String expression) {
    if (expression.isEmpty) return;
    _doc = ExprDoc.fromExample(expression);
    _lastQuestion = '';
    _lastAnswer = '';
    _hasEvaluated = false;
    notifyListeners();
  }

  // -- Handlers ---------------------------------------------------------------------------------------------------
  void handleInput(String token) {
    playSound(ClickType.num);
    var recur = _recurMode;
    if (recur && token.length == 1 && '0123456789'.contains(token)) {
      token = '$token${CasioRecurringInput.mark}';
    } else {
      recur = false;
    }
    _clearModifiers();
    _recurMode = recur;
    _syntaxError = null;
    if (_busy) return;
    // VERIF takes at most 99 bytes (manual p.85): further input is refused
    if (_mode == CasioMode.verif && !_hasEvaluated && !CasioInputBytes.fits(_expression + token)) {
      notifyListeners();
      return;
    }
    if (_sessionActive && _stage == _SessionStage.prompt && _sessionFresh) {
      // typing at a prompt replaces the value shown there
      _sessionFresh = false;
      _doc = ExprDoc.plain('0');
    }
    if (_sessionActive && (_stage != _SessionStage.prompt || token == '=')) {
      notifyListeners();
      return;
    }
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
        _continuesAns = true;
      } else {
        _continuesAns = false;
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
    if (_busy) {
      // AC interrupts a running calculation (manual: ∫, d/dx, Σ, ∏ can be interrupted with AC)
      _stopBackground();
      notifyListeners();
      return;
    }
    if (_sessionActive) {
      _exitSession();
      notifyListeners();
      return;
    }
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
    final onMark = _doc.textBeforeCaret.endsWith(CasioRecurringInput.mark);
    _doc.backspace(_multiCharTokens);
    if (onMark) _doc.backspace(_multiCharTokens); // a period digit and its overline go together
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

  /// ∫ with its limits: integrand, lower limit, upper limit (manual p.39).
  void esIntegral() => _insertStruct(IntegralNode.new);

  /// d/dx at a point: function, point (manual p.41).
  void esDeriv() => _insertStruct(DerivNode.new);

  /// Σ: term, first and last value of X (manual p.42).
  void esSigma() => _insertStruct(SigmaNode.new);

  /// ∏: factor, first and last value of X (manual p.43).
  void esProd() => _insertStruct(ProdNode.new);

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

  /// SHIFT `×10ˣ` (manual p.26): the recurring-decimal key. It types the decimal point when the number has none, and the
  /// digits typed next form the repeating period. Natural Display only (the unit refuses it in Linear Display).
  void esRecurring() {
    if (engine.config.displayFormat == CasioDisplayFormat.lineIO) {
      playSound(ClickType.num);
      _clearModifiers();
      notifyListeners();
      return;
    }
    final before = _hasEvaluated ? '' : _doc.textBeforeCaret;
    final number = RegExp(r'[0-9.]*$').firstMatch(before)?.group(0) ?? '';
    if (!number.contains('.')) {
      handleInput(number.isEmpty ? '0' : '.');
      if (number.isEmpty) handleInput('.');
    }
    _recurMode = true;
    notifyListeners();
  }

  /// `×10ˣ` (manual p.12): types `×10` and opens a raised group for the exponent, with the caret inside it.
  void esTimesTen() {
    handleInput('×');
    handleInput('1');
    handleInput('0');
    esPower('');
  }

  /// STO (manual p.35): the next variable key stores the value on the line (or Ans, with a result on screen) in it.
  void toggleSto() {
    playSound(ClickType.toggle);
    final on = !_sto;
    _clearModifiers();
    _sto = on;
    notifyListeners();
  }

  /// RCL: the next variable key puts that variable's value into the expression.
  void toggleRcl() {
    playSound(ClickType.toggle);
    final on = !_rcl;
    _clearModifiers();
    _rcl = on;
    notifyListeners();
  }

  /// A variable key (A B C D E F M X Y). Plain it types the variable; after STO it stores, after RCL it recalls.
  void variableKey(String name) {
    if (_sto) {
      _storeInto(name);
    } else if (_rcl) {
      _recallFrom(name);
    } else {
      handleInput(name);
    }
  }

  void _storeInto(String name) {
    playSound(ClickType.op);
    _clearModifiers();
    if (_busy || !kVariableNames.contains(name)) {
      notifyListeners();
      return;
    }
    if (_hasEvaluated || _expression == '0') {
      // a result is on screen (or the line is empty): store Ans at full precision and leave the display alone
      if (!_resultError) {
        engine.memory.vars[name] = engine.memory.ans;
        _persist();
      }
      notifyListeners();
      return;
    }
    handleInput('→');
    handleInput(name);
    handleEvaluate();
  }

  void _recallFrom(String name) {
    playSound(ClickType.num);
    _clearModifiers();
    if (_busy || !kVariableNames.contains(name)) {
      notifyListeners();
      return;
    }
    final text = CasioFormatter(engine.config).first(engine.memory.vars[name]!).expr;
    handleInput(text);
  }

  /// A key with no function yet: it only lets go of SHIFT / ALPHA / INS.
  void esNotYet() {
    _clearModifiers();
    notifyListeners();
  }

  /// ALPHA + CALC types `=` (an equation such as `(X²−6)/(X+3)=10`, read by SOLVE).
  void esEquals() => handleInput('=');


  // -- SOLVE and CALC sessions (Phase 7c) ---------------------------------------------------------------------------
  CasioSolver? _solver;
  CasioCalc? _calc;
  _SessionStage _stage = _SessionStage.none;
  List<String> _sessionVars = const <String>[];
  int _sessionIdx = 0;
  Map<String, CVal> _sessionVals = <String, CVal>{};
  bool _sessionFresh = false;
  ExprDoc? _savedDoc;
  String _sessionHeader = '';
  String _sessionExtraLine = '';

  /// A SOLVE or CALC session is open (prompts, Continue, result or error screen). AC leaves it.
  bool get _sessionActive => _stage != _SessionStage.none;
  bool get sessionActive => _sessionActive;

  /// The text above the answer: the usual `expression =` line, or the prompt (`A?`) / the equation of a session.
  String get questionLine {
    if (_sessionActive) return _sessionHeader;
    return _lastQuestion.isEmpty ? '' : '$_lastQuestion =';
  }

  /// The second line of the SOLVE solution screen (`L−R=0`), empty otherwise.
  String get sessionExtra => _sessionActive ? _sessionExtraLine : '';

  /// A calculation runs in the background (AC interrupts it).
  bool get busy => _busy;

  /// CALC: saves the expression and asks for the value of each variable in it, in order of appearance (manual p.47-49).
  void esCalc() {
    playSound(ClickType.op);
    _clearModifiers();
    _syntaxError = null;
    if (_busy) return;
    if (_sessionActive) {
      notifyListeners();
      return;
    }
    if (!_beginSession()) return;
    try {
      _calc = CasioCalc(engine, _doc.linear, complex: _mode == CasioMode.cmplx ? complexEngine : null);
      _solver = null;
      _sessionVars = List<String>.of(_calc!.variables);
      _sessionHeader = '';
      _startPrompts();
    } catch (e) {
      _abortBegin(e);
    }
    notifyListeners();
  }

  /// SHIFT + CALC = SOLVE: `expr`, `lhs=rhs` or `…,variable` (manual p.49-51).
  void esSolve() {
    playSound(ClickType.op);
    _clearModifiers();
    _syntaxError = null;
    if (_busy) return;
    if (_sessionActive) {
      notifyListeners();
      return;
    }
    if (!_beginSession()) return;
    try {
      _solver = CasioSolver(engine, _doc.linear);
      _calc = null;
      _sessionVars = <String>[..._solver!.prompts, _solver!.variable];
      _sessionHeader = '';
      _startPrompts();
    } catch (e) {
      _abortBegin(e);
    }
    notifyListeners();
  }

  /// Common start: nothing to run on a result screen or an empty line; an unfilled placeholder is a Syntax ERROR.
  bool _beginSession() {
    if (_hasEvaluated || _doc.root.isEmpty || _expression == '0') {
      notifyListeners();
      return false;
    }
    final placeholder = _doc.firstPlaceholderPath;
    if (placeholder != null) {
      _doc.setCaret(placeholder, 0);
      _syntaxError = 'Syntax ERROR';
      notifyListeners();
      return false;
    }
    _savedDoc = _doc;
    _sessionVals = <String, CVal>{};
    return true;
  }

  /// The line was refused (Syntax ERROR, Variable ERROR, ...): the message is shown and AC returns to the line.
  void _abortBegin(Object e) {
    _stage = _SessionStage.error;
    _showSessionError(CasioEngine.messageOf(e));
  }

  void _showSessionError(String msg) {
    _sessionHeader = '';
    _sessionExtraLine = '';
    _hasEvaluated = true;
    _resultError = true;
    _forms = const <CasioShown>[];
    _answerDisplay = '';
    _setPlain(msg);
  }

  String _valueText(CVal v) => CasioFormatter(engine.config).first(v).display;

  void _startPrompts() {
    if (_sessionVars.isEmpty) {
      _runSession();
      return;
    }
    _showPrompt(0);
  }

  void _showPrompt(int i) {
    _stage = _SessionStage.prompt;
    _sessionIdx = i;
    _hasEvaluated = false;
    _resultError = false;
    _answerDisplay = '';
    _forms = const <CasioShown>[];
    final v = _sessionVars[i];
    final cur = _sessionVals[v] ?? (_solver?.current(v) ?? _calc?.current(v) ?? CVal.zero);
    _sessionHeader = '$v?';
    _sessionExtraLine = '';
    _doc = ExprDoc.plain(_valueText(cur));
    _sessionFresh = true;
  }

  /// `=` inside a session.
  void _sessionEnter() {
    switch (_stage) {
      case _SessionStage.prompt:
        final text = _doc.linear.trim();
        CVal value;
        try {
          value = text.isEmpty ? CVal.zero : (engine.evaluate(text, commit: false).value ?? CVal.zero);
        } catch (e) {
          _syntaxError = CasioEngine.messageOf(e);
          return;
        }
        _sessionVals[_sessionVars[_sessionIdx]] = value;
        if (_sessionIdx + 1 < _sessionVars.length) {
          _showPrompt(_sessionIdx + 1);
        } else {
          _runSession();
        }
      case _SessionStage.continueScreen:
        _runSolveStep(() => _solver!.next());
      case _SessionStage.result:
        // the values stay: `=` goes through the prompts again (manual p.48: "5 = 10 =", "7 = 20 =")
        if (_sessionVars.isEmpty) {
          _runSession();
        } else {
          _showPrompt(0);
        }
      case _SessionStage.error || _SessionStage.none:
        break;
    }
  }

  void _runSession() {
    final calc = _calc;
    if (calc != null) {
      // CALC with ∫ d/dx Σ ∏ can take seconds: it runs in the background and AC interrupts it (Phase 8b)
      if (!kIsWeb && calc.canRunInBackground && CasioEngine.hasCasioCalculus(calc.expression)) {
        calc.store(_sessionVals);
        _evaluateInBackground(calc.expression, (outcome, error) {
          if (error != null || outcome == null) {
            _stage = _SessionStage.error;
            _showSessionError(CasioEngine.messageOf(error ?? const CalcError('Math ERROR')));
          } else {
            calc.finish(outcome);
            _commitCalcResult(calc, outcome);
          }
        });
        return;
      }
      try {
        _commitCalcResult(calc, calc.run(_sessionVals));
      } catch (e) {
        _stage = _SessionStage.error;
        _showSessionError(CasioEngine.messageOf(e));
      }
      return;
    }
    final solver = _solver!;
    final initial = _sessionVals[solver.variable] ?? CVal.zero;
    final given = Map<String, CVal>.of(_sessionVals)..remove(solver.variable);
    _runSolveStep(() => solver.start(given, initial));
  }

  void _commitCalcResult(CasioCalc calc, CasioOutcome out) {
    _sessionHeader = '${calc.text} =';
    _sessionExtraLine = '';
    _forms = out.forms;
    _formIndex = 0;
    _resultError = false;
    _resultRemainder = out.remainder;
    _resultExtra = out.extra;
    _formLines = const <List<String>>[];
    _resultFactorable = out.factorable;
    _answerDisplay = out.remainder != null ? '${out.text} R ${out.remainder}' : out.text;
    _setPlain(_answerDisplay);
    _hasEvaluated = true;
    _stage = _SessionStage.result;
  }

  void _runSolveStep(SolveOutcome Function() step) {
    final solver = _solver!;
    try {
      final o = step();
      _sessionHeader = solver.equation;
      _hasEvaluated = true;
      _resultError = false;
      _forms = const <CasioShown>[];
      _resultExtra = const <String, String>{};
      _resultFactorable = false;
      switch (o) {
        case SolveContinue():
          _stage = _SessionStage.continueScreen;
          _sessionExtraLine = '';
          _answerDisplay = 'Continue: [=]';
        case SolveDone(:final value, :final lMinusR):
          _stage = _SessionStage.result;
          final txt = '${solver.variable}=${solver.show(value)}';
          _forms = <CasioShown>[CasioShown(txt, txt)];
          _answerDisplay = txt;
          _sessionExtraLine = 'L−R=${_valueText(lMinusR)}';
      }
      _setPlain(_answerDisplay);
    } catch (e) {
      _stage = _SessionStage.error;
      _showSessionError(CasioEngine.messageOf(e));
    }
  }

  void _exitSession() {
    _stage = _SessionStage.none;
    _solver = null;
    _calc = null;
    _sessionHeader = '';
    _sessionExtraLine = '';
    _hasEvaluated = false;
    _resultError = false;
    _answerDisplay = '';
    _forms = const <CasioShown>[];
    _lastQuestion = '';
    _lastAnswer = '';
    _doc = _savedDoc ?? ExprDoc.plain('0');
    _savedDoc = null;
  }

  // -- Background calculation (∫, d/dx, Σ, ∏) -----------------------------------------------------------------------
  bool _busy = false;
  Isolate? _isolate;
  ReceivePort? _port;
  Completer<void>? _backgroundDone;

  /// Completes when the calculation started by the last `=` has ended (for tests and callers that want to wait).
  Future<void> get pending => _backgroundDone?.future ?? Future<void>.value();

  void _stopBackground() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _port?.close();
    _port = null;
    _busy = false;
    final d = _backgroundDone;
    _backgroundDone = null;
    if (d != null && !d.isCompleted) d.complete();
  }

  /// Starts [expr] in a background isolate; [commit] runs when it ends (it receives the outcome, or throws what the
  /// engine threw). A web build has no isolates: it calculates in place.
  void _evaluateInBackground(String expr, void Function(CasioOutcome?, Object?) commit) {
    if (kIsWeb) {
      try {
        commit(engine.evaluate(expr, continuesAns: _continuesAns, legacyAngle: _angleMode), null);
      } catch (e) {
        commit(null, e);
      }
      return;
    }
    _busy = true;
    _backgroundDone = Completer<void>();
    final port = ReceivePort();
    _port = port;
    port.listen((Object? m) {
      final reply = m! as List<Object?>;
      final continued = _continuesAns;
      _stopBackground();
      if (reply[0] == 'ok') {
        final mem = reply[2]! as CasioMemory;
        engine.memory
          ..ans = mem.ans
          ..preAns = mem.preAns
          ..ansText = mem.ansText
          ..vars.addAll(mem.vars);
        _continuesAns = continued;
        commit(reply[1]! as CasioOutcome, null);
      } else {
        final k = reply[1]! as int;
        commit(null, k >= 0 ? CasioError(CasioErrorKind.values[k]) : const CalcError('Math ERROR'));
      }
      notifyListeners();
    });
    Isolate.spawn(
      _casioWorker,
      <Object?>[port.sendPort, expr, engine.config, engine.memory, _continuesAns, _angleMode.index],
    ).then((iso) {
      if (_port != port) {
        iso.kill(priority: Isolate.immediate);
      } else {
        _isolate = iso;
      }
    }).catchError((Object e) {
      _stopBackground();
      commit(null, e);
      notifyListeners();
    });
    notifyListeners();
  }

  // -- Live preview -------------------------------------------------------------------------------------------------
  String? _livePreviewKey;
  String _livePreviewValue = '';

  /// Small answer under the expression while typing; mirrors what = would calculate (`livePreview`).
  String get livePreview {
    final key = '$_hasEvaluated|$_expression|$_equation|${_angleMode.id}|$_decimalPrecision|${engine.config.hashCode}';
    if (key == _livePreviewKey) return _livePreviewValue;
    _livePreviewKey = key;
    _livePreviewValue = _computeLivePreview();
    return _livePreviewValue;
  }

  String _computeLivePreview() {
    if (_hasEvaluated || _sessionActive || _busy || _mode == CasioMode.verif) return '';
    final trimmed = _expression.trim();
    // ∫ d/dx Σ ∏ can take seconds: they are calculated only on `=`, in the background
    if (CasioEngine.hasCasioCalculus(trimmed)) return '';
    if (trimmed.isEmpty || _reYStart.hasMatch(trimmed)) return '';
    final isPlainNumber = _rePlainNumber.hasMatch(trimmed);
    if (isPlainNumber && !hasEquation) return '';
    try {
      var exprToEval = trimmed;
      final openCount = _count(exprToEval, '(');
      final closeCount = _count(exprToEval, ')');
      if (openCount > closeCount) exprToEval += ')' * (openCount - closeCount);
      if (hasEquation && isPlainNumber) exprToEval = 'y($trimmed)';
      final formatted = engine.evaluate(exprToEval, legacyAngle: _angleMode, commit: false).text;
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
    if (_busy) return;
    if (_sessionActive) {
      _sessionEnter();
      notifyListeners();
      return;
    }
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
      if (_mode != CasioMode.comp) {
        _evaluateMode(exprToEval, shown);
        notifyListeners();
        return;
      }
      final chemText = ChemCalcFunctions.textResult(exprToEval);
      if (chemText == null && !_hasEvaluated && CasioEngine.hasCasioCalculus(exprToEval)) {
        // ∫ d/dx Σ ∏ run in the background; AC interrupts
        final asked = shown;
        _evaluateInBackground(exprToEval, (outcome, error) {
          if (error != null) {
            _commitError(error);
          } else {
            _commitResult(outcome, null, asked);
          }
        });
        return;
      }
      CasioOutcome? outcome;
      if (chemText == null) {
        outcome = engine.evaluate(exprToEval, continuesAns: _continuesAns, legacyAngle: _angleMode);
      }
      _commitResult(outcome, chemText, shown);
    } catch (err) {
      _commitError(err);
    }
    notifyListeners();
  }

  /// `=` in CMPLX or BASE-N (Phase 7d).
  void _evaluateMode(String expr, String shown) {
    try {
      if (_mode == CasioMode.cmplx) {
        final o = complexEngine.evaluate(expr, engine.config);
        final forms = [for (final f in o.forms) CasioShown(f.text, f.expr)];
        _commitCustom(forms, shown);
        _formLines = [for (final f in o.forms) f.lines];
      } else if (_mode == CasioMode.stat) {
        final o = StatCalc.evaluate(expr, CasioStat.fromData(statData), engine);
        _commitCustom(o.forms, shown);
      } else if (_mode == CasioMode.matrix || _mode == CasioMode.vector) {
        final vectorMode = _mode == CasioMode.vector;
        final o = _matvec.evaluate(expr, engine.config, vectorMode: vectorMode);
        if (o.scalar != null) {
          _commitCustom(CasioFormatter(engine.config).forms(o.scalar!), shown);
        } else {
          final cells = CasioMatVec.cellTexts((o.matrix ?? o.vector)!, engine.config);
          final text = o.matrix != null
              ? '[${[for (var r = 0; r < o.matrix!.rows; r++) '[${cells.sublist(r * o.matrix!.cols, (r + 1) * o.matrix!.cols).join(' ')}]'].join('')}]'
              : '[${cells.join(' ')}]';
          _matResult = o.matrix;
          _vecResult = o.vector;
          _commitCustom([CasioShown(text, vectorMode ? 'VctAns' : 'MatAns')], shown);
          onShowMatVecResult?.call();
        }
      } else if (_mode == CasioMode.table) {
        _tableF = expr;
        onOpenTable?.call();
      } else if (_mode == CasioMode.verif) {
        final o = CasioVerif.verify(engine, expr);
        _commitCustom([CasioShown(o.text, o.isTrue ? '1' : '0')], shown);
      } else {
        final o = _bn.evaluate(expr, _baseMode);
        _bnResult = o;
        final t = o.text;
        _commitCustom([CasioShown(t, t)], shown);
      }
    } catch (err) {
      _commitError(err);
    }
  }

  void _commitCustom(List<CasioShown> forms, String shown) {
    _continuesAns = false;
    final first = forms.first;
    _forms = forms;
    _formIndex = 0;
    _engExp = 0;
    _resultError = false;
    _resultRemainder = null;
    _resultExtra = const <String, String>{};
    _formLines = const <List<String>>[];
    _resultFactorable = false;
    _lastQuestion = shown;
    _lastAnswer = first.display;
    final hMode = _isScientific ? 'scientific' : 'standard';
    if (onAddHistoryRich != null) {
      onAddHistoryRich!.call(expression: shown, result: first.display, mode: hMode, rich: null);
    } else {
      onAddHistory?.call(expression: shown, result: first.display, mode: hMode);
    }
    _recordReplay(shown, first.display);
    _setPlain(first.expr);
    _answerDisplay = first.display == first.expr ? '' : first.display;
    _hasEvaluated = true;
    _persist();
  }

  void _commitResult(CasioOutcome? outcome, String? chemText, String shown) {
    _continuesAns = false;
    final String formatted;
    final String reusable;
    if (outcome == null) {
      formatted = chemText!;
      reusable = chemText;
    } else {
      final first = outcome.shown;
      formatted = outcome.remainder != null ? '${first.display} R ${outcome.remainder}' : first.display;
      reusable = first.expr;
    }
    _forms = outcome == null || outcome.legacy ? const <CasioShown>[] : outcome.forms;
    _formIndex = 0;
    _engExp = 0;
    _resultError = false;
    _resultRemainder = outcome?.remainder;
    _resultExtra = outcome?.extra ?? const <String, String>{};
    _formLines = const <List<String>>[];
    _resultFactorable = outcome?.factorable ?? false;

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

    _recordReplay(shown, formatted);
    _setPlain(outcome?.remainder != null ? first0(outcome!) : reusable);
    _answerDisplay = _resultExtra.isNotEmpty ? _withExtra(formatted) : (formatted == _expression ? '' : formatted);
    _hasEvaluated = true;
    _persist();
  }

  void _commitError(Object err) {
    final msg = err is CalcError || err is CasioError ? CasioEngine.messageOf(err) : 'Error';
    _lastQuestion = _expression;
    _lastAnswer = msg;
    _setPlain(msg);
    _forms = const <CasioShown>[];
    _resultError = true;
    _resultFactorable = false;
    _resultExtra = const <String, String>{};
    _formLines = const <List<String>>[];
    _answerDisplay = '';
    _continuesAns = false;
    _hasEvaluated = true;
  }

  /// With a remainder only the quotient continues into the next calculation (manual p.25).
  String first0(CasioOutcome o) => o.shown.expr;

  // -- S⇔D, mixed fractions, FACT ------------------------------------------------------------------------------------
  /// S⇔D: the next form of the result (fraction ⇔ decimal, √ ⇔ decimal, π ⇔ decimal, recurring when Rdec is on).
  void toggleForm() {
    playSound(ClickType.op);
    if (!canToggleForm || _resultRemainder != null) return;
    _formIndex = (_formIndex + 1) % _forms.length;
    _showForm(_forms[_formIndex]);
  }

  /// SHIFT S⇔D: improper ⇔ mixed fraction.
  void toggleMixedFraction() {
    playSound(ClickType.op);
    if (!_hasEvaluated || _resultRemainder != null) return;
    final v = engine.memory.ans;
    final shown = CasioFormatter(engine.config).toggleMixed(v);
    if (shown == null) return;
    _showForm(shown);
  }

  void _showForm(CasioShown f) {
    _setPlain(f.expr);
    _answerDisplay = _resultExtra.isNotEmpty ? _withExtra(f.display) : (f.display == f.expr ? '' : f.display);
    _lastAnswer = f.display;
    notifyListeners();
  }

  int _engExp = 0;

  /// ENG (right) and SHIFT ENG (left): the exponent of the shown result moves by multiples of 3 (manual p.24-25).
  void engShift({required bool right}) {
    playSound(ClickType.op);
    if (!_hasEvaluated || _resultError || _resultRemainder != null || engine.memory.ans.v == 0) return;
    _engExp = CasioFormatter.nextEng(_engExp, right: right);
    _showForm(CasioFormatter(engine.config).eng(engine.memory.ans.v, _engExp));
  }

  /// FACT: prime factorization of the last result.
  void factorResult() {
    playSound(ClickType.op);
    if (!_hasEvaluated || _resultRemainder != null) return;
    try {
      final text = engine.factorize();
      _answerDisplay = text;
      _lastAnswer = text;
    } catch (_) {
      _resultError = true;
      _answerDisplay = '';
      _setPlain('Math ERROR');
      _lastAnswer = 'Math ERROR';
      _forms = const <CasioShown>[];
    }
    notifyListeners();
  }

  // -- Calculation replay history (Part 9 section R, manual p.31-32) -----------------------------------------------------
  /// COMP, CMPLX and BASE-N keep about 200 bytes of the newest calculations. ▲ ▼ scroll through them. ON, a mode change, a
  /// display-format change and CLR ▸ Setup / All clear them.
  static const int replayBytes = 200;
  final List<_ReplayEntry> _replay = <_ReplayEntry>[];
  int _replayAt = -1;

  int get replayLength => _replay.length;

  /// The ▼▲ annunciator: a result is on screen and there is calculation history behind it.
  bool get replayAvailable => _hasEvaluated && _replay.isNotEmpty;

  void _recordReplay(String question, String answer) {
    if (_mode != CasioMode.comp && _mode != CasioMode.cmplx && _mode != CasioMode.baseN) return;
    _replay.add(_ReplayEntry(question, answer));
    var total = 0;
    for (final e in _replay) {
      total += e.bytes;
    }
    // the oldest go first, but the newest calculation always stays
    while (total > replayBytes && _replay.length > 1) {
      total -= _replay.removeAt(0).bytes;
    }
    _replayAt = _replay.length - 1;
  }

  void _clearReplay() {
    _replay.clear();
    _replayAt = -1;
  }

  /// ▲ (direction −1, older) and ▼ (+1, newer) with a result on screen.
  bool replayStep(int direction) {
    if (_replay.isEmpty || !_hasEvaluated || _busy || _sessionActive) return false;
    final next = _replayAt + direction;
    if (next < 0 || next >= _replay.length) return false;
    _replayAt = next;
    final e = _replay[next];
    _lastQuestion = e.question;
    _lastAnswer = e.answer;
    _answerDisplay = e.answer;
    _setPlain(e.answer);
    _resultError = false;
    _hasEvaluated = true;
    _forms = const <CasioShown>[];
    _clearModifiers();
    playSound(ClickType.toggle);
    notifyListeners();
    return true;
  }

  /// ▲ of the ES tab: inside a structure it moves to the numerator, otherwise it scrolls the history back.
  void esUp() {
    if (moveCaretUp()) return;
    replayStep(-1);
  }

  /// ▼ of the ES tab: to the denominator, otherwise forward in the history.
  void esDown() {
    if (moveCaretDown()) return;
    replayStep(1);
  }

  // -- Memory -------------------------------------------------------------------------------------------------------
  void handleMemory(MemoryAction action) {
    playSound(ClickType.op);
    try {
      // The expression is evaluated first, whatever the action: when it does not evaluate nothing happens.
      if (_hasEvaluated && _resultError) throw const CalcError('error on the display');
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
      _persist();
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
    _stopBackground();
    _copiedTimer?.cancel();
    _equalsTimer?.cancel();
    super.dispose();
  }
}

/// One calculation kept for ▲ ▼ replay.
class _ReplayEntry {
  _ReplayEntry(this.question, this.answer) : bytes = CasioInputBytes.count(question) + CasioInputBytes.count(answer);

  final String question;
  final String answer;
  final int bytes;
}
