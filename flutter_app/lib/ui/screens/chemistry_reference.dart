import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../engine/chemistry/chem_constants.dart';
import '../../engine/chemistry/formula.dart';
import '../../engine/chemistry/reference_tables.dart';
import '../../engine/js_number.dart';
import '../../services/feedback_service.dart';
import '../../state/navigation_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../icons/lucide_icon.dart';
import '../widgets/pressable.dart';
import 'chemistry_widgets.dart';
import 'physics_screen.dart' show formatConstantValue;
import 'screen_utils.dart';

/// One reference table as shown on screen (id, title, columns, rows, source note).
class ChemTableView {
  const ChemTableView(this.id, this.title, this.columns, this.rows, this.note);

  final String id;
  final String title;
  final List<String> columns;
  final List<List<String>> rows;
  final String? note;
}

/// Every table of the Reference tab, in order: the static ones, the ions, and the two computed from the element data.
List<ChemTableView> chemReferenceTables() => [
      for (final tb in staticReferenceTables) ChemTableView(tb.id, tb.title, tb.columns, tb.rows, tb.note),
      ChemTableView(
        'polyatomic',
        'Common polyatomic ions',
        const ['Ion', 'Name'],
        [for (final i in polyatomicIons) [prettyFormula(i.formula), i.name]],
        'Charges are part of the formula, so each ion can be typed into Formula tools.',
      ),
      ChemTableView(
        'molar_masses',
        'Molar masses of common compounds',
        const ['Compound', 'Formula', 'g/mol'],
        commonMolarMassRows(),
        'Computed from the element table, not typed in.',
      ),
      ChemTableView(
        'electronegativity',
        'Electronegativity (Pauling)',
        const ['Symbol', 'Name', 'Z', 'Value'],
        electronegativityRows(),
        electronegativityNote,
      ),
    ];

/// The Reference tab: one table at a time, chosen from a chip strip.
class ReferenceTab extends StatefulWidget {
  const ReferenceTab({super.key});

  @override
  State<ReferenceTab> createState() => _ReferenceTabState();
}

class _ReferenceTabState extends State<ReferenceTab> {
  late final List<ChemTableView> _tables = chemReferenceTables();
  late String _active = _tables.first.id;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final table = _tables.firstWhere((x) => x.id == _active);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        chemChipStrip([
          for (final x in _tables)
            KeyedSubtree(
              key: ValueKey('ref-${x.id}'),
              child: ChemChip(label: x.title, selected: x.id == _active, onTap: () => setState(() => _active = x.id)),
            ),
        ]),
        const SizedBox(height: 12),
        ChemCard(
          title: table.title,
          subtitle: table.note,
          padding: 12,
          child: Column(
            key: ValueKey('ref-table-${table.id}'),
            children: [
              _line(t, table, table.columns, header: true, first: true),
              for (final r in table.rows) _line(t, table, r),
            ],
          ),
        ),
      ],
    );
  }

  Widget _line(M3Tokens t, ChemTableView table, List<String> cells, {bool header = false, bool first = false}) {
    // a long last column (rules, notes) gets more room than the short ones
    final wide = table.columns.length <= 2 || table.id == 'solubility';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: t.outlineVariant))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var c = 0; c < cells.length; c++) ...[
            if (c > 0) const SizedBox(width: 8),
            Expanded(
              flex: wide && c == cells.length - 1 ? 3 : 2,
              child: Text(
                cells[c],
                style: appText(
                  size: 12.5,
                  weight: header || c == 0 ? FontWeight.w700 : FontWeight.w500,
                  color: header ? t.onSurfaceVariant : t.onSurface,
                  height: 18 / 12.5,
                  tabular: true,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The Constants tab: the chemistry constants with search, category chips, copy and "use in calculator".
class ChemConstantsTab extends StatefulWidget {
  const ChemConstantsTab({super.key});

  @override
  State<ChemConstantsTab> createState() => _ChemConstantsTabState();
}

class _ChemConstantsTabState extends State<ChemConstantsTab> {
  final TextEditingController _search = TextEditingController();
  String _category = 'All';
  String? _copied;

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

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final q = _search.text.trim().toLowerCase();
    final rows = [
      for (final c in chemConstants)
        if ((_category == 'All' || c.category == _category) &&
            (q.isEmpty || c.name.toLowerCase().contains(q) || c.symbol.toLowerCase().contains(q) || c.id.toLowerCase().contains(q) || c.unit.toLowerCase().contains(q)))
          c,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChemField(fieldKey: const ValueKey('const-search'), controller: _search, label: 'Search', hint: 'Name, symbol or unit'),
        const SizedBox(height: 12),
        chemChipStrip([
          for (final c in ['All', ...chemConstantCategories])
            KeyedSubtree(
              key: ValueKey('const-cat-$c'),
              child: ChemChip(label: c, selected: c == _category, onTap: () => setState(() => _category = c)),
            ),
        ]),
        const SizedBox(height: 12),
        if (rows.isEmpty) Text('No constant matches.', style: appText(size: 13, color: t.onSurfaceVariant)),
        for (final c in rows)
          Container(
            key: ValueKey('chem-const-${c.id}'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: t.surfaceContainerLowest, borderRadius: const BorderRadius.all(Radius.circular(18))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${c.name}  ${c.symbol}', style: appText(size: 13, weight: FontWeight.w700, color: t.onSurface, height: 18 / 13)),
                      Text('${formatConstantValue(c.value)} ${c.unit}', style: appText(size: 13, weight: FontWeight.w600, color: t.primary, height: 18 / 13, tabular: true)),
                      Text(c.description, style: appText(size: 11, color: t.onSurfaceVariant, height: 15 / 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Pressable(
                  key: ValueKey('chem-const-copy-${c.id}'),
                  onTap: () {
                    playScreenSound(context, ClickType.op);
                    Clipboard.setData(ClipboardData(text: jsToString(c.value)));
                    setState(() => _copied = c.id);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: t.surfaceContainerHigh, shape: BoxShape.circle),
                    child: LucideIcon(_copied == c.id ? LucideIconId.check : LucideIconId.copy, color: t.onSurface, size: 14),
                  ),
                ),
                const SizedBox(width: 6),
                Pressable(
                  key: ValueKey('chem-const-insert-${c.id}'),
                  onTap: () {
                    playScreenSound(context, ClickType.op);
                    context.read<NavigationState>().selectResult(jsToString(c.value));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: t.primaryContainer, shape: BoxShape.circle),
                    child: LucideIcon(LucideIconId.cornerDownLeft, color: t.onPrimaryContainer, size: 14),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
