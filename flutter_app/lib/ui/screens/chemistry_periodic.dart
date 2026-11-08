import 'dart:math' as math;

import 'package:flutter/material.dart' show showDialog;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../engine/chemistry/chem_format.dart';
import '../../engine/chemistry/element_types.dart';
import '../../engine/chemistry/elements.dart';
import '../../engine/chemistry/elements_lookup.dart';
import '../../services/feedback_service.dart';
import '../../state/navigation_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../widgets/option_select.dart';
import '../widgets/pressable.dart';
import 'chemistry_widgets.dart';
import 'screen_utils.dart';

/// The filters of the periodic table. `null` = no filter.
class ElementFilter {
  const ElementFilter({this.category, this.block, this.state});

  final String? category;
  final String? block;

  /// `solid`, `liquid`, `gas` or `unknown` (the dataset has no standard state for some elements).
  final String? state;

  bool matches(ChemElement e) {
    if (category != null && e.category != category) return false;
    if (block != null && e.block != block) return false;
    if (state != null && (e.standardState ?? 'unknown') != state) return false;
    return true;
  }
}

/// Whether [e] is shown at full strength for this search text and these filters (the rest of the table is dimmed).
bool elementHighlighted(ChemElement e, String query, ElementFilter filter) {
  if (!filter.matches(e)) return false;
  if (query.trim().isEmpty) return true;
  return ChemElements.search(query).any((x) => x.z == e.z);
}

/// (row, column) of an element in the layout: periods 1-7 in rows 0-6, groups 1-18 in columns 0-17; the lanthanides
/// (La-Lu) go in row 8 and the actinides (Ac-Lr) in row 9, columns 2-16 (below the table).
(int, int) elementCell(ChemElement e) {
  if (e.z >= 57 && e.z <= 71) return (8, e.z - 57 + 2);
  if (e.z >= 89 && e.z <= 103) return (9, e.z - 89 + 2);
  return (e.period - 1, e.group! - 1);
}

String _oxidation(List<int> states) =>
    states.map((s) => s > 0 ? '+$s' : (s == 0 ? '0' : '−${-s}')).join(', ');

/// Everything the detail sheet shows for one element, as label/value rows. A value the dataset lacks reads "—".
List<(String, String)> elementDetailRows(ChemElement e) {
  String opt(double? v, String unit, [int sig = 6]) => v == null ? '—' : '${chemNum(v, sig)}${unit.isEmpty ? '' : ' $unit'}';
  return [
    ('Atomic number', '${e.z}'),
    ('Atomic mass', '${chemNum(e.mass, 8)} g/mol'),
    ('Category', e.category),
    ('Group', e.group == null ? '— (f-block)' : '${e.group}'),
    ('Period', '${e.period}'),
    ('Block', e.block),
    ('Electron configuration', e.electronConfig ?? '—'),
    ('Electronegativity (Pauling)', opt(e.electronegativity, '')),
    ('Atomic radius', opt(e.atomicRadiusPm, 'pm')),
    ('First ionization energy', opt(e.ionizationEnergyEv, 'eV')),
    ('Electron affinity', opt(e.electronAffinityEv, 'eV')),
    ('Oxidation states', e.oxidationStates.isEmpty ? '—' : _oxidation(e.oxidationStates)),
    ('Standard state', e.standardState ?? '—'),
    ('Melting point', e.meltingPointK == null ? '—' : '${chemNum(e.meltingPointK!)} K (${chemNum(e.meltingPointK! - 273.15)} °C)'),
    ('Boiling point', e.boilingPointK == null ? '—' : '${chemNum(e.boilingPointK!)} K (${chemNum(e.boilingPointK! - 273.15)} °C)'),
    ('Density', opt(e.densityGcm3, 'g/cm³')),
    ('Discovered', e.yearDiscovered == null ? '—' : (e.yearDiscovered! < 0 ? '${-e.yearDiscovered!} BCE' : '${e.yearDiscovered}')),
  ];
}

/// The periodic table tab: search, filters, the 18-column grid with lanthanide and actinide rows, and a detail dialog.
class PeriodicTableTab extends StatefulWidget {
  const PeriodicTableTab({super.key});

  @override
  State<PeriodicTableTab> createState() => _PeriodicTableTabState();
}

class _PeriodicTableTabState extends State<PeriodicTableTab> {
  final TextEditingController _search = TextEditingController();
  ElementFilter _filter = const ElementFilter();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(ChemElement e) {
    playScreenSound(context, ClickType.toggle);
    showElementDetail(context, e);
  }

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final query = _search.text;
    final shown = [for (final e in chemElements) if (elementHighlighted(e, query, _filter)) e];
    final filtering = query.trim().isNotEmpty || _filter.category != null || _filter.block != null || _filter.state != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChemField(fieldKey: const ValueKey('pt-search'), controller: _search, label: 'Search', hint: 'Name, symbol or atomic number'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _select('Category', _filter.category, ['All categories', ...elementCategories], (v) {
              setState(() => _filter = ElementFilter(category: v == 'All categories' ? null : v, block: _filter.block, state: _filter.state));
            }, key: 'pt-category'),
            _select('Block', _filter.block, const ['All blocks', 's', 'p', 'd', 'f'], (v) {
              setState(() => _filter = ElementFilter(category: _filter.category, block: v == 'All blocks' ? null : v, state: _filter.state));
            }, key: 'pt-block'),
            _select('State', _filter.state, const ['All states', 'solid', 'liquid', 'gas', 'unknown'], (v) {
              setState(() => _filter = ElementFilter(category: _filter.category, block: _filter.block, state: v == 'All states' ? null : v));
            }, key: 'pt-state'),
            if (filtering)
              ChemChip(
                label: 'Clear',
                selected: false,
                onTap: () => setState(() {
                  _search.clear();
                  _filter = const ElementFilter();
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _grid(context, t, query),
        const SizedBox(height: 12),
        Text(
          filtering ? '${shown.length} of ${chemElements.length} elements match' : '${chemElements.length} elements. Tap one for details.',
          key: const ValueKey('pt-count'),
          style: appText(size: 12, color: t.onSurfaceVariant, height: 16 / 12),
        ),
        const SizedBox(height: 12),
        _legend(t),
      ],
    );
  }

  Widget _select(String label, String? value, List<String> options, ValueChanged<String> onChanged, {required String key}) {
    return KeyedSubtree(
      key: ValueKey(key),
      child: OptionSelect(
        value: value ?? options.first,
        dialogTitle: label,
        options: [for (final o in options) SelectOption(value: o, label: o.length == 1 ? '$label $o' : (o == 'unknown' ? 'State unknown' : o))],
        onChanged: onChanged,
      ),
    );
  }

  Widget _legend(M3Tokens t) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in elementCategories)
          ChemChip(
            label: c,
            dot: chemCategoryColor(t, c),
            selected: _filter.category == c,
            onTap: () => setState(() => _filter = ElementFilter(category: _filter.category == c ? null : c, block: _filter.block, state: _filter.state)),
          ),
      ],
    );
  }

  Widget _grid(BuildContext context, M3Tokens t, String query) {
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 2.0;
        final fit = (box.maxWidth - gap * 17) / 18;
        // narrower than 34 px a cell is unreadable: the table scrolls sideways instead
        final cell = math.max(34.0, math.min(64.0, fit));
        final width = cell * 18 + gap * 17;
        const rows = 10;
        final byCell = <(int, int), ChemElement>{for (final e in chemElements) elementCell(e): e};

        Widget tile(ChemElement e) {
          final on = elementHighlighted(e, query, _filter);
          final bg = chemCategoryColor(t, e.category);
          final fg = chemOnCategory(t);
          return Opacity(
            opacity: on ? 1 : 0.22,
            child: Pressable(
              key: ValueKey('element-${e.symbol}'),
              pressedScale: 0.9,
              onTap: () => _open(e),
              child: Container(
                width: cell,
                height: cell * 1.1,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.all(Radius.circular(6))),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('${e.z}', style: appText(size: math.max(7, cell * 0.2), color: fg.withValues(alpha: 0.8), height: 1, tabular: true)),
                    ),
                    Text(e.symbol, maxLines: 1, softWrap: false, style: appText(size: cell * 0.36, weight: FontWeight.w700, color: fg, height: 1.15)),
                    if (cell >= 44)
                      Text(chemNum(e.mass, 4), maxLines: 1, softWrap: false, style: appText(size: cell * 0.18, color: fg.withValues(alpha: 0.8), height: 1, tabular: true)),
                  ],
                ),
              ),
            ),
          );
        }

        Widget marker(String text) => SizedBox(
              width: cell,
              height: cell * 1.1,
              child: Center(child: Text(text, style: appText(size: math.max(7, cell * 0.2), color: t.onSurfaceVariant, height: 1))),
            );

        final children = <Widget>[];
        for (var r = 0; r < rows; r++) {
          final cells = <Widget>[];
          for (var c = 0; c < 18; c++) {
            if (c > 0) cells.add(const SizedBox(width: gap));
            final e = byCell[(r, c)];
            if (e != null) {
              cells.add(tile(e));
            } else if (r == 5 && c == 2) {
              cells.add(marker('57–71'));
            } else if (r == 6 && c == 2) {
              cells.add(marker('89–103'));
            } else {
              cells.add(SizedBox(width: cell, height: cell * 1.1));
            }
          }
          if (r == 8) children.add(const SizedBox(height: 14));
          if (r > 0 && r != 8) children.add(const SizedBox(height: gap));
          if (r == 8 || r == 9) {
            // keep the label of the row in the first two empty cells
            cells[0] = SizedBox(width: cell, height: cell * 1.1, child: Align(alignment: Alignment.centerRight, child: Text(r == 8 ? 'La–Lu' : 'Ac–Lr', style: appText(size: math.max(7, cell * 0.2), color: t.onSurfaceVariant, height: 1))));
          }
          children.add(Row(mainAxisSize: MainAxisSize.min, children: cells));
        }

        final table = SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children));
        if (width <= box.maxWidth + 0.5) return table;
        return SingleChildScrollView(
          key: const ValueKey('pt-scroll'),
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: table,
        );
      },
    );
  }
}

/// Opens the detail sheet of [e].
Future<void> showElementDetail(BuildContext context, ChemElement e) {
  final t = M3Theme.of(context);
  final nav = context.read<NavigationState>();
  return showDialog<void>(
    context: context,
    barrierColor: t.scrim.withValues(alpha: 0.45),
    builder: (ctx) => M3Theme(
      tokens: t,
      child: ElementDetailSheet(
        element: e,
        onInsertMass: () {
          Navigator.of(ctx).pop();
          nav.selectResult(chemNum(e.mass, 8));
        },
      ),
    ),
  );
}

/// The element card: big symbol on the category colour, then every field.
class ElementDetailSheet extends StatelessWidget {
  const ElementDetailSheet({super.key, required this.element, this.onInsertMass});

  final ChemElement element;
  final VoidCallback? onInsertMass;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final e = element;
    final fg = chemOnCategory(t);
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 640),
        child: Container(
          key: const ValueKey('element-detail'),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: t.surfaceContainerHigh, borderRadius: const BorderRadius.all(Radius.circular(28))),
          clipBehavior: Clip.hardEdge,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: chemCategoryColor(t, e.category),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${e.z}', style: appText(size: 14, color: fg.withValues(alpha: 0.8), height: 20 / 14, tabular: true)),
                        Text(e.symbol, key: const ValueKey('detail-symbol'), style: appText(size: 48, weight: FontWeight.w700, color: fg, height: 1.1)),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.name, style: appText(size: 22, weight: FontWeight.w700, color: fg, height: 28 / 22)),
                          Text(e.category, style: appText(size: 13, color: fg.withValues(alpha: 0.85), height: 18 / 13)),
                          Text('${chemNum(e.mass, 8)} g/mol', style: appText(size: 13, color: fg.withValues(alpha: 0.85), height: 18 / 13, tabular: true)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  children: [
                    for (final (label, value) in elementDetailRows(e).skip(2))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: Text(label, style: appText(size: 13, color: t.onSurfaceVariant, height: 18 / 13))),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 6,
                              child: Text(value, textAlign: TextAlign.right, style: appText(size: 13, weight: FontWeight.w600, color: t.onSurface, height: 18 / 13, tabular: true)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                // Three pills side by side were too narrow for "Use in calculator" on a phone and it broke into three lines.
                // The main action takes a full-width row of its own; Copy mass and Close share the row under it.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ChemButton(label: 'Use in calculator', onTap: onInsertMass ?? () {}),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChemButton(
                            label: 'Copy mass',
                            secondary: true,
                            onTap: () => Clipboard.setData(ClipboardData(text: chemNum(e.mass, 8))),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: ChemButton(label: 'Close', secondary: true, onTap: () => Navigator.of(context).pop())),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
