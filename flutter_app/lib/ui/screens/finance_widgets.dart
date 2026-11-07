import 'package:flutter/material.dart' show InputBorder, InputDecoration, Material, MaterialType, TextField;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../engine/js_locale.dart';
import '../../engine/js_number.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../icons/lucide_icon.dart';
import '../widgets/pressable.dart';
import 'screen_utils.dart';

// =====================================================================================================================
// Shared pieces of the five calculator tabs of the Finance screen (LoanCalculator.tsx, CompoundCalculator.tsx,
// SWPCalculator.tsx, TipCalculator.tsx, ROICalculator.tsx). In the web app each component repeats the same markup; the
// sizes below are the Tailwind classes it uses, written once.
// =====================================================================================================================

/// `currencySymbol = '₹'` default of the finance components.
const String kRupee = '₹';

const Color finEmeraldDark = Color(0xFF34D399); // emerald-400
const Color finEmeraldLight = Color(0xFF047857); // emerald-700
const Color finAmberDarkText = Color(0xFFFBBF24); // amber-400 (table interest column)
const Color finAmber300 = Color(0xFFFCD34D); // amber-300 (dark "Effective with GST")
const Color finAmberLightText = Color(0xFFB45309); // amber-700
const Color finAmber500 = Color(0xFFF59E0B); // amber-500 (taxes bar, SWP warning)

/// `formatMoney` / `formatINR` of the components: `Math.round(val).toLocaleString('en-IN')`.
String formatMoney(double val) => jsToLocaleStringEnIN(jsRound(val));

/// Width of [text] on one line (for items that CSS lets shrink in proportion to their own width).
double measureText(BuildContext context, String text, TextStyle style) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final w = tp.width;
  tp.dispose();
  return w;
}

/// Flex factor that makes a [Flexible] shrink like a CSS flex item: in proportion to its own width.
int flexFor(double width) {
  final v = (width * 10).round();
  return v < 1 ? 1 : v;
}

// ---------------------------------------------------------------------------------------------------------------------
// Layout: `grid grid-cols-1 md:grid-cols-12 gap-5 sm:gap-6 items-start`, inputs col-span-6, results col-span-6
// ---------------------------------------------------------------------------------------------------------------------

class FinanceLayout extends StatelessWidget {
  const FinanceLayout({super.key, required this.inputs, required this.results});

  final List<Widget> inputs;
  final Widget results;

  @override
  Widget build(BuildContext context) {
    final bp = Breakpoints.of(context);
    final gap = bp.pick(20.0, sm: 24.0);
    // `flex flex-col gap-4`
    final inputColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < inputs.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          inputs[i],
        ],
      ],
    );
    final Widget grid = bp.md
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: inputColumn),
              SizedBox(width: gap),
              Expanded(child: results),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [inputColumn, SizedBox(height: gap), results],
          );
    // `w-full max-w-5xl xl:max-w-6xl mx-auto`
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: bp.xl ? 1152 : 1024),
        child: grid,
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------------
// Input cards
// ---------------------------------------------------------------------------------------------------------------------

/// `rounded-2xl p-4` on `--m3-surface-container-low`.
class InputCard extends StatelessWidget {
  const InputCard({super.key, required this.children, this.row = false});

  final List<Widget> children;

  /// `flex items-center justify-between` (the Tip round-up card) instead of stacked content.
  final bool row;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.surfaceContainerLow, borderRadius: const BorderRadius.all(Radius.circular(16))),
      child: row
          ? Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: children)
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// `<label className="block text-xs font-medium mb-1">`.
class CardLabel extends StatelessWidget {
  const CardLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: appText(size: 12, weight: FontWeight.w500, color: t.onSurfaceVariant, height: 16 / 12)),
    );
  }
}

/// The label line of cards that show the current value on the right.
class CardHeader extends StatelessWidget {
  const CardHeader({super.key, required this.label, required this.value, this.accent = false, this.valueKey});

  final String label;
  final String value;

  /// `text-xs font-semibold` in the accent colour (`--m3-primary`); otherwise `text-xs font-mono` muted.
  final bool accent;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final labelStyle = appText(size: 12, weight: FontWeight.w500, color: t.onSurfaceVariant, height: 16 / 12);
    final valueStyle = accent
        ? appText(size: 12, weight: FontWeight.w600, color: t.primary, height: 16 / 12)
        : appText(size: 12, color: t.onSurfaceVariant, height: 16 / 12, tabular: true);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(flex: flexFor(measureText(context, label, labelStyle)), child: Text(label, style: labelStyle)),
          const SizedBox(width: 8),
          Flexible(
            flex: flexFor(measureText(context, value, valueStyle)),
            child: Text(value, key: valueKey, textAlign: TextAlign.end, style: valueStyle),
          ),
        ],
      ),
    );
  }
}

/// `type="number"` text of the browser: what `e.target.value` holds. Anything that is not a valid number reads ''.
final RegExp _validNumber = RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$');

/// `Number(s)` for the strings the field can hold ('' is 0).
double _jsNumber(String s) {
  final t = s.trim();
  if (t.isEmpty) return 0;
  return _validNumber.hasMatch(t) ? jsParseFloat(t) : double.nan;
}

/// `parseFloat(value) || 0`.
double parseFloatOr0(String s) {
  final v = jsParseFloat(s);
  return (v.isNaN || v == 0) ? 0.0 : v;
}

/// `parseInt(value)` (radix 10): the leading integer, NaN when there is none.
double jsParseInt(String s) {
  final m = RegExp(r'^\s*([+-]?\d+)').firstMatch(s);
  if (m == null) return double.nan;
  return double.parse(m[1]!);
}

/// The number input of the cards: `<input type="number" value={x} onChange={e => setX(parse(e.target.value))}
/// className="w-full bg-transparent text-2xl sm:text-3xl font-light outline-none font-mono">`, with an optional
/// prefix (`text-2xl font-light`) and suffix (`text-xl font-light`).
///
/// The state is a number and the field is controlled, so after every keystroke React writes the number back unless the
/// text means the same number: clearing the field reads `0`, and `0` typed into a field that has to be at least 1 reads
/// `1`. [onChanged] gets the parsed number and the field text follows the same rule.
class FinanceNumberInput extends StatefulWidget {
  const FinanceNumberInput({
    super.key,
    required this.inputKey,
    required this.value,
    required this.parse,
    required this.onChanged,
    required this.placeholder,
    this.prefix,
    this.suffix,
    this.bottomGap = 0,
  });

  /// Key of the [TextField] (tests type into it).
  final Key inputKey;

  /// The state of the screen.
  final double value;

  /// `parseFloat(v) || 0`, with the clamp of that field, from the value the browser would report.
  final double Function(String browserValue) parse;
  final ValueChanged<double> onChanged;
  final String placeholder;
  final String? prefix;
  final String? suffix;

  /// `mb-3` under the row when chips follow.
  final double bottomGap;

  @override
  State<FinanceNumberInput> createState() => _FinanceNumberInputState();
}

class _FinanceNumberInputState extends State<FinanceNumberInput> {
  late final TextEditingController _c = TextEditingController(text: jsToString(widget.value));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FinanceNumberInput old) {
    super.didUpdateWidget(old);
    // a preset (or any other change that did not come from this field) rewrites the text
    if (widget.value != old.value && _jsNumber(_c.text) != widget.value) _setText(jsToString(widget.value));
  }

  void _setText(String s) {
    _c.value = TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }

  void _onChanged(String text) {
    final bv = _validNumber.hasMatch(text.trim()) ? text.trim() : '';
    final v = widget.parse(bv);
    if ((v == 0 && bv.isEmpty) || _jsNumber(bv) != v) _setText(jsToString(v));
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final bp = Breakpoints.of(context);
    final size = bp.sm ? 30.0 : 24.0;
    final lh = bp.sm ? 36.0 : 32.0;
    final style = appText(size: size, weight: FontWeight.w300, color: t.onSurface, height: lh / size, tabular: true);
    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.prefix != null) ...[
            Text(widget.prefix!, style: appText(size: 24, weight: FontWeight.w300, color: t.onSurfaceVariant, height: 32 / 24)),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Material(
              type: MaterialType.transparency,
              child: TextField(
                key: widget.inputKey,
                controller: _c,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9eE+\-.]'))],
                cursorColor: t.onSurface,
                style: style,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: widget.placeholder,
                  hintStyle: style.copyWith(color: t.onSurface.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),
          if (widget.suffix != null) ...[
            const SizedBox(width: 6),
            Text(widget.suffix!, style: appText(size: 20, weight: FontWeight.w300, color: t.onSurfaceVariant, height: 28 / 20)),
          ],
        ],
      ),
    );
  }
}

/// `text-xs font-mono mt-1` helper line under an input.
class MonoHelper extends StatelessWidget {
  const MonoHelper(this.text, {super.key, this.helperKey});

  final String text;
  final Key? helperKey;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text, key: helperKey, style: appText(size: 12, color: t.onSurfaceVariant, height: 16 / 12, tabular: true)),
    );
  }
}

/// `text-xs mt-1` plain helper line.
class PlainHelper extends StatelessWidget {
  const PlainHelper(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text, style: appText(size: 12, color: t.onSurfaceVariant, height: 16 / 12)),
    );
  }
}

/// A preset chip: label, whether it is the active one, tap handler.
typedef ChipSpec = ({Key key, String label, bool active, VoidCallback onTap});

/// `flex flex-wrap gap-2 pt-1 border-t` (or `pt-2.5 mt-2` after a helper line) with the preset buttons.
class PresetChips extends StatelessWidget {
  const PresetChips({super.key, required this.chips, this.afterHelper = false});

  final List<ChipSpec> chips;

  /// `pt-2.5 mt-2` (the first card of a tab, which has a helper line above) instead of `pt-1`.
  final bool afterHelper;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    return Container(
      margin: EdgeInsets.only(top: afterHelper ? 8 : 0),
      padding: EdgeInsets.only(top: afterHelper ? 10 : 4),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.outlineVariant))),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in chips)
            Pressable(
              key: c.key,
              onTap: c.onTap,
              child: AnimatedContainer(
                duration: kTailwindDuration,
                curve: kTailwindEase,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: c.active ? t.primaryContainer : t.surfaceContainer,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                child: Text(
                  c.label,
                  style: appText(
                    size: 12,
                    weight: c.active ? FontWeight.w700 : FontWeight.w500,
                    color: c.active ? t.onPrimaryContainer : t.onSurfaceVariant,
                    height: 16 / 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// `<input type="checkbox" className="w-4 h-4 rounded" style={{ accentColor }}>`: the browser's check box in the accent
/// colour (16 px; checked = filled with a white or black tick, whichever contrasts).
class FinanceCheckbox extends StatelessWidget {
  const FinanceCheckbox({super.key, required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final tick = t.primary.computeLuminance() > 0.5 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: checked ? t.primary : null,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        border: checked ? null : Border.all(color: t.outline, width: 1),
      ),
      child: checked ? Center(child: _Tick(color: tick)) : null,
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => LucideIcon(LucideIconId.check, color: color, size: 12);
}

/// A check box with its label, `flex items-center gap-2 cursor-pointer`: the whole line toggles.
class CheckLine extends StatelessWidget {
  const CheckLine({super.key, required this.checkKey, required this.checked, required this.onChanged, required this.label, this.gap = 8, this.labelStyle});

  final Key checkKey;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final String label;
  final double gap;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    return GestureDetector(
      key: checkKey,
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!checked),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FinanceCheckbox(checked: checked),
          SizedBox(width: gap),
          Flexible(child: Text(label, style: labelStyle ?? appText(size: 12, color: t.onSurface, height: 16 / 12))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------------
// Results card
// ---------------------------------------------------------------------------------------------------------------------

/// `relative rounded-3xl p-5 sm:p-6 overflow-hidden` on a surface-container role.
class ResultsCard extends StatelessWidget {
  const ResultsCard({super.key, required this.background, required this.children});

  final Color background;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final bp = Breakpoints.of(context);
    return Container(
      clipBehavior: Clip.hardEdge,
      padding: EdgeInsets.all(bp.pick(20.0, sm: 24.0)),
      decoration: BoxDecoration(color: background, borderRadius: const BorderRadius.all(Radius.circular(24))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// Caption of the headline metric: `text-[11px] font-semibold tracking-wider uppercase mb-1`.
class MetricCaption extends StatelessWidget {
  const MetricCaption(this.text, {super.key, this.captionKey});

  final String text;
  final Key? captionKey;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text.toUpperCase(),
        key: captionKey,
        style: appText(size: 11, weight: FontWeight.w600, letterSpacingEm: 0.05, color: t.onSurfaceVariant, height: 16.5 / 11),
      ),
    );
  }
}

/// One piece of the headline value row (`flex items-baseline gap-1`).
typedef HeadlinePart = ({String text, Key? key, TextStyle style, double extraGap});

/// The headline value: `text-3xl sm:text-4xl lg:text-5xl font-light tracking-tight font-mono flex items-baseline gap-1`.
/// The row never wraps; what does not fit is cut by the card (`overflow-hidden`).
class HeadlineRow extends StatelessWidget {
  const HeadlineRow({super.key, required this.parts});

  final List<HeadlinePart> parts;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            for (var i = 0; i < parts.length; i++) ...[
              if (i > 0) SizedBox(width: 4 + parts[i].extraGap),
              Text(parts[i].text, key: parts[i].key, style: parts[i].style, softWrap: false),
            ],
          ],
        ),
      ),
    );
  }
}

/// Text styles of the headline row for the current width: `big` is the number, `symbol` the `text-2xl sm:text-3xl
/// font-normal` currency sign.
({TextStyle big, TextStyle symbol}) headlineStyles(BuildContext context, M3Tokens t, {Color? bigColor}) {
  final bp = Breakpoints.of(context);
  final size = bp.pick(30.0, sm: 36.0, lg: 48.0);
  final lh = bp.pick(36.0, sm: 40.0, lg: 48.0);
  final symbolSize = bp.sm ? 30.0 : 24.0;
  final symbolLh = bp.sm ? 36.0 : 32.0;
  return (
    big: appText(size: size, weight: FontWeight.w300, letterSpacingEm: -0.025, color: bigColor ?? t.onSurface, height: lh / size, tabular: true),
    symbol: appText(size: symbolSize, weight: FontWeight.w400, letterSpacingEm: -0.025, color: t.onSurfaceVariant, height: symbolLh / symbolSize, tabular: true),
  );
}

/// The `text-sm font-normal font-sans ml-1` unit after the number ("/ month", "/ each").
TextStyle headlineUnitStyle(M3Tokens t) => appText(size: 14, weight: FontWeight.w400, color: t.onSurfaceVariant, height: 20 / 14);

/// A segment of the ratio bar.
typedef BarSegment = ({Key? key, double percent, Color color});

/// `w-full h-3 rounded-full overflow-hidden flex` with segments `transition-all duration-500`.
class RatioBar extends StatelessWidget {
  const RatioBar({super.key, required this.segments});

  final List<BarSegment> segments;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    return Container(
      height: 12,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: t.surfaceContainerHighest, borderRadius: const BorderRadius.all(Radius.circular(999))),
      child: LayoutBuilder(
        builder: (context, box) {
          var total = 0.0;
          for (final s in segments) {
            total += s.percent;
          }
          // flex-shrink: segments that add up to more than 100% shrink in proportion
          final scale = total > 100 ? 100 / total : 1.0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final s in segments)
                AnimatedContainer(
                  key: s.key,
                  duration: const Duration(milliseconds: 500),
                  curve: kTailwindEase,
                  width: box.maxWidth * s.percent * scale / 100,
                  color: s.color,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A legend entry of the ratio bar: dot colour, label, percentage text and its colour.
typedef LegendEntry = ({Color dot, String label, String value, Color valueColor, Key? valueKey});

/// `flex items-center justify-between text-xs pt-1` (with `flex-wrap gap-2` when [wrap]).
class RatioLegend extends StatelessWidget {
  const RatioLegend({super.key, required this.entries, this.wrap = false});

  final List<LegendEntry> entries;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final labelStyle = appText(size: 12, color: t.onSurfaceVariant, height: 16 / 12);
    final valueStyle = appText(size: 12, weight: FontWeight.w600, height: 16 / 12, tabular: true);

    Widget item(LegendEntry e) {
      final vs = valueStyle.copyWith(color: e.valueColor);
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: e.dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Flexible(flex: flexFor(measureText(context, e.label, labelStyle)), child: Text(e.label, style: labelStyle)),
          const SizedBox(width: 6),
          Flexible(flex: flexFor(measureText(context, e.value, vs)), child: Text(e.value, key: e.valueKey, style: vs)),
        ],
      );
    }

    double itemWidth(LegendEntry e) =>
        10 + 6 + measureText(context, e.label, labelStyle) + 6 + measureText(context, e.value, valueStyle);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: wrap
          ? Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [for (final e in entries) item(e)],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [for (final e in entries) Flexible(flex: flexFor(itemWidth(e)), child: item(e))],
            ),
    );
  }
}

/// A metric tile of the two-tile grid.
typedef TileSpec = ({
  Key? key,
  Key? valueKey,
  Color background,
  String caption,
  Color captionColor,
  String value,
  Color valueColor,
  FontWeight valueWeight,
});

/// `grid grid-cols-1 sm:grid-cols-2 gap-3 mb-5`: two `rounded-2xl p-4 flex flex-col justify-between` tiles.
class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.left, required this.right});

  final TileSpec left;
  final TileSpec right;

  @override
  Widget build(BuildContext context) {
    final bp = Breakpoints.of(context);
    Widget tile(TileSpec s) {
      final size = bp.sm ? 24.0 : 20.0;
      final lh = bp.sm ? 32.0 : 28.0;
      return Container(
        key: s.key,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: s.background, borderRadius: const BorderRadius.all(Radius.circular(16))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(s.caption, style: appText(size: 12, weight: FontWeight.w500, color: s.captionColor, height: 16 / 12)),
            ),
            Text(
              s.value,
              key: s.valueKey,
              style: appText(size: size, weight: s.valueWeight, color: s.valueColor, height: lh / size, tabular: true),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: bp.sm
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: tile(left)),
                  const SizedBox(width: 12),
                  Expanded(child: tile(right)),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [tile(left), const SizedBox(height: 12), tile(right)],
            ),
    );
  }
}

/// `text-[11px] leading-relaxed` footnote.
class Footnote extends StatelessWidget {
  const Footnote(this.text, {super.key, this.bottom = 20});

  final String text;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Text(text, style: appText(size: 11, color: t.onSurfaceVariant, height: 1.625)),
    );
  }
}

/// `Math.min(100, Math.max(0, x))` (NaN stays NaN).
double clampPct(double v) => v.isNaN ? v : (v < 0 ? 0.0 : (v > 100 ? 100.0 : v));

/// JavaScript `a || b` for numbers: `b` when `a` is 0 or NaN.
double orElse(double a, double b) => (a == 0 || a.isNaN) ? b : a;

/// `{currentTheme.isDark ? '#fcd34d' : '#b45309'}`.
Color amberNoteColor(M3Tokens t) => t.isDark ? finAmber300 : finAmberLightText;

/// `{currentTheme.isDark ? '#fbbf24' : '#b45309'}`.
Color amberCellColor(M3Tokens t) => t.isDark ? finAmberDarkText : finAmberLightText;

/// `{currentTheme.isDark ? '#34d399' : '#047857'}`.
Color emeraldColor(M3Tokens t) => t.isDark ? finEmeraldDark : finEmeraldLight;

// ---------------------------------------------------------------------------------------------------------------------
// Collapsible table
// ---------------------------------------------------------------------------------------------------------------------

/// One cell of a [FinanceTable].
typedef TableCellSpec = ({String text, Color color, FontWeight weight});

/// `pt-3 border-t` section with a `w-full flex items-center justify-between py-2 text-xs font-semibold` toggle and, when
/// open, the table (`mt-3 table-wrap no-scrollbar animate-fadeIn`).
class CollapsibleTable extends StatefulWidget {
  const CollapsibleTable({
    super.key,
    required this.toggleKey,
    required this.title,
    required this.titleColor,
    this.chevronColor,
    required this.headers,
    required this.rows,
  });

  final Key toggleKey;
  final String title;
  final Color titleColor;

  /// Chevron colour when it differs from the title (the SWP tab).
  final Color? chevronColor;
  final List<String> headers;
  final List<List<TableCellSpec>> rows;

  @override
  State<CollapsibleTable> createState() => _CollapsibleTableState();
}

class _CollapsibleTableState extends State<CollapsibleTable> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.outlineVariant))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            key: widget.toggleKey,
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(widget.title, style: appText(size: 12, weight: FontWeight.w600, color: widget.titleColor, height: 16 / 12)),
                  ),
                  const SizedBox(width: 8),
                  LucideIcon(_open ? LucideIconId.chevronUp : LucideIconId.chevronDown, color: widget.chevronColor ?? widget.titleColor, size: 16),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FadeIn(child: FinanceTable(headers: widget.headers, rows: widget.rows)),
            ),
        ],
      ),
    );
  }
}

/// `animate-fadeIn`: `m3FadeIn` 200 ms, `cubic-bezier(0.05, 0.7, 0.1, 1)`, from `opacity: 0; translateY(4px)`.
class FadeIn extends StatelessWidget {
  const FadeIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      curve: const Cubic(0.05, 0.7, 0.1, 1),
      builder: (context, p, child) => Opacity(
        opacity: p,
        child: Transform.translate(offset: Offset(0, 4 * (1 - p)), child: child),
      ),
      child: child,
    );
  }
}

/// The schedule table: `table w-full text-left text-[11.5px] sm:text-xs font-mono` with `py-2 px-1.5 sm:px-2.5` cells, a
/// bottom border under the header and `divide-y` between rows; the last column is right-aligned. Columns share the
/// width in proportion to their content (CSS `table-layout: auto`) and the table scrolls sideways when the content is
/// wider than the card (`table-wrap`).
class FinanceTable extends StatelessWidget {
  const FinanceTable({super.key, required this.headers, required this.rows});

  final List<String> headers;
  final List<List<TableCellSpec>> rows;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final bp = Breakpoints.of(context);
    // `text-[11.5px]` has no line height of its own and inherits the page's 1.5; `sm:text-xs` is 12 / 16.
    final size = bp.sm ? 12.0 : 11.5;
    final lh = bp.sm ? 16.0 : 17.25;
    final padX = bp.sm ? 10.0 : 6.0;
    final cols = headers.length;

    TextStyle style(FontWeight w, Color c) => appText(size: size, weight: w, color: c, height: lh / size, tabular: true);
    final headStyle = style(FontWeight.w600, t.onSurfaceVariant);

    final natural = List<double>.filled(cols, 0);
    for (var i = 0; i < cols; i++) {
      natural[i] = measureText(context, headers[i], headStyle) + 2 * padX;
      for (final r in rows) {
        final w = measureText(context, r[i].text, style(r[i].weight, r[i].color)) + 2 * padX;
        if (w > natural[i]) natural[i] = w;
      }
    }
    var total = 0.0;
    for (final w in natural) {
      total += w;
    }

    Widget cell(double width, String text, TextStyle s, bool right) => SizedBox(
          width: width,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padX, vertical: 8),
            child: Text(text, style: s, textAlign: right ? TextAlign.end : TextAlign.start, maxLines: 1, softWrap: false, overflow: TextOverflow.visible),
          ),
        );

    return LayoutBuilder(
      builder: (context, box) {
        final tableWidth = box.maxWidth > total ? box.maxWidth : total;
        final extra = tableWidth - total;
        final widths = [for (final w in natural) w + (total > 0 ? extra * w / total : 0)];

        final header = Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.outlineVariant))),
          child: Row(children: [for (var i = 0; i < cols; i++) cell(widths[i], headers[i], headStyle, i == cols - 1)]),
        );
        final body = <Widget>[
          for (var r = 0; r < rows.length; r++)
            Container(
              decoration: BoxDecoration(border: r == 0 ? null : Border(top: BorderSide(color: t.outlineVariant))),
              child: Row(
                children: [
                  for (var i = 0; i < cols; i++) cell(widths[i], rows[r][i].text, style(rows[r][i].weight, rows[r][i].color), i == cols - 1),
                ],
              ),
            ),
        ];
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: SizedBox(
            width: tableWidth,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, ...body]),
          ),
        );
      },
    );
  }
}
