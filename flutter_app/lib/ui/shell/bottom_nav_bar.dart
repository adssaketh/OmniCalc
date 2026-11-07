import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../services/feedback_service.dart';
import '../../state/navigation_state.dart';
import '../../theme/glass.dart';
import '../../theme/motion.dart';
import '../../theme/spring_value.dart';
import '../../theme/tokens.dart';
import 'nav_destination.dart';

/// Material 3 navigation bar floating at the bottom (`BottomNavBar.tsx`). The app shell positions it; its surface
/// (solid or glass) is [BarSurface].
class BottomNavBar extends StatefulWidget {
  const BottomNavBar({
    super.key,
    required this.currentMode,
    required this.onSelectMode,
    required this.soundEnabled,
    required this.hapticEnabled,
    required this.onToggleHistory,
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
  final VoidCallback onToggleHistory;
  final FeedbackService feedback;
  final bool isHistoryOpen;
  final int historyCount;
  final bool enableGrapher;
  final bool enablePhysics;

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> with TickerProviderStateMixin {
  late final SpringValue _enter;
  late final SpringValue _pill;

  List<NavItem> get _items => getNavItems(widget.enableGrapher, widget.enablePhysics);

  int _activeIndex() {
    final items = _items;
    for (var i = 0; i < items.length; i++) {
      if (isNavItemActive(items[i], widget.currentMode, widget.isHistoryOpen)) return i;
    }
    return -1;
  }

  @override
  void initState() {
    super.initState();
    // initial {y: 90, opacity: 0} -> animate {y: 0, opacity: 1}, transition `spring`
    _enter = SpringValue(vsync: this, spring: M3Springs.spring, initial: 0);
    _pill = SpringValue(vsync: this, spring: M3Springs.springBouncy, initial: math.max(_activeIndex(), 0).toDouble());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _enter.animateTo(1);
    });
  }

  @override
  void didUpdateWidget(BottomNavBar old) {
    super.didUpdateWidget(old);
    final i = _activeIndex();
    if (i >= 0) _pill.animateTo(i.toDouble());
  }

  @override
  void dispose() {
    _enter.dispose();
    _pill.dispose();
    super.dispose();
  }

  void _tap(NavItem item) {
    navFeedback(widget.feedback, soundEnabled: widget.soundEnabled, hapticEnabled: widget.hapticEnabled);
    if (item.isRecents) {
      widget.onToggleHistory();
    } else {
      widget.onSelectMode(item.mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final instant = reduceMotion(context);
    _enter.instant = instant;
    _pill.instant = instant;
    final items = _items;
    final bottom = math.max(MediaQuery.paddingOf(context).bottom, 8.0);

    return AnimatedBuilder(
      animation: _enter,
      builder: (context, child) {
        final p = _enter.value;
        return Opacity(
          opacity: p.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, 90 * (1 - p)), child: child),
        );
      },
      child: Semantics(
        container: true,
        label: 'Bottom Navigation Bar',
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 4, 12, bottom),
          child: Center(
            child: LayoutBuilder(
              builder: (context, box) {
                // max-w-xl (576) and sm:max-w-2xl (672) from 640 up
                final maxW = MediaQuery.sizeOf(context).width >= 640 ? 672.0 : 576.0;
                return ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: BarSurface(
                    borderRadius: const BorderRadius.all(Radius.circular(32)),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: LayoutBuilder(
                        builder: (context, inner) {
                          const gap = 4.0;
                          final itemW = (inner.maxWidth - gap * (items.length - 1)) / items.length;
                          return Stack(
                            children: [
                              // shared sliding pill (`layoutId="bottom-nav-pill"`), 56 x 32 at the top of each item (py-0.5)
                              AnimatedBuilder(
                                animation: _pill,
                                builder: (context, _) => Positioned(
                                  left: _pill.value * (itemW + gap) + (itemW - 56) / 2,
                                  top: 2,
                                  child: Container(
                                    width: 56,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: t.primaryContainer,
                                      borderRadius: const BorderRadius.all(Radius.circular(9999)),
                                    ),
                                  ),
                                ),
                              ),
                              IntrinsicHeight(
                                child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (var i = 0; i < items.length; i++) ...[
                                    if (i > 0) const SizedBox(width: gap),
                                    Expanded(
                                      child: _BarItem(
                                        item: items[i],
                                        active: isNavItemActive(items[i], widget.currentMode, widget.isHistoryOpen),
                                        historyCount: widget.historyCount,
                                        onTap: () => _tap(items[i]),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({required this.item, required this.active, required this.historyCount, required this.onTap});

  final NavItem item;
  final bool active;
  final int historyCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: item.isRecents ? 'Recent Calculations ($historyCount)' : item.label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: NavDestinationContent(item: item, label: item.label, active: active, historyCount: historyCount),
        ),
      ),
    );
  }
}
