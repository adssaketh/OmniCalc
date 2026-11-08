import 'package:flutter/material.dart' show InputBorder, InputDecoration, Material, MaterialType, SelectableText, TextField;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../engine/chemistry/solver_types.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../widgets/pressable.dart';

/// Small building blocks shared by the tabs of the Chemistry screen (chemistry_screen.dart and its part files).

/// Colour of an element category. Hues are fixed per category; lightness and saturation follow the theme so the cells read
/// on both light and dark surfaces.
Color chemCategoryColor(M3Tokens t, String category) {
  const hues = <String, double>{
    'Alkali metal': 8,
    'Alkaline earth metal': 32,
    'Transition metal': 48,
    'Post-transition metal': 150,
    'Metalloid': 175,
    'Nonmetal': 205,
    'Halogen': 235,
    'Noble gas': 275,
    'Lanthanide': 315,
    'Actinide': 345,
  };
  final h = hues[category] ?? 0;
  return HSLColor.fromAHSL(1, h, t.isDark ? 0.42 : 0.62, t.isDark ? 0.28 : 0.82).toColor();
}

/// Readable text colour on a [chemCategoryColor] cell.
Color chemOnCategory(M3Tokens t) => t.isDark ? const Color(0xFFF1F1F1) : const Color(0xFF1B1B1F);

/// The card every block of a tab sits in.
class ChemCard extends StatelessWidget {
  const ChemCard({super.key, required this.child, this.title, this.subtitle, this.padding = 16});

  final Widget child;
  final String? title;
  final String? subtitle;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(color: t.surfaceContainerLowest, borderRadius: const BorderRadius.all(Radius.circular(22))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) Text(title!, style: appText(size: 15, weight: FontWeight.w700, color: t.onSurface, height: 22 / 15)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle!, style: appText(size: 12, color: t.onSurfaceVariant, height: 16 / 12)),
            ),
          if (title != null || subtitle != null) const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Column with a fixed gap.
Widget chemGap(List<Widget> children, {double gap = 12}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(height: gap),
        children[i],
      ],
    ],
  );
}

/// A labelled text field. [numeric] opens the number keyboard and keeps to number characters (`e` for exponents).
class ChemField extends StatelessWidget {
  const ChemField({
    super.key,
    required this.controller,
    required this.label,
    this.unit,
    this.hint,
    this.numeric = false,
    this.onChanged,
    this.onSubmitted,
    this.fieldKey,
  });

  final TextEditingController controller;
  final String label;
  final String? unit;
  final String? hint;
  final bool numeric;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            unit == null || unit!.isEmpty ? label : '$label ($unit)',
            style: appText(size: 12, weight: FontWeight.w600, color: t.onSurfaceVariant, height: 16 / 12),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: t.surfaceContainer, borderRadius: const BorderRadius.all(Radius.circular(18))),
          child: Material(
            type: MaterialType.transparency,
            child: TextField(
              key: fieldKey,
              controller: controller,
              keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text,
              inputFormatters: numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9eE+\-.]'))] : null,
              autocorrect: false,
              enableSuggestions: false,
              cursorColor: t.onSurface,
              style: appText(size: 16, color: t.onSurface, height: 24 / 16, tabular: true),
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: appText(size: 16, color: t.onSurface.withValues(alpha: 0.3), height: 24 / 16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A filled pill button.
class ChemButton extends StatelessWidget {
  const ChemButton({super.key, required this.label, required this.onTap, this.secondary = false});

  final String label;
  final VoidCallback onTap;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: secondary ? t.surfaceContainerHigh : t.primary,
          borderRadius: const BorderRadius.all(Radius.circular(999)),
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: appText(size: 14, weight: FontWeight.w700, color: secondary ? t.onSurface : t.onPrimary, height: 20 / 14),
        ),
      ),
    );
  }
}

/// A selectable pill (category and filter strips).
class ChemChip extends StatelessWidget {
  const ChemChip({super.key, required this.label, required this.selected, required this.onTap, this.dot});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Optional colour dot in front of the label.
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? t.primary : t.surfaceContainer,
          borderRadius: const BorderRadius.all(Radius.circular(999)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot != null) ...[
              Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: appText(
                size: 12,
                weight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? t.onPrimary : t.onSurfaceVariant,
                height: 16 / 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A horizontally scrolling row of chips.
Widget chemChipStrip(List<Widget> chips, {Key? key}) {
  return SingleChildScrollView(
    key: key,
    scrollDirection: Axis.horizontal,
    physics: const ClampingScrollPhysics(),
    child: Row(
      children: [
        for (var i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          chips[i],
        ],
      ],
    ),
  );
}

/// Red error line under a form.
class ChemErrorText extends StatelessWidget {
  const ChemErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.errorContainer, borderRadius: const BorderRadius.all(Radius.circular(14))),
      child: Text(message, style: appText(size: 13, weight: FontWeight.w600, color: t.onErrorContainer, height: 18 / 13)),
    );
  }
}

/// One caption + value pair of a result.
class ChemValue extends StatelessWidget {
  const ChemValue({super.key, required this.caption, required this.value, this.note, this.big = false});

  final String caption;
  final String value;
  final String? note;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(caption, style: appText(size: 12, color: t.onSurfaceVariant, height: 16 / 12)),
        const SizedBox(height: 2),
        SelectableText(
          value,
          style: appText(size: big ? 20 : 16, weight: FontWeight.w700, color: t.primary, height: big ? 28 / 20 : 24 / 16, tabular: true),
        ),
        if (note != null)
          Text(note!, style: appText(size: 11, color: t.onSurfaceVariant, height: 15 / 11)),
      ],
    );
  }
}

/// The outputs and the numbered working of a [ChemResult].
class ChemResultView extends StatelessWidget {
  const ChemResultView({super.key, required this.result});

  final ChemResult result;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    return Container(
      key: const ValueKey('chem-result'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t.primaryContainer.withValues(alpha: 0.45), borderRadius: const BorderRadius.all(Radius.circular(18))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (result.message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(result.message!, style: appText(size: 14, weight: FontWeight.w700, color: t.onSurface, height: 20 / 14)),
            ),
          for (final o in result.outputs)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ChemValue(caption: o.label, value: o.text, note: o.note, big: o == result.outputs.first),
            ),
          if (result.steps.isNotEmpty) ...[
            Text('Working', style: appText(size: 12, weight: FontWeight.w700, color: t.onSurfaceVariant, height: 16 / 12)),
            const SizedBox(height: 6),
            for (var i = 0; i < result.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text('${i + 1}.', style: appText(size: 12, color: t.onSurfaceVariant, height: 18 / 12, tabular: true)),
                    ),
                    Expanded(
                      child: SelectableText(result.steps[i], style: appText(size: 13, color: t.onSurface, height: 18 / 13, tabular: true)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Parses a field the way the solvers need: a plain number, `1e-5` forms included. Empty text is `null` (not entered);
/// text that is not a number is `NaN` so the solver reports "is not a number".
double? parseChemNumber(String text) {
  final s = text.trim();
  if (s.isEmpty) return null;
  return double.tryParse(s) ?? double.nan;
}
