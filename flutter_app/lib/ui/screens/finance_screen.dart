import 'package:flutter/material.dart';

import '../../services/feedback_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../icons/lucide_icon.dart';
import '../shell/intrinsic_cache.dart';
import '../shell/swipeable_tab_container.dart';
import 'currency_screen.dart';
import 'screen_utils.dart';

/// `FinanceTab` of FinanceScreen.tsx.
enum FinanceTab { currency, loan, compound, swp, tip, roi }

/// The tab strip of FinanceScreen.tsx: label and lucide icon per tab, in order.
const List<({FinanceTab tab, String label, LucideIconId icon})> financeTabs = [
  (tab: FinanceTab.currency, label: 'Currency', icon: LucideIconId.globe),
  (tab: FinanceTab.loan, label: 'Loan / EMI', icon: LucideIconId.landmark),
  (tab: FinanceTab.compound, label: 'SIP & Compound', icon: LucideIconId.piggyBank),
  (tab: FinanceTab.swp, label: 'SWP', icon: LucideIconId.wallet),
  (tab: FinanceTab.tip, label: 'Tip & Bill', icon: LucideIconId.receipt),
  (tab: FinanceTab.roi, label: 'ROI & CAGR', icon: LucideIconId.lineChart),
];

/// Port of FinanceScreen.tsx. The Currency tab is real (Phase 5b); the other five show a stand-in until Phase 5c.
class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  FinanceTab _active = FinanceTab.currency;

  void _select(String id) {
    playScreenSound(context, ClickType.toggle);
    setState(() => _active = FinanceTab.values.firstWhere((t) => t.name == id));
  }

  @override
  Widget build(BuildContext context) {
    final bp = Breakpoints.of(context);
    final tabs = [
      for (final f in financeTabs)
        TabItem(
          id: f.tab.name,
          label: f.label,
          iconBuilder: (color, size) => LucideIcon(f.icon, color: color, size: size),
        ),
    ];

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
              onSelectTab: _select,
              showNavButtons: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: switch (_active) {
                  FinanceTab.currency => const CurrencyScreen(key: ValueKey('finance-currency')),
                  _ => _StandIn(key: ValueKey('finance-${_active.name}'), label: financeTabs.firstWhere((f) => f.tab == _active).label),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stand-in for the finance tabs that arrive in Phase 5c.
class _StandIn extends StatelessWidget {
  const _StandIn({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    return SizedBox(
      height: 320,
      child: Center(
        child: Text('$label (Phase 5c)', style: appText(size: 16, weight: FontWeight.w600, color: t.onSurfaceVariant)),
      ),
    );
  }
}
