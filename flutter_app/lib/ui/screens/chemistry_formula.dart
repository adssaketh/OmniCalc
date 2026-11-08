import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/widgets.dart';

import '../../engine/calc_error.dart';
import '../../engine/chemistry/balancer.dart';
import '../../engine/chemistry/chem_format.dart';
import '../../engine/chemistry/formula.dart';
import '../../engine/chemistry/solver_types.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../widgets/option_select.dart';
import 'chemistry_widgets.dart';

String _message(Object e) => e is CalcError ? e.message : 'Something went wrong with that input';

/// A small table of label/value rows (element breakdown).
Widget _rows(M3Tokens t, List<List<String>> rows, {List<int> flex = const []}) {
  int f(int i) => i < flex.length ? flex[i] : 1;
  return Column(
    children: [
      for (var r = 0; r < rows.length; r++)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(border: r == 0 ? null : Border(top: BorderSide(color: t.outlineVariant))),
          child: Row(
            children: [
              for (var c = 0; c < rows[r].length; c++)
                Expanded(
                  flex: f(c),
                  child: Text(
                    rows[r][c],
                    textAlign: c == 0 ? TextAlign.left : TextAlign.right,
                    style: appText(
                      size: 13,
                      weight: r == 0 ? FontWeight.w700 : FontWeight.w500,
                      color: r == 0 ? t.onSurfaceVariant : t.onSurface,
                      height: 18 / 13,
                      tabular: true,
                    ),
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}

/// Formula tools: molar mass and composition, mole conversions, empirical and molecular formula, unsaturation.
class FormulaToolsTab extends StatefulWidget {
  const FormulaToolsTab({super.key});

  @override
  State<FormulaToolsTab> createState() => _FormulaToolsTabState();
}

class _FormulaToolsTabState extends State<FormulaToolsTab> {
  final _formula = TextEditingController(text: 'Ca(OH)2');
  final _amount = TextEditingController();
  String _from = 'grams';

  // empirical formula
  final List<TextEditingController> _empEl = [TextEditingController(text: 'C'), TextEditingController(text: 'H'), TextEditingController(text: 'O')];
  final List<TextEditingController> _empAmt = [TextEditingController(), TextEditingController(), TextEditingController()];
  final _empMolar = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final c in [_formula, _amount, _empMolar, ..._empEl, ..._empAmt]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_formula, _amount, _empMolar, ..._empEl, ..._empAmt]) {
      c.dispose();
    }
    super.dispose();
  }

  ChemFormula? _parsed;
  String? _formulaError;

  void _parse() {
    final text = _formula.text.trim();
    _parsed = null;
    _formulaError = null;
    if (text.isEmpty) return;
    try {
      _parsed = parseFormula(text);
    } catch (e) {
      _formulaError = _message(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    _parse();
    return chemGap([
      _molarMassCard(context),
      _conversionCard(context),
      _empiricalCard(context),
      _unsaturationCard(context),
    ], gap: 16);
  }

  Widget _molarMassCard(BuildContext context) {
    final t = M3Theme.of(context);
    final f = _parsed;
    return ChemCard(
      title: 'Molar mass and composition',
      subtitle: 'Brackets, hydrates (CuSO4.5H2O), charges (SO4^2-, Fe3+) and isotopes (13C) work. Type digits and ^ on the keyboard.',
      child: chemGap([
        ChemField(fieldKey: const ValueKey('formula-input'), controller: _formula, label: 'Formula', hint: 'e.g. Al2(SO4)3'),
        if (_formulaError != null) ChemErrorText(_formulaError!),
        if (f != null) ...[
          Text(prettyFormula(_formula.text.trim()), key: const ValueKey('formula-pretty'), style: appText(size: 22, weight: FontWeight.w700, color: t.onSurface, height: 28 / 22)),
          ChemValue(
            caption: 'Molar mass',
            value: '${chemNum(f.molarMass, 7)} g/mol',
            big: true,
            note: f.hasIsotopes ? 'Isotopes use the mass number as the atomic mass.' : null,
          ),
          _rows(
            t,
            [
              ['Element', 'Atoms', 'Mass (g/mol)', 'Mass %'],
              for (var i = 0; i < f.parts.length; i++)
                [
                  f.parts[i].label,
                  '${f.parts[i].count}',
                  chemNum(f.parts[i].mass, 6),
                  '${chemNum(f.massPercents[i], 5)} %',
                ],
            ],
            flex: const [2, 2, 3, 3],
          ),
        ],
      ]),
    );
  }

  Widget _conversionCard(BuildContext context) {
    final f = _parsed;
    final amount = parseChemNumber(_amount.text);
    Widget? result;
    if (f != null && amount != null) {
      if (amount.isNaN || amount < 0) {
        result = const ChemErrorText('Enter a number that is zero or more');
      } else {
        final double mol = switch (_from) {
          'grams' => molesFromGrams(amount, f.molarMass),
          'moles' => amount,
          _ => molesFromParticles(amount),
        };
        result = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ChemValue(caption: 'Mass', value: '${chemNum(gramsFromMoles(mol, f.molarMass))} g'),
            const SizedBox(height: 8),
            ChemValue(caption: 'Amount', value: '${chemNum(mol)} mol'),
            const SizedBox(height: 8),
            ChemValue(caption: 'Particles (molecules or formula units)', value: chemNum(particlesFromMoles(mol))),
          ],
        );
      }
    }
    return ChemCard(
      title: 'Moles, grams, particles',
      subtitle: 'Uses the formula above. Avogadro constant 6.02214076×10²³ per mol.',
      child: chemGap([
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: ChemField(fieldKey: const ValueKey('convert-amount'), controller: _amount, label: 'Amount', numeric: true, hint: '0')),
            const SizedBox(width: 10),
            OptionSelect(
              value: _from,
              dialogTitle: 'Amount is in',
              options: const [
                SelectOption(value: 'grams', label: 'grams'),
                SelectOption(value: 'moles', label: 'moles'),
                SelectOption(value: 'particles', label: 'particles'),
              ],
              onChanged: (v) => setState(() => _from = v),
            ),
          ],
        ),
        if (f == null && amount != null) const ChemErrorText('Enter a valid formula first'),
        if (result != null) result,
      ]),
    );
  }

  void _addRow() {
    setState(() {
      final e = TextEditingController();
      final a = TextEditingController();
      e.addListener(() => setState(() {}));
      a.addListener(() => setState(() {}));
      _empEl.add(e);
      _empAmt.add(a);
    });
  }

  void _removeRow() {
    if (_empEl.length <= 2) return;
    setState(() {
      _empEl.removeLast().dispose();
      _empAmt.removeLast().dispose();
    });
  }

  Widget _empiricalCard(BuildContext context) {
    final t = M3Theme.of(context);
    Widget? result;
    final symbols = <String>[];
    final amounts = <double>[];
    var bad = false;
    for (var i = 0; i < _empEl.length; i++) {
      final s = _empEl[i].text.trim();
      final a = parseChemNumber(_empAmt[i].text);
      if (s.isEmpty && a == null) continue;
      if (s.isEmpty || a == null) {
        bad = true;
        continue;
      }
      symbols.add(s);
      amounts.add(a);
    }
    if (symbols.isNotEmpty) {
      if (bad) {
        result = const ChemErrorText('Give both an element and an amount on every row');
      } else {
        try {
          final r = empiricalFormula(symbols, amounts);
          final text = StringBuffer();
          for (var i = 0; i < symbols.length; i++) {
            text.write(symbols[i][0].toUpperCase() + symbols[i].substring(1).toLowerCase());
            if (r.counts[i] > 1) text.write(toSubscript('${r.counts[i]}'));
          }
          final molar = parseChemNumber(_empMolar.text);
          String? molecular;
          if (molar != null && molar.isFinite && molar > 0) {
            molecular = molecularFormulaText(text.toString(), molar);
          }
          result = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ChemValue(caption: 'Empirical formula', value: text.toString(), big: true, note: 'Empirical mass ${chemNum(r.empiricalMass, 6)} g/mol'),
              if (molecular != null) ...[
                const SizedBox(height: 8),
                ChemValue(caption: 'Molecular formula', value: molecular),
              ],
              const SizedBox(height: 8),
              _rows(
                t,
                [
                  ['Element', 'Moles', 'Ratio', 'Subscript'],
                  for (var i = 0; i < symbols.length; i++)
                    [symbols[i], chemNum(r.moles[i], 5), chemNum(r.ratios[i], 5), '${r.counts[i]}'],
                ],
                flex: const [2, 3, 3, 2],
              ),
            ],
          );
        } catch (e) {
          result = ChemErrorText(_message(e));
        }
      }
    }
    return ChemCard(
      title: 'Empirical and molecular formula',
      subtitle: 'Enter mass percent or grams for each element. Give the molar mass to get the molecular formula too.',
      child: chemGap([
        for (var i = 0; i < _empEl.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(width: 90, child: ChemField(fieldKey: ValueKey('emp-el-$i'), controller: _empEl[i], label: 'Element', hint: 'C')),
              const SizedBox(width: 10),
              Expanded(child: ChemField(fieldKey: ValueKey('emp-amt-$i'), controller: _empAmt[i], label: 'Percent or grams', numeric: true, hint: '0')),
            ],
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChemChip(label: 'Add element', selected: false, onTap: _addRow),
            ChemChip(label: 'Remove last', selected: false, onTap: _removeRow),
          ],
        ),
        ChemField(fieldKey: const ValueKey('emp-molar'), controller: _empMolar, label: 'Molar mass (optional)', unit: 'g/mol', numeric: true),
        if (result != null) result,
      ]),
    );
  }

  Widget _unsaturationCard(BuildContext context) {
    final f = _parsed;
    Widget? result;
    if (f != null) {
      try {
        final d = degreesOfUnsaturation(f);
        result = ChemValue(
          caption: 'Degrees of unsaturation (rings + double bonds + 2 × triple bonds)',
          value: chemNum(d),
          note: d == d.roundToDouble() ? null : 'A fractional value means the formula is not a neutral molecule of these elements.',
        );
      } catch (e) {
        result = ChemErrorText(_message(e));
      }
    }
    return ChemCard(
      title: 'Degrees of unsaturation',
      subtitle: 'For the formula above (C, H, N, halogens, O, S).',
      child: result ?? Text('Enter a formula above.', style: appText(size: 13, color: M3Theme.of(context).onSurfaceVariant)),
    );
  }
}

/// Equation balancer, with limiting reagent and percent yield for the balanced equation.
class BalancerTab extends StatefulWidget {
  const BalancerTab({super.key});

  @override
  State<BalancerTab> createState() => _BalancerTabState();
}

class _BalancerTabState extends State<BalancerTab> {
  final _equation = TextEditingController(text: 'C3H8 + O2 -> CO2 + H2O');
  BalancedEquation? _balanced;
  String? _error;

  final List<TextEditingController> _grams = [];
  final _actual = TextEditingController();
  int _product = 0;
  ChemResult? _lr;
  String? _lrError;

  @override
  void dispose() {
    _equation.dispose();
    _actual.dispose();
    for (final c in _grams) {
      c.dispose();
    }
    super.dispose();
  }

  void _balance() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _lr = null;
      _lrError = null;
      try {
        final b = balanceEquation(_equation.text);
        for (final c in _grams) {
          c.dispose();
        }
        _grams
          ..clear()
          ..addAll([for (final _ in b.reactants) TextEditingController()]);
        _balanced = b;
        _error = null;
        _product = 0;
      } catch (e) {
        _balanced = null;
        _error = _message(e);
      }
    });
  }

  void _limiting() {
    final b = _balanced;
    if (b == null) return;
    setState(() {
      try {
        final grams = <double>[];
        for (var i = 0; i < _grams.length; i++) {
          final v = parseChemNumber(_grams[i].text);
          if (v == null) throw CalcError('Enter the mass of ${b.reactants[i].pretty}');
          grams.add(v);
        }
        final actual = parseChemNumber(_actual.text);
        _lr = limitingReagent(b, grams, productIndex: _product, actualGrams: actual);
        _lrError = null;
      } catch (e) {
        _lr = null;
        _lrError = _message(e);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final b = _balanced;
    return chemGap([
      ChemCard(
        title: 'Equation balancer',
        subtitle: 'Separate species with +, the sides with -> or =. Charges: Fe^2+, MnO4^-. Coefficients you type are ignored.',
        child: chemGap([
          ChemField(
            fieldKey: const ValueKey('equation-input'),
            controller: _equation,
            label: 'Equation',
            hint: 'H2 + O2 -> H2O',
            onSubmitted: (_) => _balance(),
          ),
          ChemButton(label: 'Balance', onTap: _balance),
          if (_error != null) ChemErrorText(_error!),
          if (b != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: t.primaryContainer.withValues(alpha: 0.45), borderRadius: const BorderRadius.all(Radius.circular(18))),
              child: SelectableText(
                b.text,
                key: const ValueKey('balanced-text'),
                style: appText(size: 18, weight: FontWeight.w700, color: t.onSurface, height: 26 / 18),
              ),
            ),
            for (var i = 0; i < b.steps.length; i++)
              Text('${i + 1}. ${b.steps[i]}', style: appText(size: 13, color: t.onSurface, height: 18 / 13)),
          ],
        ]),
      ),
      if (b != null)
        ChemCard(
          title: 'Limiting reagent and yield',
          subtitle: 'Enter the mass of each reactant in grams.',
          child: chemGap([
            for (var i = 0; i < b.reactants.length; i++)
              ChemField(
                fieldKey: ValueKey('lr-grams-$i'),
                controller: _grams[i],
                label: b.reactants[i].pretty,
                unit: 'g',
                numeric: true,
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: ChemField(fieldKey: const ValueKey('lr-actual'), controller: _actual, label: 'Actual yield (optional)', unit: 'g', numeric: true)),
                const SizedBox(width: 10),
                OptionSelect(
                  value: '$_product',
                  dialogTitle: 'Product',
                  options: [for (var i = 0; i < b.products.length; i++) SelectOption(value: '$i', label: b.products[i].pretty)],
                  onChanged: (v) => setState(() => _product = int.parse(v)),
                ),
              ],
            ),
            ChemButton(label: 'Find limiting reagent', onTap: _limiting),
            if (_lrError != null) ChemErrorText(_lrError!),
            if (_lr != null) ChemResultView(result: _lr!),
          ]),
        ),
    ], gap: 16);
  }
}
