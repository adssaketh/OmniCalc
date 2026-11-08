import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../icons/lucide_icon.dart';

/// One choice of an [OptionSelect].
class SelectOption {
  const SelectOption({required this.value, required this.label});

  final String value;
  final String label;
}

/// The web app's `<select>` (`text-xs font-medium rounded-xl px-2.5 py-1.5`, `surface-container-high` background).
/// On the phone the browser opens the system option list; here the same list opens in a dialog. [onChanged] runs only
/// when a different option is picked, like `onChange`.
class OptionSelect extends StatelessWidget {
  const OptionSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.dialogTitle,
    this.fill = false,
    this.background,
    this.radius = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  });

  final String value;
  final List<SelectOption> options;
  final ValueChanged<String> onChanged;
  final String? dialogTitle;

  /// `w-full`: the closed button takes the whole width and the arrow sits at the right edge (Physics Lab). Otherwise it is
  /// as wide as its label.
  final bool fill;

  /// Closed-button background; `surface-container-high` when null.
  final Color? background;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final current = options.firstWhere((o) => o.value == value, orElse: () => options.first);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(context),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(color: background ?? t.surfaceContainerHigh, borderRadius: BorderRadius.all(Radius.circular(radius))),
        child: Row(
          mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Flexible(
              fit: fill ? FlexFit.tight : FlexFit.loose,
              child: Text(
                current.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appText(size: 12, weight: FontWeight.w500, color: t.onSurface, height: 16 / 12),
              ),
            ),
            const SizedBox(width: 4),
            LucideIcon(LucideIconId.chevronDown, color: t.onSurface, size: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final t = M3Theme.of(context);
    final picked = await showDialog<String>(
      context: context,
      barrierColor: t.scrim.withValues(alpha: 0.32),
      builder: (ctx) => M3Theme(
        tokens: t,
        child: Dialog(
          backgroundColor: t.surfaceContainerHigh,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (dialogTitle != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Text(dialogTitle!, style: appText(size: 16, weight: FontWeight.w600, color: t.onSurface)),
                  ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      for (final o in options)
                        GestureDetector(
                          key: ValueKey('option-${o.value}'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(ctx).pop(o.value),
                          child: Container(
                            color: o.value == value ? t.primaryContainer : null,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            child: Text(
                              o.label,
                              style: appText(
                                size: 14,
                                weight: o.value == value ? FontWeight.w700 : FontWeight.w500,
                                color: o.value == value ? t.onPrimaryContainer : t.onSurface,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked != null && picked != value) onChanged(picked);
  }
}
