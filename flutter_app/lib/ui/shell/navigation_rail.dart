import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../services/feedback_service.dart';
import '../../state/navigation_state.dart';
import '../../theme/motion.dart';
import '../../theme/spring_value.dart';
import '../../theme/tokens.dart';
import '../icons/omnicalc_logo.dart';
import 'header.dart' show buildShellActions;
import 'nav_destination.dart';

/// Material 3 navigation rail for tablets and desktop (`NavigationRail.tsx`): same destinations and pill indicator as the
/// bottom bar. 88 px wide plus the left inset.
class ShellNavigationRail extends StatefulWidget {
  const ShellNavigationRail({
    super.key,
    required this.currentMode,
    required this.onSelectMode,
    required this.soundEnabled,
    required this.hapticEnabled,
    required this.onToggleSound,
    required this.onOpenSettings,
    required this.onOpenGuide,
    required this.onOpenHistory,
    required this.feedback,
    this.isHistoryOpen = false,
    this.historyCount = 0,
    this.enableGrapher = false,
    this.enablePhysics = false,
  });

  final CalculatorMode currentMode;
  final ValueChanged<CalculatorMode> onSelectMode;
  final bool soundEnabled;
  final bool hapticEnabled;
  final VoidCallback onToggleSound;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenGuide;
  final VoidCallback onOpenHistory;
  final FeedbackService feedback;
  final bool isHistoryOpen;
  final int historyCount;
  final bool enableGrapher;
  final bool enablePhysics;

  @override
  State<ShellNavigationRail> createState() => _ShellNavigationRailState();
}

class _ShellNavigationRailState extends State<ShellNavigationRail> with SingleTickerProviderStateMixin {
  // Each item is min-h 48 + py-1 (8) ... the pill sits at the top of its item. Item positions are measured, so the pill
  // follows the active item through a global key per item.
  late final SpringValue _pillY;
  final _stackKey = GlobalKey();
  final Map<String, GlobalKey> _itemKeys = {};
  bool _measuredOnce = false;

  List<NavItem> get _items => getNavItems(widget.enableGrapher, widget.enablePhysics);

  String? _activeId() {
    for (final i in _items) {
      if (isNavItemActive(i, widget.currentMode, widget.isHistoryOpen)) return i.id;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _pillY = SpringValue(vsync: this, spring: M3Springs.springBouncy);
  }

  @override
  void didUpdateWidget(ShellNavigationRail old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPill());
  }

  @override
  void dispose() {
    _pillY.dispose();
    super.dispose();
  }

  double? _targetY() {
    final id = _activeId();
    if (id == null) return null;
    final itemBox = _itemKeys[id]?.currentContext?.findRenderObject() as RenderBox?;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (itemBox == null || stackBox == null || !itemBox.attached || !stackBox.attached) return null;
    return stackBox.globalToLocal(itemBox.localToGlobal(Offset.zero)).dy + 4; // py-1
  }

  void _syncPill() {
    if (!mounted) return;
    final y = _targetY();
    if (y == null) return;
    if (!_measuredOnce) {
      _measuredOnce = true;
      _pillY.jumpTo(y);
    } else {
      _pillY.animateTo(y);
    }
  }

  void _tap(NavItem item) {
    navFeedback(widget.feedback, soundEnabled: widget.soundEnabled, hapticEnabled: widget.hapticEnabled);
    if (item.isRecents) {
      widget.onOpenHistory();
    } else {
      widget.onSelectMode(item.mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    _pillY.instant = reduceMotion(context);
    final pad = MediaQuery.paddingOf(context);
    final items = _items;
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPill());

    return Semantics(
      container: true,
      label: 'Navigation Rail',
      child: Container(
        width: 88 + pad.left,
        color: t.surfaceContainerLow,
        padding: EdgeInsets.fromLTRB(math.max(pad.left, 8), math.max(pad.top, 12), 8, math.max(pad.bottom, 12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Semantics(
              button: true,
              label: 'OmniCalc',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onSelectMode(CalculatorMode.standard),
                child: const OmniCalcLogo(size: 40),
              ),
            ),
            Expanded(
              child: Center(
                child: Stack(
                  key: _stackKey,
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedBuilder(
                      animation: _pillY,
                      builder: (context, _) => Positioned(
                        left: 0,
                        right: 0,
                        top: _pillY.value,
                        child: Center(
                          child: Container(
                            width: 56,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _activeId() == null ? const Color(0x00000000) : t.primaryContainer,
                              borderRadius: const BorderRadius.all(Radius.circular(9999)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < items.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          _RailItem(
                            key: _itemKeys.putIfAbsent(items[i].id, GlobalKey.new),
                            item: items[i],
                            active: isNavItemActive(items[i], widget.currentMode, widget.isHistoryOpen),
                            historyCount: widget.historyCount,
                            onTap: () => _tap(items[i]),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, a) in buildShellActions(
                  t,
                  soundEnabled: widget.soundEnabled,
                  onToggleSound: widget.onToggleSound,
                  onOpenSettings: widget.onOpenSettings,
                  onOpenGuide: widget.onOpenGuide,
                ).indexed) ...[
                  if (i > 0) const SizedBox(height: 8),
                  a,
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({super.key, required this.item, required this.active, required this.historyCount, required this.onTap});

  final NavItem item;
  final bool active;
  final int historyCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: item.railLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Center(
              child: NavDestinationContent(
                item: item,
                label: item.railLabel,
                active: active,
                historyCount: historyCount,
                truncateLabel: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
