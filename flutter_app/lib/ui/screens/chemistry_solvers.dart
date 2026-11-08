import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/widgets.dart';

import '../../engine/calc_error.dart';
import '../../engine/chemistry/all_solvers.dart';
import '../../engine/chemistry/solver_types.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../widgets/option_select.dart';
import '../widgets/pressable.dart';
import 'chemistry_widgets.dart';

/// The Solvers tab: topics grouped by section; opening one shows its fields, the formula, the answer and the working.
class ChemSolversTab extends StatefulWidget {
  const ChemSolversTab({super.key, this.initialSolverId});

  /// Opens this solver straight away (tests and deep links).
  final String? initialSolverId;

  @override
  State<ChemSolversTab> createState() => _ChemSolversTabState();
}

class _ChemSolversTabState extends State<ChemSolversTab> {
  String? _selected;
  String _group = chemSolverGroups.first;
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSolverId;
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ChemSolver> _visible() {
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      return [
        for (final s in allChemSolvers)
          if (s.title.toLowerCase().contains(q) || s.summary.toLowerCase().contains(q) || s.group.toLowerCase().contains(q)) s,
      ];
    }
    return solversInGroup(_group);
  }

  @override
  Widget build(BuildContext context) {
    final sel = _selected == null ? null : allChemSolvers.where((s) => s.id == _selected).firstOrNull;
    if (sel != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ChemChip(label: '← All topics', selected: false, onTap: () => setState(() => _selected = null)),
          ),
          const SizedBox(height: 12),
          SolverPanel(key: ValueKey('solver-${sel.id}'), solver: sel),
        ],
      );
    }
    final t = M3Theme.of(context);
    final list = _visible();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChemField(fieldKey: const ValueKey('solver-search'), controller: _search, label: 'Search topics', hint: 'e.g. buffer, half-life, ideal gas'),
        const SizedBox(height: 12),
        if (_search.text.trim().isEmpty)
          chemChipStrip([
            for (final g in chemSolverGroups)
              KeyedSubtree(
                key: ValueKey('group-$g'),
                child: ChemChip(label: g, selected: g == _group, onTap: () => setState(() => _group = g)),
              ),
          ]),
        const SizedBox(height: 12),
        if (list.isEmpty)
          Text('No topic matches that search.', style: appText(size: 13, color: t.onSurfaceVariant))
        else
          for (final s in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Pressable(
                key: ValueKey('solver-tile-${s.id}'),
                onTap: () => setState(() => _selected = s.id),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: t.surfaceContainerLowest, borderRadius: const BorderRadius.all(Radius.circular(18))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title, style: appText(size: 15, weight: FontWeight.w700, color: t.onSurface, height: 22 / 15)),
                      const SizedBox(height: 2),
                      Text(s.summary, style: appText(size: 12, color: t.onSurfaceVariant, height: 16 / 12)),
                      if (_search.text.trim().isNotEmpty)
                        Text(s.group, style: appText(size: 11, weight: FontWeight.w600, color: t.primary, height: 15 / 11)),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

/// The form of one solver: mode switch, fields, relation, Solve, result.
class SolverPanel extends StatefulWidget {
  const SolverPanel({super.key, required this.solver});

  final ChemSolver solver;

  @override
  State<SolverPanel> createState() => _SolverPanelState();
}

class _SolverPanelState extends State<SolverPanel> {
  late String _modeId = widget.solver.modes.first.id;
  final Map<String, TextEditingController> _fields = {};
  ChemResult? _result;
  String? _error;

  ChemMode get _mode => widget.solver.modes.firstWhere((m) => m.id == _modeId);

  TextEditingController _ctl(String modeId, ChemInput i) {
    return _fields.putIfAbsent('$modeId/${i.id}', () {
      final c = TextEditingController(text: i.initial == null ? '' : chemFieldText(i.initial!));
      return c;
    });
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _solve() {
    FocusManager.instance.primaryFocus?.unfocus();
    final mode = _mode;
    final values = <String, double>{};
    for (final i in mode.inputs) {
      final v = parseChemNumber(_ctl(mode.id, i).text);
      if (v != null) values[i.id] = v;
    }
    setState(() {
      try {
        _result = mode.run(values);
        _error = null;
      } on CalcError catch (e) {
        _result = null;
        _error = e.message;
      } catch (_) {
        _result = null;
        _error = 'That combination of values cannot be solved';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final s = widget.solver;
    final mode = _mode;
    return ChemCard(
      title: s.title,
      subtitle: s.summary,
      child: chemGap([
        if (s.modes.length > 1)
          Row(
            children: [
              Expanded(
                child: OptionSelect(
                  fill: true,
                  value: _modeId,
                  dialogTitle: 'Solve for',
                  options: [for (final m in s.modes) SelectOption(value: m.id, label: m.label)],
                  onChanged: (v) => setState(() {
                    _modeId = v;
                    _result = null;
                    _error = null;
                  }),
                ),
              ),
            ],
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: t.surfaceContainer, borderRadius: const BorderRadius.all(Radius.circular(14))),
          child: SelectableText(mode.formula, key: const ValueKey('solver-formula'), style: appText(size: 14, weight: FontWeight.w600, color: t.onSurface, height: 20 / 14, tabular: true)),
        ),
        for (final i in mode.inputs)
          ChemField(
            fieldKey: ValueKey('in-${mode.id}-${i.id}'),
            controller: _ctl(mode.id, i),
            label: i.label,
            unit: i.unit,
            numeric: true,
            onSubmitted: (_) => _solve(),
          ),
        ChemButton(label: 'Solve', onTap: _solve),
        if (_error != null) ChemErrorText(_error!),
        if (_result != null) ChemResultView(result: _result!),
      ]),
    );
  }
}

/// A starting value as field text: whole numbers without `.0`.
String chemFieldText(double v) => v == v.roundToDouble() && v.abs() < 1e15 ? v.toStringAsFixed(0) : '$v';
