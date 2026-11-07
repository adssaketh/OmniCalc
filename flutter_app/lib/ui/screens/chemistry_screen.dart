import 'package:flutter/widgets.dart';

import '../../services/feedback_service.dart';
import '../../theme/tokens.dart';
import '../icons/lucide_icon.dart';
import '../shell/intrinsic_cache.dart';
import '../shell/swipeable_tab_container.dart';
import 'chemistry_formula.dart';
import 'chemistry_periodic.dart';
import 'chemistry_reference.dart';
import 'chemistry_solvers.dart';
import 'screen_utils.dart';

/// Tabs of the Chemistry screen.
enum ChemTab { periodic, formula, solvers, balancer, reference, constants }

/// Label and icon per tab, in order.
const List<({ChemTab tab, String label, LucideIconId icon})> chemTabs = [
  (tab: ChemTab.periodic, label: 'Periodic Table', icon: LucideIconId.atom),
  (tab: ChemTab.formula, label: 'Formula Tools', icon: LucideIconId.scale),
  (tab: ChemTab.solvers, label: 'Solvers', icon: LucideIconId.flame),
  (tab: ChemTab.balancer, label: 'Balancer', icon: LucideIconId.arrowLeftRight),
  (tab: ChemTab.reference, label: 'Reference', icon: LucideIconId.fileText),
  (tab: ChemTab.constants, label: 'Constants', icon: LucideIconId.hash),
];

/// Chemistry (Phase 6): periodic table, formula tools, solvers, equation balancer, reference tables and constants.
class ChemistryScreen extends StatefulWidget {
  const ChemistryScreen({super.key, this.initialTab = ChemTab.periodic});

  final ChemTab initialTab;

  @override
  State<ChemistryScreen> createState() => _ChemistryScreenState();
}

class _ChemistryScreenState extends State<ChemistryScreen> {
  late ChemTab _active = widget.initialTab;

  void _selectTab(String id) {
    playScreenSound(context, ClickType.toggle);
    setState(() => _active = ChemTab.values.firstWhere((t) => t.name == id));
  }

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final bp = Breakpoints.of(context);
    final tabs = [
      for (final f in chemTabs)
        TabItem(
          id: f.tab.name,
          label: f.label,
          iconBuilder: (color, size) => LucideIcon(f.icon, color: color, size: size),
        ),
    ];
    final Widget body = switch (_active) {
      ChemTab.periodic => const PeriodicTableTab(),
      ChemTab.formula => const FormulaToolsTab(),
      ChemTab.solvers => const ChemSolversTab(),
      ChemTab.balancer => const BalancerTab(),
      ChemTab.reference => const ReferenceTab(),
      ChemTab.constants => const ChemConstantsTab(),
    };
    return CachedIntrinsicHeight(
      estimate: 760,
      measureNatural: true,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: bp.xl ? 1152 : 1024),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: SwipeableTabContainer(
              tabs: tabs,
              activeTabId: _active.name,
              onSelectTab: _selectTab,
              child: Container(
                clipBehavior: Clip.hardEdge,
                padding: EdgeInsets.all(bp.pick(16.0, sm: 28.0)),
                decoration: BoxDecoration(color: t.surfaceContainerLow, borderRadius: const BorderRadius.all(Radius.circular(24))),
                child: KeyedSubtree(key: ValueKey('chem-tab-${_active.name}'), child: body),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
