import 'package:flutter/widgets.dart';

import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../engine/casio/base_n.dart';
import 'calc_style.dart';
import '../../engine/casio/stat.dart';
import 'calculator_controller.dart';
import 'spoken.dart';

enum _Role { onSurface, primary, tertiary }

enum _Kind { normal, formula, angle, active }

/// One key of an advanced tab (a `<button className={btnClass}>` of renderAdvancedTabContent).
class _Adv {
  const _Adv(
    this.label,
    this.sub,
    this.onTap, {
    this.kind = _Kind.normal,
    this.labelSize,
    this.textSm = false,
    this.role = _Role.onSurface,
    this.mono = false,
    this.subSize = 10,
    this.subOpacity = 0.7,
    this.shiftLabel,
    this.alphaLabel,
    this.shiftArmed = false,
    this.alphaArmed = false,
  });

  final String label;
  final String sub;
  final VoidCallback onTap;
  final _Kind kind;

  /// Explicit label size (`text-sm`, `text-[11px]`, `text-xs`); null inherits the button's `text-xs sm:text-sm`.
  final double? labelSize;

  /// The label span carries `text-sm`, which also fixes its line box at 20 px.
  final bool textSm;
  final _Role role;
  final bool mono;
  final double subSize;
  final double subOpacity;

  /// Small labels of the SHIFT and ALPHA layers (ES tab), drawn like the photo: SHIFT in the primary colour, ALPHA in the
  /// tertiary colour. The one whose prefix is armed is bold.
  final String? shiftLabel;
  final String? alphaLabel;
  final bool shiftArmed;
  final bool alphaArmed;
}

const String _hintCalculus = 'Fill the boxes with ▶ • diff(f(x), x_val) • integrate(f(x), a, b) • sum(f(x), 1, n) still work typed';
const String _hintProb = 'Syntax: nCr(n, r) • nPr(n, r) • gcd(a, b) • lcm(a, b) • randInt(1, 100)';

/// The five advanced tabs, keys in the order of the TSX (rows of four).
List<_Adv> _keysFor(AdvancedTab tab, CalculatorController c, VoidCallback toggleAngle) {
  _Adv fn(String label, String sub, String name, {double? size, bool textSm = false}) =>
      _Adv(label, sub, () => c.handleFunction(name), labelSize: size, textSm: textSm);
  _Adv tpl(String label, String sub, String template) => _Adv(label, sub, () => c.handleInsertTemplate(template));
  _Adv inp(String label, String sub, String token, {bool textSm = false}) =>
      _Adv(label, sub, () => c.handleInput(token), textSm: textSm, labelSize: textSm ? 14 : null);
  // The exit key (Phase 4b): leaves the superscript / subscript the caret is in. It stands where `sgn` (Calculus tab; still
  // in Powers and Probability) and `%` (Powers tab; still on the main keypad) used to be, so no function is lost.
  _Adv exitKey() => _Adv('→', 'exit power', () => c.exitGroup(), labelSize: 14, textSm: true, role: _Role.primary);
  _Adv formula(String label, String template) =>
      _Adv(label, 'formula', () => c.handleInsertTemplate(template), kind: _Kind.formula, labelSize: 11, role: _Role.primary, subSize: 9, subOpacity: 0.75);

  switch (tab) {
    case AdvancedTab.calculus:
      return [
        // Phase 7c: the structures of the unit (caret starts in the first slot). The words diff( integrate( sum( prod(
        // can still be typed; they keep their OmniCalc meaning.
        _Adv('d/dx', 'derivative', c.esDeriv, labelSize: 12, textSm: true),
        _Adv('∫▭▭', 'integral', c.esIntegral, labelSize: 12, textSm: true),
        _Adv('Σ▭▭', 'sum', c.esSigma, labelSize: 12, textSm: true),
        _Adv('∏▭▭', 'product', c.esProd, labelSize: 12, textSm: true),
        tpl('lim', 'limit', 'limit('),
        fn('|x|', 'abs', 'abs'),
        exitKey(),
        fn('ln', 'base e', 'ln'),
        _Adv('x', 'var x', () => c.handleInput('x'), labelSize: 14, textSm: true, role: _Role.primary, mono: true),
        _Adv('y', 'y = f(x)', c.handleYKey, labelSize: 14, textSm: true, role: _Role.tertiary, mono: true),
        inp(',', 'comma', ', ', textSm: true),
        _Adv('( )', 'parens', c.handleParentheses, labelSize: 14, textSm: true),
        inp('x²', 'square', '^2'),
        inp('xʸ', 'power', '^'),
        fn('√x', 'root', 'sqrt'),
        tpl('eˣ', 'exp', 'exp('),
        formula('d/dx(x²)', 'diff(x^2, '),
        formula('∫(x²)', 'integrate(x^2, 0, '),
        formula('∑(x)', 'sum(x, 1, '),
        formula('∏(x)', 'prod(x, 1, '),
      ];
    case AdvancedTab.trig:
      return [
        fn('sin', 'sine', 'sin'),
        fn('cos', 'cosine', 'cos'),
        fn('tan', 'tangent', 'tan'),
        fn('sec', 'secant', 'sec'),
        fn('csc', 'cosecant', 'csc'),
        fn('cot', 'cotangent', 'cot'),
        fn('sin⁻¹', 'arcsin', 'asin'),
        fn('cos⁻¹', 'arccos', 'acos'),
        fn('tan⁻¹', 'arctan', 'atan'),
        fn('sinh', 'hyp sin', 'sinh'),
        fn('cosh', 'hyp cos', 'cosh'),
        fn('tanh', 'hyp tan', 'tanh'),
        fn('sinh⁻¹', 'arsinh', 'asinh'),
        fn('cosh⁻¹', 'arcosh', 'acosh'),
        fn('tanh⁻¹', 'artanh', 'atanh'),
        fn('sech', 'hyp sec', 'sech'),
        fn('csch', 'hyp csc', 'csch'),
        fn('coth', 'hyp cot', 'coth'),
        inp('π', '3.14159', 'π', textSm: true),
        _Adv(c.angleMode.id.toUpperCase(), 'switch mode', toggleAngle,
            kind: _Kind.angle, labelSize: 12, mono: true, subSize: 9, subOpacity: 0.8),
      ];
    case AdvancedTab.powers:
      return [
        inp('x²', 'square', '^2'),
        inp('x³', 'cube', '^3'),
        inp('xʸ', 'power', '^'),
        inp('x⁻¹', '1/x', '^(-1)'),
        fn('√x', 'sq root', 'sqrt'),
        fn('³√x', 'cube root', 'cbrt'),
        tpl('ʸ√x', 'root(y,x)', 'root('),
        fn('|x|', 'absolute', 'abs'),
        tpl('10ˣ', '10^x', '10^('),
        tpl('2ˣ', '2^x', '2^('),
        tpl('eˣ', 'exp(x)', 'exp('),
        inp('e', '2.71828', 'e', textSm: true),
        fn('ln', 'base e', 'ln'),
        fn('log₁₀', 'base 10', 'log'),
        fn('log₂', 'base 2', 'log2'),
        tpl('log_b', 'any base', 'logb('),
        fn('sgn', 'sign', 'sign'),
        exitKey(),
        _Adv('( )', 'brackets', c.handleParentheses),
        inp(',', 'comma', ', ', textSm: true),
      ];
    case AdvancedTab.prob:
      return [
        tpl('nPr', 'permutation', 'nPr('),
        tpl('nCr', 'combination', 'nCr('),
        inp('x!', 'factorial', '!'),
        tpl('mod', 'modulo', 'mod('),
        tpl('gcd', 'greatest div', 'gcd('),
        tpl('lcm', 'least mult', 'lcm('),
        fn('round', 'nearest', 'round'),
        fn('sgn', 'sign', 'sign'),
        fn('floor', 'round down', 'floor'),
        fn('ceil', 'round up', 'ceil'),
        tpl('rand()', '0 ... 1', 'rand()'),
        tpl('randInt', 'min, max', 'randInt('),
        tpl('min', 'minimum', 'min('),
        tpl('max', 'maximum', 'max('),
        tpl('avg', 'average', 'mean('),
        fn('|x|', 'absolute', 'abs'),
        inp(',', 'comma', ', ', textSm: true),
        _Adv('( )', 'parens', c.handleParentheses, labelSize: 14, textSm: true),
        inp('%', 'percent', '%'),
        inp('π', '3.14159', 'π', textSm: true),
      ];
    case AdvancedTab.constants:
      return [
        inp('π', '3.14159', 'π', textSm: true),
        inp('e', '2.71828', 'e', textSm: true),
        inp('φ', '1.61803', 'φ', textSm: true),
        inp('c', 'light speed', 'c'),
        inp('h', 'planck', 'h'),
        inp('ħ', 'h / 2π', 'hbar'),
        inp('G', 'gravity', 'G'),
        inp('k_B', 'boltzmann', 'kB'),
        inp('N_A', 'avogadro', 'NA'),
        inp('q_e', 'elem charge', 'qe'),
        inp('m_e', 'electron', 'me'),
        inp('g', '9.80665 m/s²', 'g'),
        inp('m_p', 'proton mass', 'mp'),
        inp('m_n', 'neutron mass', 'mn'),
        inp('ε₀', 'permittivity', 'eps0'),
        inp('μ₀', 'permeability', 'mu0'),
        inp('R', 'gas const', 'R'),
        inp('σ', 'stefan-boltz', 'sigma'),
        inp('atm', '101325 Pa', 'atm'),
        inp('au', 'astron unit', 'au'),
      ];
    case AdvancedTab.es:
      // Phase 8a. Every key of this tab honours SHIFT / ALPHA through [layered]: the armed layer's action runs instead of
      // the plain one (a key without that layer just does its plain action).
      _Adv layered(
        String label,
        String sub, {
        required VoidCallback main,
        VoidCallback? shift,
        VoidCallback? alpha,
        String? shiftLabel,
        String? alphaLabel,
        double? size,
        bool mono = false,
      }) =>
          _Adv(
            label,
            sub,
            () {
              if (c.alphaOn && alpha != null) {
                alpha();
              } else if (c.shiftOn && shift != null) {
                shift();
              } else {
                main();
              }
            },
            labelSize: size ?? 14,
            textSm: true,
            mono: mono,
            shiftLabel: shiftLabel,
            alphaLabel: alphaLabel,
            shiftArmed: c.shiftOn && shift != null,
            alphaArmed: c.alphaOn && alpha != null,
          );
      _Adv prefix(String label, String sub, bool on, VoidCallback tap) =>
          _Adv(label, sub, tap, kind: on ? _Kind.active : _Kind.normal, labelSize: 12, textSm: false, role: _Role.primary);
      return [
        prefix('SHIFT', 'prefix', c.shiftOn, c.toggleShift),
        prefix('ALPHA', 'prefix', c.alphaOn, c.toggleAlpha),
        prefix('INS', 'wrap arg', c.insArmed, c.toggleIns),
        layered('CALC', 'calc', main: c.esCalc, shift: c.esSolve, alpha: c.esEquals, shiftLabel: 'SOLVE', alphaLabel: '=', size: 12),
        _Adv('◀', 'left', c.moveCaretLeft, labelSize: 14, textSm: true),
        _Adv('▲', 'up / history', c.esUp, labelSize: 14, textSm: true),
        _Adv('▼', 'down / history', c.esDown, labelSize: 14, textSm: true),
        _Adv('▶', 'right', c.moveCaretRight, labelSize: 14, textSm: true),
        layered('▭/▭', 'fraction', main: c.esFraction, shift: c.esMixedFraction, shiftLabel: 'a▭/▭'),
        layered('√▭', 'root', main: c.esSqrt, shift: c.esCbrt, shiftLabel: '∛▭'),
        _Adv('ⁿ√▭', 'n-th root', c.esRoot, labelSize: 14, textSm: true),
        _Adv('|▭|', 'abs', c.esAbs, labelSize: 14, textSm: true),
        _Adv('log▭▭', 'any base', c.esLogBase, labelSize: 12, textSm: true),
        layered('x²', 'square', main: () => c.esPower('2'), shift: () => c.esPower('3'), shiftLabel: 'x³'),
        _Adv('x⁻¹', 'inverse', () => c.esPower('−1'), labelSize: 14, textSm: true),
        _Adv('xʸ', 'power', () => c.handleInput('^'), labelSize: 14, textSm: true),
        _Adv('X', 'var X', () => c.variableKey('X'), labelSize: 14, textSm: true, role: _Role.primary, mono: true),
        _Adv('Y', 'var Y', () => c.variableKey('Y'), labelSize: 14, textSm: true, role: _Role.tertiary, mono: true),
        _Adv('→', 'exit', c.exitGroup, labelSize: 14, textSm: true, role: _Role.primary),
        _Adv('( )', 'parens', c.handleParentheses, labelSize: 14, textSm: true),
        // Phase 7b: the result keys of the unit
        layered('S⇔D', 'fraction ⇔ dec', main: c.toggleForm, shift: c.toggleMixedFraction, shiftLabel: 'ab/c⇔d/c', size: 12),
        _Adv('FACT', 'prime factors', c.factorResult, labelSize: 12, textSm: true),
        layered('×10ˣ', 'exponent', main: c.esTimesTen, shift: c.esRecurring, shiftLabel: '0.ṅ', size: 12),
        inp('÷R', 'remainder', '÷R', textSm: true),
        layered('ENG', 'engineering', main: () => c.engShift(right: true), shift: () => c.engShift(right: false), shiftLabel: '←', size: 12),
        inp('Ans', 'last result', 'Ans', textSm: true),
        tpl('Rnd', 'round', 'Rnd('),
        tpl('Pol', 'to polar', 'Pol('),
        tpl('Rec', 'to rect.', 'Rec('),
        // Phase 8a: DRG▸ (manual p.37): the angle-unit marks ° ʳ ᵍ
        inp('°', 'DRG▸ degree', '°', textSm: true),
        inp('ʳ', 'DRG▸ radian', 'ʳ', textSm: true),
        inp('ᵍ', 'DRG▸ gradian', 'ᵍ', textSm: true),
        // Phase 8a: memory keys of the unit (manual p.35-36)
        prefix('STO', 'store', c.stoOn, c.toggleSto),
        prefix('RCL', 'recall', c.rclOn, c.toggleRcl),
        _Adv('M+', 'add to M', () => c.handleMemory(MemoryAction.mPlus), labelSize: 14, textSm: true),
        _Adv('M−', 'subtract', () => c.handleMemory(MemoryAction.mMinus), labelSize: 14, textSm: true),
        for (final v in const ['A', 'B', 'C', 'D', 'E', 'F', 'M'])
          _Adv(v, 'var $v', () => c.variableKey(v), labelSize: 14, textSm: true, role: _Role.tertiary, mono: true),
      ];
    case AdvancedTab.modes:
      // Phase 7d. The MODE key opens the menu (COMP, CMPLX, BASE-N, EQN). The CMPLX keys work in CMPLX mode, the BASE-N keys in BASE-N mode.
      _Adv baseKey(String label, BaseMode m) => _Adv(label, 'base', () => c.setBaseMode(m),
          kind: c.mode == CasioMode.baseN && c.baseMode == m ? _Kind.active : _Kind.normal, labelSize: 12, textSm: false, role: _Role.primary);
      return [
        _Adv('MODE', c.modeName, c.openModeMenu,
            labelSize: 12, textSm: true, role: _Role.primary),
        _Adv('CLR', 'setup / memory', c.openClrMenu, labelSize: 12, textSm: true, role: _Role.primary),
        _Adv('OFF', 'screen off', c.powerOff, labelSize: 12, textSm: true, role: _Role.primary),
        inp('i', 'imaginary', 'i', textSm: true),
        inp('∠', 'polar angle', '∠', textSm: true),
        tpl('Abs', 'modulus', 'Abs('),
        tpl('arg', 'argument', 'arg('),
        tpl('Conjg', 'conjugate', 'Conjg('),
        inp('▸r∠θ', 'to polar', '▸r∠θ', textSm: false),
        inp('▸a+bi', 'to rect.', '▸a+bi', textSm: false),
        baseKey('DEC', BaseMode.dec),
        baseKey('HEX', BaseMode.hex),
        baseKey('BIN', BaseMode.bin),
        baseKey('OCT', BaseMode.oct),
        inp('and', 'logic', 'and', textSm: true),
        inp('or', 'logic', 'or', textSm: true),
        inp('xor', 'logic', 'xor', textSm: true),
        inp('xnor', 'logic', 'xnor', textSm: true),
        inp('Not', 'complement', 'Not(', textSm: true),
        inp('Neg', 'negate', 'Neg(', textSm: true),
        inp('d', 'dec number', 'd', textSm: true),
        inp('h', 'hex number', 'h', textSm: true),
        inp('b', 'bin number', 'b', textSm: true),
        inp('o', 'oct number', 'o', textSm: true),
        inp('A', 'hex digit', 'A', textSm: true),
        inp('B', 'hex digit', 'B', textSm: true),
        inp('C', 'hex digit', 'C', textSm: true),
        inp('D', 'hex digit', 'D', textSm: true),
        inp('E', 'hex digit', 'E', textSm: true),
        inp('F', 'hex digit', 'F', textSm: true),
      ];
    case AdvancedTab.data:
      // Phase 7d-2. The keys follow the current mode: STAT (editor, type, statistics), MATRIX, VECTOR, TABLE. In the other
      // modes the four entry keys open each mode.
      _Adv sym(String label, String sub) => _Adv(label, sub, () => c.handleInput(label), labelSize: label.length > 3 ? 12 : 14, textSm: true);
      switch (c.mode) {
        case CasioMode.stat:
          final t = c.statType;
          final two = t.paired;
          return [
            _Adv('Data', 'editor', c.openStatEditor, labelSize: 12, textSm: true, role: _Role.primary),
            _Adv('Type', 'STAT type', c.openStatTypeMenu, labelSize: 12, textSm: true, role: _Role.primary),
            _Adv('MODE', 'menu', c.openModeMenu, labelSize: 12, textSm: true, role: _Role.primary),
            _Adv('( )', 'parens', c.handleParentheses, labelSize: 14, textSm: true),
            for (final k in two ? StatKeys.sums2 : StatKeys.sums1) sym(k, 'sum'),
            for (final k in two ? StatKeys.vars2 : StatKeys.vars1) sym(k, 'variable'),
            for (final k in two ? StatKeys.minMax2 : StatKeys.minMax1) sym(k, two ? 'min/max' : 'min/max/quart'),
            if (two)
              for (final k in (t == StatType.quadratic ? StatKeys.regQuad : StatKeys.reg)) sym(k, 'regression'),
            if (!two) for (final k in StatKeys.distr) sym(k, 'normal'),
          ];
        case CasioMode.matrix:
          return [
            _Adv('Dim', 'MatA..C', c.openMatVecEditor, labelSize: 12, textSm: true, role: _Role.primary),
            _Adv('MODE', 'menu', c.openModeMenu, labelSize: 12, textSm: true, role: _Role.primary),
            _Adv('Ans', 'MatAns', c.showMatVecResult, labelSize: 12, textSm: true, role: _Role.primary),
            _Adv('( )', 'parens', c.handleParentheses, labelSize: 14, textSm: true),
            inp('MatA', 'matrix', 'MatA', textSm: true),
            inp('MatB', 'matrix', 'MatB', textSm: true),
            inp('MatC', 'matrix', 'MatC', textSm: true),
            inp('MatAns', 'last result', 'MatAns', textSm: true),
            tpl('det', 'determinant', 'det('),
            tpl('Trn', 'transpose', 'Trn('),
            tpl('Ref', 'row echelon', 'Ref('),
            tpl('Rref', 'reduced', 'Rref('),
            tpl('Abs', 'element-wise', 'Abs('),
            inp('x²', 'square', '^2'),
            inp('x³', 'cube', '^3'),
            inp('x⁻¹', 'inverse', '^(−1)'),
          ];
        case CasioMode.vector:
          return [
            _Adv('Dim', 'VctA..C', c.openMatVecEditor, labelSize: 12, textSm: true, role: _Role.primary),
            _Adv('MODE', 'menu', c.openModeMenu, labelSize: 12, textSm: true, role: _Role.primary),
            _Adv('Ans', 'VctAns', c.showMatVecResult, labelSize: 12, textSm: true, role: _Role.primary),
            _Adv('( )', 'parens', c.handleParentheses, labelSize: 14, textSm: true),
            inp('VctA', 'vector', 'VctA', textSm: true),
            inp('VctB', 'vector', 'VctB', textSm: true),
            inp('VctC', 'vector', 'VctC', textSm: true),
            inp('VctAns', 'last result', 'VctAns', textSm: true),
            inp('Dot', 'dot product', ' Dot ', textSm: true),
            inp('×', 'cross product', '×', textSm: true),
            tpl('Abs', 'magnitude', 'Abs('),
          ];
        case CasioMode.table:
          return [
            _Adv('f(x)', 'table', c.openTableSheet, labelSize: 12, textSm: true, role: _Role.primary),
            _Adv('MODE', 'menu', c.openModeMenu, labelSize: 12, textSm: true, role: _Role.primary),
            inp('X', 'var X', 'X', textSm: true),
            _Adv('( )', 'parens', c.handleParentheses, labelSize: 14, textSm: true),
          ];
        case CasioMode.verif:
          // Phase 7e: the relational operators of the VERIF menu (manual p.85); = on the main keypad answers TRUE or FALSE.
          return [
            _Adv('MODE', 'menu', c.openModeMenu, labelSize: 12, textSm: true, role: _Role.primary),
            _Adv('( )', 'parens', c.handleParentheses, labelSize: 14, textSm: true),
            inp('=', 'equal', '=', textSm: true),
            inp('≠', 'not equal', '≠', textSm: true),
            inp('>', 'greater', '>', textSm: true),
            inp('<', 'less', '<', textSm: true),
            inp('≥', 'at least', '≥', textSm: true),
            inp('≤', 'at most', '≤', textSm: true),
            inp('π', '3.14159', 'π', textSm: true),
            inp('e', '2.71828', 'e', textSm: true),
            inp('A', 'variable', 'A', textSm: true),
            inp('B', 'variable', 'B', textSm: true),
            inp('X', 'variable', 'X', textSm: true),
            inp('Y', 'variable', 'Y', textSm: true),
          ];
        default:
          return [
            _Adv('STAT', 'statistics', c.openStatTypeMenu, labelSize: 12, textSm: true, role: _Role.primary),
            _Adv('MATRIX', 'MatA..C', c.enterMatrix, labelSize: 12, textSm: true, role: _Role.primary),
            _Adv('VECTOR', 'VctA..C', c.enterVector, labelSize: 12, textSm: true, role: _Role.primary),
            _Adv('TABLE', 'f(x) table', c.enterTable, labelSize: 12, textSm: true, role: _Role.primary),
            _Adv('VERIF', 'TRUE / FALSE', c.enterVerif, labelSize: 12, textSm: true, role: _Role.primary),
            _Adv('INEQ', 'inequalities', () => c.onOpenIneq?.call(), labelSize: 12, textSm: true, role: _Role.primary),
            _Adv('DIST', 'distributions', () => c.onOpenDist?.call(), labelSize: 12, textSm: true, role: _Role.primary),
          ];
      }
    case AdvancedTab.chemistry:
      // Phase 6. The functions take their text in quotes, e.g. molar("H2O"), amass("Fe"), atomic("Fe"), atomicsym(26).
      return [
        tpl('molar', 'molar mass', 'molar("'),
        tpl('amass', 'atomic mass', 'amass("'),
        tpl('atomic', 'atomic no.', 'atomic("'),
        tpl('atomicsym', 'symbol of Z', 'atomicsym('),
        inp('" "', 'quote', '"', textSm: true),
        _Adv('( )', 'parens', c.handleParentheses, labelSize: 14, textSm: true),
        inp(',', 'comma', ', ', textSm: true),
        inp('N_A', 'avogadro', 'NA'),
        inp('R', 'gas const', 'R'),
        inp('k_B', 'boltzmann', 'kB'),
        inp('q_e', 'elem charge', 'qe'),
        inp('atm', '101325 Pa', 'atm'),
        formula('H₂O', 'molar("H2O")'),
        formula('NaCl', 'molar("NaCl")'),
        formula('CO₂', 'molar("CO2")'),
        formula('C₆H₁₂O₆', 'molar("C6H12O6")'),
        formula('Ca(OH)₂', 'molar("Ca(OH)2")'),
        formula('Al₂(SO₄)₃', 'molar("Al2(SO4)3")'),
        formula('KMnO₄', 'molar("KMnO4")'),
        formula('CuSO₄·5H₂O', 'molar("CuSO4.5H2O")'),
      ];
  }
}

/// `renderAdvancedTabContent(isLandscapeMode)`: the keys of the selected tab, plus the format hint under the Calculus
/// and Probability tabs in portrait.
class AdvancedTabContent extends StatelessWidget {
  const AdvancedTabContent({
    super.key,
    required this.controller,
    required this.onToggleAngleMode,
    required this.width,
    required this.landscape,
  });

  final CalculatorController controller;
  final VoidCallback onToggleAngleMode;
  final double width;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final tab = controller.advancedTab;
    final keys = _keysFor(tab, controller, onToggleAngleMode);
    final cols = landscape ? 4 : (width >= 640 ? 6 : 4);
    final gap = tw(width, 6, sm: 8);
    final rows = <List<_Adv>>[];
    for (var i = 0; i < keys.length; i += cols) {
      rows.add(keys.sublist(i, i + cols > keys.length ? keys.length : i + cols));
    }

    Widget rowOf(List<_Adv> rowKeys, int rowIndex) {
      final cells = <Widget>[];
      for (var k = 0; k < cols; k++) {
        if (k > 0) cells.add(SizedBox(width: gap));
        final idx = rowIndex * cols + k;
        cells.add(Expanded(
          child: k < rowKeys.length
              ? AdvKeyIn(index: idx, replayKey: tab, child: _AdvButton(def: rowKeys[k], width: width, landscape: landscape, t: t))
              : const SizedBox.shrink(),
        ));
      }
      final row = Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells);
      // portrait rows sit in an unbounded-height column: IntrinsicHeight gives the equal-height CSS grid row
      return landscape ? row : IntrinsicHeight(child: row);
    }

    final grid = landscape
        ? Column(
            children: [
              for (var r = 0; r < rows.length; r++) ...[
                if (r > 0) SizedBox(height: gap),
                Expanded(child: rowOf(rows[r], r)),
              ],
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 0; r < rows.length; r++) ...[
                if (r > 0) SizedBox(height: gap),
                rowOf(rows[r], r),
              ],
            ],
          );

    final hint = !landscape && (tab == AdvancedTab.calculus || tab == AdvancedTab.prob)
        ? Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              tab == AdvancedTab.calculus ? _hintCalculus : _hintProb,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: calcText(size: 10, weight: FontWeight.w400, color: t.onSurfaceVariant, lineHeight: 15, mono: true, opacity: 0.75),
            ),
          )
        : null;

    if (landscape) return grid;
    return Column(mainAxisSize: MainAxisSize.min, children: [grid, if (hint != null) hint]);
  }
}

class _AdvButton extends StatelessWidget {
  const _AdvButton({required this.def, required this.width, required this.landscape, required this.t});

  final _Adv def;
  final double width;
  final bool landscape;
  final M3Tokens t;

  @override
  Widget build(BuildContext context) {
    final sm = width >= 640;
    final radius = BorderRadius.circular(sm ? 26 : 22);
    final inheritedSize = sm ? 14.0 : 12.0;
    final inheritedLine = sm ? 20.0 : 16.0;

    final Color bg;
    final Color fg;
    switch (def.kind) {
      case _Kind.angle:
      case _Kind.active:
        bg = t.primaryContainer;
        fg = t.onPrimaryContainer;
      case _Kind.formula:
        bg = t.surfaceContainerHigh;
        fg = t.onSurface;
      case _Kind.normal:
        bg = landscape ? t.surfaceContainer : t.surfaceContainerHigh;
        fg = t.onSurface;
    }
    final labelColor = switch (def.role) {
      _Role.onSurface => fg,
      _Role.primary => t.primary,
      _Role.tertiary => t.tertiary,
    };

    final labelStyle = calcText(
      size: def.labelSize ?? inheritedSize,
      weight: FontWeight.w700,
      color: labelColor,
      // `text-sm` fixes the line box at 20 px and `text-xs` (the angle key) at 16 px; other labels inherit the button's.
      lineHeight: def.textSm ? 20 : (def.kind == _Kind.angle ? 16 : inheritedLine),
      mono: def.mono,
    );
    final subStyle = calcText(
      size: def.subSize,
      weight: FontWeight.w600,
      color: fg,
      lineHeight: inheritedLine,
      opacity: def.subOpacity,
    );

    Widget layerLabels() {
      TextStyle layer(Color color, bool armed) => subStyle.copyWith(
            color: color,
            fontWeight: armed ? FontWeight.w800 : FontWeight.w600,
            decoration: armed ? TextDecoration.underline : TextDecoration.none,
            decorationColor: color,
          );
      // one Text.rich, not a Row: like the plain sub label it may run past the key without a layout overflow
      return Text.rich(
        TextSpan(children: [
          if (def.shiftLabel != null) TextSpan(text: def.shiftLabel, style: layer(t.primary, def.shiftArmed)),
          if (def.shiftLabel != null && def.alphaLabel != null) const TextSpan(text: '  '),
          if (def.alphaLabel != null) TextSpan(text: def.alphaLabel, style: layer(t.tertiary, def.alphaArmed)),
        ]),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
      );
    }

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(def.label, semanticsLabel: spokenKey(def.label), maxLines: 1, softWrap: false, overflow: TextOverflow.visible, style: labelStyle),
        if (def.shiftLabel != null || def.alphaLabel != null)
          layerLabels()
        else
          Text(def.sub, maxLines: 1, softWrap: false, overflow: TextOverflow.visible, style: subStyle),
      ],
    );

    final Widget body;
    if (landscape) {
      final minH = tw(width, 48, sm: 54, md: 62);
      body = ConstrainedBox(
        constraints: BoxConstraints(minHeight: minH),
        child: Center(child: Padding(padding: const EdgeInsets.all(6), child: content)),
      );
    } else {
      body = Padding(
        padding: EdgeInsets.symmetric(vertical: tw(width, 10, sm: 14), horizontal: tw(width, 8, sm: 12)),
        child: Center(child: content),
      );
    }

    return M3Key(
      foreground: fg,
      background: bg,
      borderRadius: radius,
      onTap: def.onTap,
      child: body,
    );
  }
}
