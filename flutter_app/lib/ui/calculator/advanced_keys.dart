import 'package:flutter/widgets.dart';

import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import 'calc_style.dart';
import 'calculator_controller.dart';

enum _Role { onSurface, primary, tertiary }

enum _Kind { normal, formula, angle }

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
}

const String _hintCalculus = 'Format: diff(f(x), x_val) • integrate(f(x), a, b) • sum(f(x), 1, n)';
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
        tpl('d/dx', 'derivative', 'diff('),
        tpl('∫ dx', 'integral', 'integrate('),
        tpl('∑', 'sum', 'sum('),
        tpl('∏', 'product', 'prod('),
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

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(def.label, maxLines: 1, softWrap: false, overflow: TextOverflow.visible, style: labelStyle),
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
