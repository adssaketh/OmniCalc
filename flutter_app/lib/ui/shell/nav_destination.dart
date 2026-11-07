import 'package:flutter/widgets.dart';

import '../../state/navigation_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../icons/nav_icon.dart';

/// The 56 x 32 indicator, the icon on it, the optional history badge and the label under it. Shared by the bottom bar
/// and the navigation rail (`NavigationRail.tsx` repeats `BottomNavBar.tsx` markup). The sliding pill itself is drawn by
/// the parent underneath, so it can travel from one destination to the next.
class NavDestinationContent extends StatelessWidget {
  const NavDestinationContent({
    super.key,
    required this.item,
    required this.label,
    required this.active,
    required this.historyCount,
    this.truncateLabel = true,
  });

  final NavItem item;
  final String label;
  final bool active;
  final int historyCount;

  /// Bottom bar: the label truncates; rail: it never wraps.
  final bool truncateLabel;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 56,
          height: 32,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              NavIcon(
                id: navIconIdFor(item.id),
                active: active,
                size: 22,
                color: active ? t.onPrimaryContainer : t.onSurfaceVariant,
              ),
              if (item.isRecents && historyCount > 0)
                Positioned(
                  top: -4,
                  right: 2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: t.primary, borderRadius: const BorderRadius.all(Radius.circular(9999))),
                    child: Text(
                      historyCount > 99 ? '99+' : '$historyCount',
                      style: appText(size: 10, weight: FontWeight.w700, color: t.onPrimary, height: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: truncateLabel ? TextOverflow.ellipsis : TextOverflow.visible,
          style: appText(
            size: 10.5,
            weight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? t.onSurface : t.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
