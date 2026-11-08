import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../engine/casio/config.dart';
import '../../engine/types.dart';
import '../../services/feedback_service.dart';
import '../../services/link_service.dart';
import '../../state/app_settings.dart';
import '../../state/casio_settings.dart';
import '../../state/navigation_state.dart';
import '../../state/settings_store.dart';
import '../../theme/glass.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../calculator/calc_style.dart';
import '../icons/lucide_icon.dart';
import '../icons/nav_icon.dart';
import '../icons/omnicalc_logo.dart';
import '../icons/svg_paths_generated.dart';
import '../widgets/m3_sheet.dart';
import '../widgets/pressable.dart';
import 'history_tape_sheet.dart' show pillRadiusAll;

/// `src/version.ts`.
const String kAppVersion = '1.1.0';
const String kRepoUrl = 'https://github.com/adssaketh/OmniCalc';
const String kRepoLabel = 'github.com/adssaketh/OmniCalc';

/// The web app opens `/privacy-policy.html` of its own bundle. The Flutter app has no such page, so the link goes to
/// the same policy in the repository (see PHASE5_NOTES.md).
const String kPrivacyPolicyUrl = 'https://github.com/adssaketh/OmniCalc/blob/main/PRIVACY.md';

/// `ActiveSheet` of SettingsModal.tsx.
enum SettingsSubSheet {
  none,
  complexFormat,
  statFreq,
  tableFormat,
  theme,
  colorMode,
  angleMode,
  precision,
  vibration,
  privacy,
  resetConfirm,
  calcStyle,
  percentStyle,
  resultDisplay,
  numberFormat,
  fractionFormat,
  decimalPoint,
  contrast
}

/// `ThemeOption`.
class ThemeOption {
  const ThemeOption(this.id, this.name, this.desc, this.primary, this.container, {this.isDynamic = false});

  final String id;
  final String name;
  final String desc;

  /// The swatch: one colour, or (dynamic) a 135 degree gradient.
  final int primary;
  final int container;
  final bool isDynamic;
}

const List<ThemeOption> kThemeOptions = [
  ThemeOption(ThemeIds.dynamic, 'Dynamic (system colours)', 'Matches wallpaper & Android 12+ Monet palette', 0xFFA8C7FA, 0xFF264585,
      isDynamic: true),
  ThemeOption(ThemeIds.iris, 'Expressive Iris', 'Android Flagship Monet Blue', 0xFFA8C7FA, 0xFF264585),
  ThemeOption(ThemeIds.ocean, 'Dynamic Oceanic', 'Teal & Deep Marine Blue', 0xFF7BD0FF, 0xFF004D67),
  ThemeOption(ThemeIds.forest, 'Botanical Sage', 'Forest & Mint Flora', 0xFF9CD67D, 0xFF23520E),
  ThemeOption(ThemeIds.sunset, 'Sunset Terracotta', 'Warm Coral & Amber Flame', 0xFFFFB59D, 0xFF72351F),
  ThemeOption(ThemeIds.amoled, 'AMOLED / Pure Contrast', 'High Contrast Monochrome & Deep Black', 0xFFC2C1FF, 0xFF141220),
  ThemeOption(ThemeIds.darkObsidian, 'Dark Obsidian', 'Deep Slate & Iris Accent', 0xFFA8C7FA, 0xFF1D2024),
  ThemeOption(ThemeIds.cyberEmerald, 'Cyber Emerald', 'Luminous Emerald & Night Jade', 0xFF00FF9D, 0xFF003822),
];

/// `THEME_OPTIONS.find(...) || THEME_OPTIONS[1]`.
ThemeOption themeOptionFor(String id) => kThemeOptions.firstWhere((o) => o.id == id, orElse: () => kThemeOptions[1]);

String colorModeLabel(ColorMode m) => switch (m) {
      ColorMode.system => 'System default (auto)',
      ColorMode.light => 'Light mode',
      ColorMode.dark => 'Dark mode',
    };

String precisionLabel(int p) => p == -1 ? 'Auto (Full precision)' : '$p decimal places';

/// `handleResetSettings`: every field the TS resets (the currency pair is left alone).
AppSettings resetSettings(AppSettings s) => s.copyWith(
      soundEnabled: true,
      hapticEnabled: true,
      vibrationIntensity: VibrationIntensity.medium,
      angleMode: AngleMode.deg,
      decimalPrecision: -1,
      theme: ThemeIds.dynamic,
      colorMode: ColorMode.system,
      enableGrapher: false,
      enablePhysics: false,
      enableChemistry: false,
      edgeEffect: EdgeEffect.fade,
      fadeHeight: FadeHeight.medium,
      barStyle: BarStyle.solid,
      glassTransparency: 70,
      glassBlur: GlassBlur.medium,
      glassEdge: true,
    );

// ---------------------------------------------------------------------------------------------------------------------
// Building blocks
// ---------------------------------------------------------------------------------------------------------------------

/// CSS `linear-gradient(<angle>deg, ...)` on a box of any shape: the gradient line is as long as the box needs.
ui.Shader cssGradientShader(Rect r, double angleDeg, List<Color> colors, List<double> stops) {
  final a = angleDeg * math.pi / 180;
  final dx = math.sin(a);
  final dy = -math.cos(a);
  final len = (r.width * math.sin(a)).abs() + (r.height * math.cos(a)).abs();
  final c = r.center;
  return ui.Gradient.linear(
    Offset(c.dx - dx * len / 2, c.dy - dy * len / 2),
    Offset(c.dx + dx * len / 2, c.dy + dy * len / 2),
    colors,
    stops,
  );
}

class _GradientPainter extends CustomPainter {
  const _GradientPainter(this.angle, this.colors, this.stops);

  final double angle;
  final List<Color> colors;
  final List<double> stops;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..shader = cssGradientShader(Offset.zero & size, angle, colors, stops));
  }

  @override
  bool shouldRepaint(_GradientPainter old) => old.angle != angle || old.colors != colors;
}

/// The swatch of a theme option: its colour, or the dynamic 135 degree gradient.
class _Swatch extends StatelessWidget {
  const _Swatch({super.key, required this.option, required this.size, this.child});

  final ThemeOption option;
  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: option.isDynamic ? null : BoxDecoration(color: Color(option.primary), shape: BoxShape.circle),
      child: option.isDynamic
          ? ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const CustomPaint(
                    painter: _GradientPainter(
                      135,
                      [Color(0xFFA8C7FA), Color(0xFF7BD0FF), Color(0xFFB0C6FF)],
                      [0, 0.5, 1],
                    ),
                  ),
                  if (child != null) Center(child: child),
                ],
              ),
            )
          : child,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            title.toUpperCase(),
            style: calcText(size: 12, weight: FontWeight.w700, color: t.primary, lineHeight: 16, letterSpacingEm: 0.05),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(color: t.surfaceContainer, borderRadius: const BorderRadius.all(Radius.circular(28))),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, c) in children.indexed) ...[
                  if (i > 0) const SizedBox(height: 2),
                  c,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// `Row` of SettingsModal.tsx.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.onTap,
    this.trailing,
    this.chevron = false,
    this.dimmed = false,
    this.leading,
  });

  /// Leading icon; null leaves an empty spacer so the text lines up with the rows above.
  final LucideIconId? icon;
  final String title;
  final String? subtitle;

  /// A subtitle that is not plain text (the theme row's sparkle).
  final Widget? subtitleWidget;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool chevron;
  final bool dimmed;

  /// Replaces the icon tile (the app logo, the guide and GitHub tiles).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            leading ??
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: icon == null
                      ? null
                      : BoxDecoration(color: t.surfaceContainerHigh, borderRadius: const BorderRadius.all(Radius.circular(16))),
                  child: icon == null ? null : LucideIcon(icon!, color: t.primary, size: 20),
                ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: calcText(size: 14, weight: FontWeight.w500, color: t.onSurface, lineHeight: 19.25)),
                  if (subtitleWidget != null)
                    subtitleWidget!
                  else if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: calcText(size: 12, weight: FontWeight.w400, color: t.onSurfaceVariant, lineHeight: 16),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 16), trailing!],
            if (chevron) ...[
              const SizedBox(width: 16),
              LucideIcon(LucideIconId.chevronRight, color: t.onSurfaceVariant, size: 20),
            ],
          ],
        ),
      ),
    );
    if (dimmed) row = Opacity(opacity: 0.6, child: row);
    if (onTap == null) return row;
    // `active:scale-[0.985]` with `transition-colors` only: the scale is not part of the transition
    return Pressable(
      onTap: onTap,
      pressedScale: 0.985,
      animated: false,
      child: Semantics(button: true, label: title, excludeSemantics: true, child: row),
    );
  }
}

/// The Material 3 switch of the web app: 52 x 28 track, 20 px knob that slides 24 px, a check on the knob when on.
class M3Switch extends StatelessWidget {
  const M3Switch({super.key, required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final instant = reduceMotion(context);
    final d = instant ? Duration.zero : const Duration(milliseconds: 200);
    return AnimatedContainer(
      duration: d,
      curve: kTailwindEase,
      width: 52,
      height: 28,
      padding: const EdgeInsets.all(4),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(color: on ? t.primary : t.surfaceContainerHighest, borderRadius: pillRadiusAll),
      child: AnimatedSlide(
        duration: d,
        curve: kTailwindEase,
        offset: Offset(on ? 24 / 20 : 0, 0),
        child: Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: on ? t.onPrimary : t.outline, shape: BoxShape.circle),
          child: on ? LucideIcon(LucideIconId.check, color: t.primary, size: 12) : null,
        ),
      ),
    );
  }
}

/// `Segmented`: a row of pill choices.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.label,
    this.disabled = false,
  });

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String label;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final d = reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 200);
    return Semantics(
      label: label,
      container: true,
      child: IgnorePointer(
        ignoring: disabled,
        child: AnimatedOpacity(
          duration: d,
          opacity: disabled ? 0.45 : 1,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (id, text) in options)
                Pressable(
                  key: ValueKey('seg-$label-$text'),
                  onTap: () => onChanged(id),
                  child: Semantics(
                    inMutuallyExclusiveGroup: true,
                    checked: id == value,
                    label: text,
                    excludeSemantics: true,
                    child: AnimatedContainer(
                      duration: d,
                      curve: kTailwindEase,
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: id == value ? t.primaryContainer : t.surfaceContainerHigh,
                        borderRadius: pillRadiusAll,
                      ),
                      child: Text(
                        text,
                        style: calcText(
                          size: 13,
                          weight: id == value ? FontWeight.w700 : FontWeight.w500,
                          color: id == value ? t.onPrimaryContainer : t.onSurfaceVariant,
                          lineHeight: 19.5,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `OptionBlock`.
class _OptionBlock extends StatelessWidget {
  const _OptionBlock({required this.title, required this.desc, required this.child, this.dimmed = false});

  final String title;
  final String desc;
  final bool dimmed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final d = reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 200);
    return AnimatedOpacity(
      duration: d,
      opacity: dimmed ? 0.45 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: calcText(size: 14, weight: FontWeight.w500, color: t.onSurface, lineHeight: 19.25)),
          Text(desc, style: calcText(size: 12, weight: FontWeight.w400, color: t.onSurfaceVariant, lineHeight: 16.5)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// The preview of the bars: colourful content behind a top and a bottom bar, drawn with the real bar styles.
class _BarPreview extends StatelessWidget {
  const _BarPreview();

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    Widget bar(String text) => BarSurface(
          borderRadius: pillRadiusAll,
          child: Container(
            height: 40,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(text, style: calcText(size: 12, weight: FontWeight.w600, color: t.onSurface, lineHeight: 16)),
          ),
        );
    return ExcludeSemantics(
      child: SizedBox(
        key: const ValueKey('bar-preview'),
        height: 128,
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _GradientPainter(
                        115,
                        [t.primary, t.tertiary, t.secondary, t.primaryContainer],
                        const [0, 0.38, 0.62, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: -16,
                    top: 32,
                    width: 96,
                    height: 96,
                    child: DecoratedBox(decoration: BoxDecoration(color: t.tertiaryContainer, shape: BoxShape.circle)),
                  ),
                  Positioned(
                    right: 24,
                    top: 12,
                    width: 80,
                    height: 80,
                    child: Transform.rotate(
                      angle: 12 * math.pi / 180,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: t.primaryContainer, borderRadius: const BorderRadius.all(Radius.circular(28))),
                      ),
                    ),
                  ),
                  Positioned(
                    left: w / 3,
                    bottom: 4,
                    width: 112,
                    height: 56,
                    child: DecoratedBox(decoration: BoxDecoration(color: t.secondaryContainer, borderRadius: pillRadiusAll)),
                  ),
                  Positioned(left: 12, right: 12, top: 12, child: bar('Top bar')),
                  Positioned(left: 12, right: 12, bottom: 12, child: bar('Bottom bar')),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// `.m3-slider`: 28 px tall hit area, 10 px track filled up to the value, 26 px thumb. 0 to 100 in steps of 1.
class M3Slider extends StatefulWidget {
  const M3Slider({super.key, required this.value, required this.onChanged, required this.label});

  final int value;
  final ValueChanged<int> onChanged;
  final String label;

  @override
  State<M3Slider> createState() => _M3SliderState();
}

class _M3SliderState extends State<M3Slider> {
  bool _active = false;

  int _valueAt(double x, double width) {
    final usable = math.max(1.0, width - 26);
    return (((x - 13) / usable) * 100).round().clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    return Semantics(
      slider: true,
      label: widget.label,
      value: '${widget.value}',
      increasedValue: '${math.min(100, widget.value + 1)}',
      decreasedValue: '${math.max(0, widget.value - 1)}',
      onIncrease: () => widget.onChanged(math.min(100, widget.value + 1)),
      onDecrease: () => widget.onChanged(math.max(0, widget.value - 1)),
      child: LayoutBuilder(
        builder: (context, c) {
          final width = c.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              setState(() => _active = true);
              widget.onChanged(_valueAt(d.localPosition.dx, width));
            },
            onTapUp: (_) => setState(() => _active = false),
            onTapCancel: () => setState(() => _active = false),
            onHorizontalDragStart: (d) => setState(() => _active = true),
            onHorizontalDragUpdate: (d) => widget.onChanged(_valueAt(d.localPosition.dx, width)),
            onHorizontalDragEnd: (_) => setState(() => _active = false),
            onHorizontalDragCancel: () => setState(() => _active = false),
            child: SizedBox(
              height: 28,
              width: double.infinity,
              child: CustomPaint(
                painter: _SliderPainter(
                  pct: widget.value / 100,
                  fill: t.primary,
                  track: t.surfaceContainerHighest,
                  thumbScale: _active ? 1.15 : 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SliderPainter extends CustomPainter {
  const _SliderPainter({required this.pct, required this.fill, required this.track, required this.thumbScale});

  final double pct;
  final Color fill;
  final Color track;
  final double thumbScale;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final trackRect = RRect.fromRectAndRadius(Rect.fromLTWH(0, cy - 5, size.width, 10), const Radius.circular(9999));
    canvas.drawRRect(trackRect, Paint()..color = track);
    canvas.save();
    canvas.clipRRect(trackRect);
    // `linear-gradient(to right, fill pct%, track pct%)`: a hard edge at pct of the track width
    canvas.drawRect(Rect.fromLTWH(0, cy - 5, size.width * pct, 10), Paint()..color = fill);
    canvas.restore();
    final cx = 13 + (size.width - 26) * pct;
    final r = 13 * thumbScale;
    canvas.drawCircle(
      Offset(cx, cy + 1),
      r,
      Paint()
        ..color = const Color(0x59000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = fill);
  }

  @override
  bool shouldRepaint(_SliderPainter old) =>
      old.pct != pct || old.fill != fill || old.track != track || old.thumbScale != thumbScale;
}

/// One choice of a [_ChoiceSheet].
class _ChoiceOption<T> {
  const _ChoiceOption(this.id, this.title, this.desc, {this.leading, this.extra});

  final T id;
  final String title;
  final String desc;
  final Widget? leading;

  /// Control shown before the radio (the vibration "Test" button).
  final Widget? extra;
}

/// `ChoiceSheet`: a single-choice bottom sheet with radio rows.
class _ChoiceSheet<T> extends StatelessWidget {
  const _ChoiceSheet({
    required this.isOpen,
    required this.title,
    required this.description,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.onClose,
    this.closeLabel = 'Cancel',
  });

  final bool isOpen;
  final String title;
  final String description;
  final List<_ChoiceOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelect;
  final VoidCallback onClose;
  final String closeLabel;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    return M3Sheet(
      isOpen: isOpen,
      onClose: onClose,
      label: title,
      maxWidth: 448,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: calcText(size: 18, weight: FontWeight.w700, color: t.onSurface, lineHeight: 28)),
              const SizedBox(height: 2),
              Text(description, style: calcText(size: 12, weight: FontWeight.w400, color: t.onSurfaceVariant, lineHeight: 16)),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, opt) in options.indexed) ...[
                  if (i > 0) const SizedBox(height: 4),
                  _ChoiceRow<T>(option: opt, selected: selected == opt.id, onTap: () => onSelect(opt.id)),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Align(
            alignment: Alignment.centerRight,
            child: Pressable(
              key: const ValueKey('choice-close'),
              onTap: onClose,
              child: Semantics(
                button: true,
                label: closeLabel,
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(closeLabel, style: calcText(size: 12, weight: FontWeight.w600, color: t.primary, lineHeight: 16)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({required this.option, required this.selected, required this.onTap});

  final _ChoiceOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final fg = selected ? t.onPrimaryContainer : t.onSurface;
    return Pressable(
      key: ValueKey('choice-${option.id}'),
      onTap: onTap,
      pressedScale: 0.985,
      animated: false,
      child: Semantics(
        button: true,
        selected: selected,
        label: option.title,
        excludeSemantics: true,
        child: AnimatedContainer(
          duration: reduceMotion(context) ? Duration.zero : kTailwindDuration,
          curve: kTailwindEase,
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? t.primaryContainer : const Color(0x00000000),
            borderRadius: const BorderRadius.all(Radius.circular(24)),
          ),
          child: Row(
            children: [
              if (option.leading != null) ...[option.leading!, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.title, style: calcText(size: 14, weight: FontWeight.w500, color: fg, lineHeight: 19.25)),
                    Opacity(
                      opacity: 0.75,
                      child: Text(
                        option.desc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: calcText(size: 11, weight: FontWeight.w400, color: fg, lineHeight: 16.5),
                      ),
                    ),
                  ],
                ),
              ),
              if (option.extra != null) ...[const SizedBox(width: 14), option.extra!],
              const SizedBox(width: 14),
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? t.primary : null,
                  border: Border.all(color: selected ? t.primary : t.outline, width: 2),
                ),
                child: selected
                    ? DecoratedBox(
                        decoration: BoxDecoration(color: t.onPrimary, shape: BoxShape.circle),
                        child: const SizedBox(width: 8, height: 8),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------------
// The Settings sheet
// ---------------------------------------------------------------------------------------------------------------------

/// Port of `SettingsModal.tsx`: the Settings sheet and the sheets it opens (theme, colour mode, angle unit, precision,
/// vibration strength, privacy, reset). Pressing back closes an open sub-sheet first ([NavigationState.innerBack]).
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  // The web component stays mounted while closed, so these survive closing and re-opening Settings.
  SettingsSubSheet _active = SettingsSubSheet.none;
  bool _showResetToast = false;
  Timer? _toastTimer;
  NavigationState? _nav;
  late final bool Function() _innerBack = _closeSubSheetFromBack;

  bool _closeSubSheetFromBack() {
    if (_active == SettingsSubSheet.none) return false;
    setState(() => _active = SettingsSubSheet.none);
    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _nav = context.read<NavigationState>();
    _nav!.innerBack = _innerBack;
  }

  @override
  void initState() {
    super.initState();
    CasioRuntime.instance.addListener(_casioChanged);
  }

  void _casioChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    CasioRuntime.instance.removeListener(_casioChanged);
    _toastTimer?.cancel();
    if (_nav?.innerBack == _innerBack) _nav!.innerBack = null;
    super.dispose();
  }

  void _closeSub() => setState(() => _active = SettingsSubSheet.none);

  void _openSub(SettingsSubSheet s) => setState(() => _active = s);

  void _reset(SettingsStore store) {
    store.update(resetSettings);
    CasioRuntime.instance.reset();
    setState(() {
      _active = SettingsSubSheet.none;
      _showResetToast = true;
    });
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 3000), () {
      if (mounted) setState(() => _showResetToast = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final nav = context.watch<NavigationState>();
    final store = context.watch<SettingsStore>();
    final feedback = context.read<FeedbackService>();
    final links = context.read<LinkService>();
    final s = store.settings;
    final cs = CasioRuntime.instance.settings;
    final isOpen = nav.isSettingsOpen;
    final sm = MediaQuery.sizeOf(context).width >= 640;
    final px = sm ? 20.0 : 16.0;
    final theme = themeOptionFor(s.theme);
    final vibration = s.vibrationIntensity.name;

    void update(AppSettings Function(AppSettings) change) => store.update(change);

    void pickTheme(String id) {
      update((c) => c.copyWith(theme: id));
      store.markThemeUserSet();
    }

    final modeIcon = switch (s.colorMode) {
      ColorMode.light => LucideIconId.sun,
      ColorMode.dark => LucideIconId.moon,
      ColorMode.system => LucideIconId.laptop,
    };

    final tileDecoration = BoxDecoration(color: t.surfaceContainerHigh, borderRadius: const BorderRadius.all(Radius.circular(16)));

    return Stack(
      children: [
        M3Sheet(
          isOpen: isOpen,
          onClose: () => nav.setSettingsOpen(false),
          label: 'Settings',
          maxWidth: 672,
          fixedHeight: true,
          children: [
            // top bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: px, vertical: 12),
              child: Row(
                children: [
                  Pressable(
                    key: const ValueKey('settings-back'),
                    onTap: () => nav.setSettingsOpen(false),
                    pressedScale: 0.9,
                    child: Semantics(
                      button: true,
                      label: 'Back to calculator',
                      excludeSemantics: true,
                      child: SizedBox(width: 44, height: 44, child: Center(child: LucideIcon(LucideIconId.arrowLeft, color: t.onSurface, size: 20))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Settings',
                      style: calcText(size: 20, weight: FontWeight.w700, color: t.onSurface, lineHeight: 28, letterSpacingEm: -0.025)),
                ],
              ),
            ),
            // content
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('settings-scroll'),
                padding: EdgeInsets.fromLTRB(px, 0, px, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_showResetToast) ...[
                      Container(
                        key: const ValueKey('reset-toast'),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: t.primaryContainer, borderRadius: const BorderRadius.all(Radius.circular(24))),
                        child: Row(
                          children: [
                            LucideIcon(LucideIconId.check, color: t.primary, size: 16),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('Settings restored to factory defaults',
                                  style: calcText(size: 12, weight: FontWeight.w600, color: t.onPrimaryContainer, lineHeight: 16)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    _Section(title: 'Appearance', children: [
                      _SettingsRow(
                        key: const ValueKey('row-theme'),
                        icon: LucideIconId.palette,
                        title: 'Theme',
                        chevron: true,
                        onTap: () => _openSub(SettingsSubSheet.theme),
                        subtitleWidget: Row(
                          children: [
                            if (s.theme == ThemeIds.dynamic) ...[
                              LucideIcon(LucideIconId.sparkles, color: t.primary, size: 12),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(theme.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: calcText(size: 12, weight: FontWeight.w400, color: t.onSurfaceVariant, lineHeight: 16)),
                            ),
                          ],
                        ),
                        trailing: _Swatch(key: const ValueKey('theme-swatch'), option: theme, size: 24),
                      ),
                      _SettingsRow(
                        key: const ValueKey('row-color-mode'),
                        icon: modeIcon,
                        title: 'Colour mode',
                        subtitle: colorModeLabel(s.colorMode),
                        chevron: true,
                        onTap: () => _openSub(SettingsSubSheet.colorMode),
                      ),
                      _SettingsRow(
                        key: const ValueKey('row-amoled'),
                        icon: LucideIconId.moon,
                        title: 'Pure black (AMOLED)',
                        subtitle: 'Pitch black surfaces to save battery on OLED screens',
                        trailing: M3Switch(key: const ValueKey('switch-amoled'), on: s.theme == ThemeIds.amoled),
                        onTap: () {
                          // Record that the user picked a theme so the dynamic-colour auto-default never overrides it
                          store.markThemeUserSet();
                          if (s.theme == ThemeIds.amoled) {
                            update((c) => c.copyWith(theme: ThemeIds.dynamic));
                          } else {
                            update((c) => c.copyWith(theme: ThemeIds.amoled, colorMode: ColorMode.dark));
                          }
                        },
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _Section(title: 'Bars & scrolling', children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _BarPreview(),
                            const SizedBox(height: 20),
                            _OptionBlock(
                              title: 'Scroll edge effect',
                              desc:
                                  'What happens to content as it slides under the top bar and the bottom bar. Fade is clean and light; Fade + blur adds a soft blur while it fades.',
                              child: _Segmented<EdgeEffect>(
                                label: 'Scroll edge effect',
                                options: const [(EdgeEffect.off, 'Off'), (EdgeEffect.fade, 'Fade'), (EdgeEffect.blur, 'Fade + blur')],
                                value: s.edgeEffect,
                                onChanged: (v) => update((c) => c.copyWith(edgeEffect: v)),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _OptionBlock(
                              title: 'Fade height',
                              desc: 'How far from the bars content starts to fade away.',
                              dimmed: s.edgeEffect == EdgeEffect.off,
                              child: _Segmented<FadeHeight>(
                                label: 'Fade height',
                                options: const [(FadeHeight.short, 'Short'), (FadeHeight.medium, 'Medium'), (FadeHeight.tall, 'Tall')],
                                value: s.fadeHeight,
                                disabled: s.edgeEffect == EdgeEffect.off,
                                onChanged: (v) => update((c) => c.copyWith(fadeHeight: v)),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _OptionBlock(
                              title: 'Bar style',
                              desc: 'Solid colour, or frosted glass that lets content show through (uses a little more battery).',
                              child: _Segmented<BarStyle>(
                                label: 'Bar style',
                                options: const [(BarStyle.solid, 'Solid'), (BarStyle.glass, 'Glass')],
                                value: s.barStyle,
                                onChanged: (v) => update((c) => c.copyWith(barStyle: v)),
                              ),
                            ),
                            SpringReveal(
                              show: s.barStyle == BarStyle.glass,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 20),
                                child: Container(
                                  key: const ValueKey('glass-options'),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: t.surfaceContainerHigh,
                                    borderRadius: const BorderRadius.all(Radius.circular(24)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Glass transparency',
                                              style: calcText(size: 14, weight: FontWeight.w500, color: t.onSurface, lineHeight: 20)),
                                          Text('${s.glassTransparency}%',
                                              key: const ValueKey('glass-transparency-value'),
                                              style: calcText(size: 14, weight: FontWeight.w700, color: t.primary, lineHeight: 20)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      M3Slider(
                                        key: const ValueKey('glass-transparency'),
                                        label: 'Glass transparency',
                                        value: s.glassTransparency,
                                        onChanged: (v) => update((c) => c.copyWith(glassTransparency: v)),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Frosted', style: calcText(size: 11, weight: FontWeight.w400, color: t.onSurfaceVariant, lineHeight: 16.5)),
                                          Text('Clear', style: calcText(size: 11, weight: FontWeight.w400, color: t.onSurfaceVariant, lineHeight: 16.5)),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      _OptionBlock(
                                        title: 'Glass blur',
                                        desc: 'How strongly the glass blurs what is behind it.',
                                        child: _Segmented<GlassBlur>(
                                          label: 'Glass blur',
                                          options: const [(GlassBlur.soft, 'Soft'), (GlassBlur.medium, 'Medium'), (GlassBlur.strong, 'Strong')],
                                          value: s.glassBlur,
                                          onChanged: (v) => update((c) => c.copyWith(glassBlur: v)),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Pressable(
                                        key: const ValueKey('glass-edge'),
                                        onTap: () => update((c) => c.copyWith(glassEdge: !c.glassEdge)),
                                        pressedScale: 0.99,
                                        child: Semantics(
                                          toggled: s.glassEdge,
                                          label: 'Glass edge',
                                          excludeSemantics: true,
                                          onTap: () => update((c) => c.copyWith(glassEdge: !c.glassEdge)),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Glass edge',
                                                        style: calcText(size: 14, weight: FontWeight.w500, color: t.onSurface, lineHeight: 19.25)),
                                                    Text('A thin light rim around the bars.',
                                                        style: calcText(size: 12, weight: FontWeight.w400, color: t.onSurfaceVariant, lineHeight: 16)),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              M3Switch(key: const ValueKey('switch-glass-edge'), on: s.glassEdge),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _Section(title: 'Calculator', children: [
                      _SettingsRow(
                        key: const ValueKey('row-angle'),
                        icon: LucideIconId.compass,
                        title: 'Angle unit',
                        subtitle: s.angleMode == AngleMode.deg ? 'Degrees (DEG)' : 'Radians (RAD)',
                        chevron: true,
                        onTap: () => _openSub(SettingsSubSheet.angleMode),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(color: t.primaryContainer, borderRadius: pillRadiusAll),
                          child: Text(
                            s.angleMode.id.toUpperCase(),
                            style: calcText(size: 12, weight: FontWeight.w700, color: t.onPrimaryContainer, lineHeight: 16, mono: true),
                          ),
                        ),
                      ),
                      _SettingsRow(
                        key: const ValueKey('row-precision'),
                        icon: LucideIconId.hash,
                        title: 'Decimal precision',
                        subtitle: precisionLabel(s.decimalPrecision),
                        chevron: true,
                        onTap: () => _openSub(SettingsSubSheet.precision),
                      ),
                      _SettingsRow(
                        key: const ValueKey('row-calc-style'),
                        icon: LucideIconId.calculator,
                        title: 'Calculation style',
                        subtitle: cs.useCasio ? 'Casio (default)' : 'OmniCalc (legacy)',
                        chevron: true,
                        onTap: () => _openSub(SettingsSubSheet.calcStyle),
                      ),
                      _SettingsRow(
                        key: const ValueKey('row-percent-style'),
                        icon: LucideIconId.hash,
                        title: 'Percent style',
                        subtitle: cs.phonePercent ? 'OmniCalc (default)' : 'Casio postfix',
                        chevron: true,
                        onTap: () => _openSub(SettingsSubSheet.percentStyle),
                      ),
                      _SettingsRow(
                        key: const ValueKey('row-result-display'),
                        icon: LucideIconId.hash,
                        title: 'Result display',
                        subtitle: cs.decimalFirst ? 'Decimal first (LineIO)' : 'Math (fractions, √ and π)',
                        chevron: true,
                        onTap: () => _openSub(SettingsSubSheet.resultDisplay),
                      ),
                      _SettingsRow(
                        key: const ValueKey('row-number-format'),
                        icon: LucideIconId.hash,
                        title: 'Number format',
                        subtitle: casioNumberFormatLabel(cs),
                        chevron: true,
                        onTap: () => _openSub(SettingsSubSheet.numberFormat),
                      ),
                      _SettingsRow(
                        key: const ValueKey('row-fraction-format'),
                        icon: LucideIconId.hash,
                        title: 'Fraction format',
                        subtitle: cs.mixedFractions ? 'Mixed (a b/c)' : 'Improper (d/c)',
                        chevron: true,
                        onTap: () => _openSub(SettingsSubSheet.fractionFormat),
                      ),
                      _SettingsRow(
                        key: const ValueKey('row-rdec'),
                        icon: LucideIconId.hash,
                        title: 'Recurring decimals (Rdec)',
                        subtitle: 'S⇔D can show 1÷7 as 0.142857 with a bar over the period',
                        trailing: M3Switch(key: const ValueKey('switch-rdec'), on: cs.recurring),
                        onTap: () => CasioRuntime.instance.update((c) => c.copyWith(recurring: !c.recurring)),
                      ),
                      _SettingsRow(
                        key: const ValueKey('row-disp'),
                        icon: LucideIconId.hash,
                        title: 'Decimal point (Disp)',
                        subtitle: cs.commaDecimal ? 'Comma in results (1,5)' : 'Dot in results (1.5)',
                        chevron: true,
                        onTap: () => _openSub(SettingsSubSheet.decimalPoint),
                      ),
                      _SettingsRow(
                        key: const ValueKey('row-contrast'),
                        icon: LucideIconId.hash,
                        title: 'Display contrast (CONT)',
                        subtitle: casioContrastLabel(cs.contrast),
                        chevron: true,
                        onTap: () => _openSub(SettingsSubSheet.contrast),
                      ),
                      _SettingsRow(
                        key: const ValueKey('row-complex-format'),
                        icon: LucideIconId.hash,
                        title: 'Complex format',
                        subtitle: cs.complexPolar ? 'Polar (r∠θ)' : 'Rectangular (a+bi)',
                        chevron: true,
                        onTap: () => _openSub(SettingsSubSheet.complexFormat),
                      ),
                      _SettingsRow(
                        key: const ValueKey('row-stat-freq'),
                        icon: LucideIconId.hash,
                        title: 'STAT frequency column',
                        subtitle: cs.statFreq ? 'On (FREQ)' : 'Off',
                        chevron: true,
                        onTap: () => _openSub(SettingsSubSheet.statFreq),
                      ),
                      _SettingsRow(
                        key: const ValueKey('row-table-format'),
                        icon: LucideIconId.hash,
                        title: 'TABLE format',
                        subtitle: cs.tableFg ? 'f(x), g(x)' : 'f(x)',
                        chevron: true,
                        onTap: () => _openSub(SettingsSubSheet.tableFormat),
                      ),
                      _SettingsRow(
                        key: const ValueKey('row-gra'),
                        icon: LucideIconId.compass,
                        title: 'Gradians (GRA)',
                        subtitle: 'Angle unit with 400 grads in a full circle; overrides DEG and RAD',
                        trailing: M3Switch(key: const ValueKey('switch-gra'), on: cs.gradians),
                        onTap: () => CasioRuntime.instance.update((c) => c.copyWith(gradians: !c.gradians)),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _Section(title: 'Feedback', children: [
                      _SettingsRow(
                        key: const ValueKey('row-sound'),
                        icon: LucideIconId.volume2,
                        title: 'Key click sounds',
                        subtitle: 'Tactile mechanical audio responses on button taps',
                        trailing: M3Switch(key: const ValueKey('switch-sound'), on: s.soundEnabled),
                        onTap: () => update((c) => c.copyWith(soundEnabled: !c.soundEnabled)),
                      ),
                      _SettingsRow(
                        key: const ValueKey('row-haptic'),
                        icon: LucideIconId.smartphone,
                        title: 'Haptic vibration',
                        subtitle: 'Physical vibrations on keypad and gesture triggers',
                        trailing: M3Switch(key: const ValueKey('switch-haptic'), on: s.hapticEnabled),
                        onTap: () {
                          final next = !s.hapticEnabled;
                          update((c) => c.copyWith(hapticEnabled: next));
                          if (next) feedback.triggerHaptic(s.vibrationIntensity);
                        },
                      ),
                      _SettingsRow(
                        key: const ValueKey('row-vibration'),
                        title: 'Vibration strength',
                        subtitleWidget: Text(
                          s.hapticEnabled ? '${_capitalize(vibration)} intensity' : 'Disabled',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: calcText(size: 12, weight: FontWeight.w400, color: t.onSurfaceVariant, lineHeight: 16),
                        ),
                        chevron: true,
                        dimmed: !s.hapticEnabled,
                        onTap: () {
                          if (!s.hapticEnabled) update((c) => c.copyWith(hapticEnabled: true));
                          _openSub(SettingsSubSheet.vibration);
                        },
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _Section(title: 'Features', children: [
                      _SettingsRow(
                        key: const ValueKey('row-physics'),
                        icon: LucideIconId.atom,
                        title: 'Physics Lab',
                        subtitle: 'Constants, formulas and solvers. Adds a Physics tab to the navigation',
                        trailing: M3Switch(key: const ValueKey('switch-physics'), on: s.enablePhysics),
                        onTap: () => update((c) => c.copyWith(enablePhysics: !c.enablePhysics)),
                      ),
                      _SettingsRow(
                        key: const ValueKey('row-chemistry'),
                        icon: LucideIconId.flame,
                        title: 'Chemistry',
                        subtitle: 'Periodic table, formulas, equation balancer and solvers. Adds a Chemistry tab to the navigation',
                        trailing: M3Switch(key: const ValueKey('switch-chemistry'), on: s.enableChemistry),
                        onTap: () => update((c) => c.copyWith(enableChemistry: !c.enableChemistry)),
                      ),
                      _SettingsRow(
                        key: const ValueKey('row-grapher'),
                        icon: LucideIconId.lineChart,
                        title: 'Interactive 2D grapher',
                        subtitle: 'Function plotting, zoom and multi-curve tracing workspace',
                        trailing: M3Switch(key: const ValueKey('switch-grapher'), on: s.enableGrapher),
                        onTap: () => update((c) => c.copyWith(enableGrapher: !c.enableGrapher)),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _Section(title: 'About', children: [
                      const _SettingsRow(
                        key: ValueKey('row-about'),
                        leading: SizedBox(width: 48, height: 48, child: Center(child: OmniCalcLogo(size: 36))),
                        title: 'OmniCalc',
                        subtitle: 'Version $kAppVersion • By Saketh',
                      ),
                      _SettingsRow(
                        key: const ValueKey('row-guide'),
                        leading: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: tileDecoration,
                          child: NavIcon(id: NavIconId.guide, color: t.primary, size: 22),
                        ),
                        title: 'User guide',
                        subtitle: 'How to use differentiation, integration, limits and more',
                        chevron: true,
                        onTap: () {
                          nav.setSettingsOpen(false);
                          nav.setGuideOpen(true);
                        },
                      ),
                      _SettingsRow(
                        key: const ValueKey('row-github'),
                        leading: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: tileDecoration,
                          child: SizedBox(width: 24, height: 24, child: CustomPaint(painter: _GithubPainter(t.primary))),
                        ),
                        title: 'Source code on GitHub',
                        subtitle: '$kRepoLabel • Open source (GPL-3.0)',
                        trailing: LucideIcon(LucideIconId.externalLink, color: t.onSurfaceVariant, size: 16),
                        onTap: () => links.open(kRepoUrl),
                      ),
                      _SettingsRow(
                        key: const ValueKey('row-privacy'),
                        icon: LucideIconId.shieldCheck,
                        title: 'Privacy policy',
                        subtitle: '100% on-device • Zero telemetry • No permissions',
                        chevron: true,
                        onTap: () => _openSub(SettingsSubSheet.privacy),
                      ),
                      _SettingsRow(
                        key: const ValueKey('row-reset'),
                        icon: LucideIconId.rotateCcw,
                        title: 'Reset settings',
                        subtitle: 'Restore original preferences & themes',
                        chevron: true,
                        onTap: () => _openSub(SettingsSubSheet.resetConfirm),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            // footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: Pressable(
                  key: const ValueKey('settings-done'),
                  onTap: () => nav.setSettingsOpen(false),
                  child: Semantics(
                    button: true,
                    label: 'Done',
                    excludeSemantics: true,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      decoration: BoxDecoration(color: t.primary, borderRadius: pillRadiusAll),
                      child: Text('Done', style: calcText(size: 12, weight: FontWeight.w600, color: t.onPrimary, lineHeight: 16)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        // the sheets Settings opens (z-60: above Settings)
        _ChoiceSheet<String>(
          isOpen: isOpen && _active == SettingsSubSheet.theme,
          title: 'Choose theme',
          description: 'Select a Material You dynamic scheme or curated accent',
          selected: s.theme,
          options: [
            for (final o in kThemeOptions)
              _ChoiceOption<String>(
                o.id,
                o.name,
                o.desc,
                leading: _Swatch(
                  option: o,
                  size: 40,
                  child: o.isDynamic ? const LucideIcon(LucideIconId.sparkles, color: Color(0xFFFFFFFF), size: 16) : null,
                ),
              ),
          ],
          onSelect: (id) {
            pickTheme(id);
            _closeSub();
          },
          onClose: _closeSub,
        ),
        _ChoiceSheet<ColorMode>(
          isOpen: isOpen && _active == SettingsSubSheet.colorMode,
          title: 'Colour mode',
          description: 'Choose how the app responds to system lighting',
          selected: s.colorMode,
          options: [
            for (final (id, title, desc, icon) in const [
              (ColorMode.system, 'System default', 'Follows phone dark mode schedule automatically', LucideIconId.laptop),
              (ColorMode.light, 'Light mode', 'Always use clean bright surfaces', LucideIconId.sun),
              (ColorMode.dark, 'Dark mode', 'Always use subdued dark surfaces', LucideIconId.moon),
            ])
              _ChoiceOption<ColorMode>(
                id,
                title,
                desc,
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: s.colorMode == id ? t.primary : t.surfaceContainerHigh, shape: BoxShape.circle),
                  child: LucideIcon(icon, color: s.colorMode == id ? t.onPrimary : t.primary, size: 16),
                ),
              ),
          ],
          onSelect: (id) {
            update((c) => c.copyWith(colorMode: id));
            _closeSub();
          },
          onClose: _closeSub,
        ),
        _ChoiceSheet<AngleMode>(
          isOpen: isOpen && _active == SettingsSubSheet.angleMode,
          title: 'Angle unit',
          description: 'Unit used for sin, cos, tan and inverse trigonometric operations',
          selected: s.angleMode,
          options: const [
            _ChoiceOption<AngleMode>(AngleMode.deg, 'Degrees (DEG)', 'Full circle = 360°. Standard for engineering & navigation.'),
            _ChoiceOption<AngleMode>(AngleMode.rad, 'Radians (RAD)', 'Full circle = 2π rad. Standard for calculus & physics.'),
          ],
          onSelect: (id) {
            update((c) => c.copyWith(angleMode: id));
            _closeSub();
          },
          onClose: _closeSub,
        ),
        _ChoiceSheet<int>(
          isOpen: isOpen && _active == SettingsSubSheet.precision,
          title: 'Decimal precision',
          description: 'Number of rounded decimal digits displayed on calculation results',
          selected: s.decimalPrecision,
          options: const [
            _ChoiceOption<int>(-1, 'Auto (Full Precision)', 'Adaptive scientific & fractional display'),
            _ChoiceOption<int>(2, '2 decimal places', 'e.g. 3.14 (Ideal for currency & accounting)'),
            _ChoiceOption<int>(4, '4 decimal places', 'e.g. 3.1416 (Standard scientific accuracy)'),
            _ChoiceOption<int>(6, '6 decimal places', 'e.g. 3.141593 (High accuracy)'),
            _ChoiceOption<int>(8, '8 decimal places', 'e.g. 3.14159265 (Physics & engineering)'),
          ],
          onSelect: (id) {
            update((c) => c.copyWith(decimalPrecision: id));
            _closeSub();
          },
          onClose: _closeSub,
        ),
        _ChoiceSheet<bool>(
          isOpen: isOpen && _active == SettingsSubSheet.calcStyle,
          title: 'Calculation style',
          description: 'How an expression is read and its result shown',
          selected: cs.useCasio,
          options: const [
            _ChoiceOption<bool>(true, 'Casio (default)', 'The fx-991ES PLUS rules: priorities, exact fractions, √ and π results, input-range errors.'),
            _ChoiceOption<bool>(false, 'OmniCalc (legacy)', 'The original OmniCalc engine, unchanged.'),
          ],
          onSelect: (id) {
            CasioRuntime.instance.update((c) => c.copyWith(useCasio: id));
            _closeSub();
          },
          onClose: _closeSub,
        ),
        _ChoiceSheet<bool>(
          isOpen: isOpen && _active == SettingsSubSheet.percentStyle,
          title: 'Percent style',
          description: 'What the % key does after + and −',
          selected: cs.phonePercent,
          options: const [
            _ChoiceOption<bool>(true, 'OmniCalc (default)', '100+10% = 110 and 200−10% = 180, as on a phone.'),
            _ChoiceOption<bool>(false, 'Casio postfix', '% divides by 100: 100+10% = 100.1. 150×20% = 30 either way.'),
          ],
          onSelect: (id) {
            CasioRuntime.instance.update((c) => c.copyWith(phonePercent: id));
            _closeSub();
          },
          onClose: _closeSub,
        ),
        _ChoiceSheet<bool>(
          isOpen: isOpen && _active == SettingsSubSheet.resultDisplay,
          title: 'Result display',
          description: 'What = shows first; S⇔D switches to the other form',
          selected: cs.decimalFirst,
          options: const [
            _ChoiceOption<bool>(false, 'Math (fractions, √ and π)', 'MthIO-MathO: 2÷3 gives a fraction, √2×√3 gives √6.'),
            _ChoiceOption<bool>(true, 'Decimal first', 'LineIO: results start as decimals, S⇔D gives the exact form.'),
          ],
          onSelect: (id) {
            CasioRuntime.instance.update((c) => c.copyWith(
                decimalFirst: id, displayFormat: id ? CasioDisplayFormat.lineIO : CasioDisplayFormat.mathO));
            _closeSub();
          },
          onClose: _closeSub,
        ),
        _ChoiceSheet<int>(
          isOpen: isOpen && _active == SettingsSubSheet.numberFormat,
          title: 'Number format',
          description: 'Fix, Sci, Norm 1 and Norm 2 of the calculator',
          selected: casioNumberFormatId(cs),
          options: [
            const _ChoiceOption<int>(0, 'Norm 1', 'Exponent form below 10⁻² and from 10¹⁰'),
            const _ChoiceOption<int>(1, 'Norm 2', 'Exponent form below 10⁻⁹ and from 10¹⁰'),
            for (var d = 0; d <= 9; d++)
              _ChoiceOption<int>(100 + d, 'Fix $d', '$d decimal places, e.g. ${(3.14159265358979).toStringAsFixed(d)}'),
            for (var d = 1; d <= 9; d++) _ChoiceOption<int>(200 + d, 'Sci $d', '$d significant digits'),
            const _ChoiceOption<int>(200, 'Sci 0', '10 significant digits'),
          ],
          onSelect: (id) {
            CasioRuntime.instance.update((c) {
              if (id == 0) return c.copyWith(numberFormat: CasioNumberFormat.norm1, digits: 0);
              if (id == 1) return c.copyWith(numberFormat: CasioNumberFormat.norm2, digits: 0);
              if (id >= 200) return c.copyWith(numberFormat: CasioNumberFormat.sci, digits: id - 200);
              return c.copyWith(numberFormat: CasioNumberFormat.fix, digits: id - 100);
            });
            _closeSub();
          },
          onClose: _closeSub,
        ),
        _ChoiceSheet<bool>(
          isOpen: isOpen && _active == SettingsSubSheet.fractionFormat,
          title: 'Fraction format',
          description: 'How fraction results larger than 1 are written',
          selected: cs.mixedFractions,
          options: const [
            _ChoiceOption<bool>(false, 'Improper (d/c)', '7⌟6'),
            _ChoiceOption<bool>(true, 'Mixed (a b/c)', '1⌟1⌟6'),
          ],
          onSelect: (id) {
            CasioRuntime.instance.update((c) => c.copyWith(mixedFractions: id));
            _closeSub();
          },
          onClose: _closeSub,
        ),
        _ChoiceSheet<bool>(
          isOpen: isOpen && _active == SettingsSubSheet.decimalPoint,
          title: 'Decimal point (Disp)',
          description: 'Results only: a dot is always shown while typing. With a comma, several results are separated by ;',
          selected: cs.commaDecimal,
          options: const [
            _ChoiceOption<bool>(false, 'Dot (.)', '1.5'),
            _ChoiceOption<bool>(true, 'Comma (,)', '1,5'),
          ],
          onSelect: (id) {
            CasioRuntime.instance.update((c) => c.copyWith(commaDecimal: id));
            _closeSub();
          },
          onClose: _closeSub,
        ),
        _ChoiceSheet<int>(
          isOpen: isOpen && _active == SettingsSubSheet.contrast,
          title: 'Display contrast (CONT)',
          description: 'How strong the calculator display is drawn. 5 is the normal look',
          selected: cs.contrast,
          options: [
            for (final n in const [5, 4, 3, 2, 1]) _ChoiceOption<int>(n, casioContrastLabel(n), n == 5 ? 'Default' : 'Lighter'),
          ],
          onSelect: (id) {
            CasioRuntime.instance.update((c) => c.copyWith(contrast: id));
            _closeSub();
          },
          onClose: _closeSub,
        ),
        _ChoiceSheet<bool>(
          isOpen: isOpen && _active == SettingsSubSheet.complexFormat,
          title: 'Complex format',
          description: 'How CMPLX results are written (▸r∠θ and ▸a+bi override it for one result)',
          selected: cs.complexPolar,
          options: const [
            _ChoiceOption<bool>(false, 'Rectangular (a+bi)', '1+i'),
            _ChoiceOption<bool>(true, 'Polar (r∠θ)', '√2∠45'),
          ],
          onSelect: (id) {
            CasioRuntime.instance.update((c) => c.copyWith(complexPolar: id));
            _closeSub();
          },
          onClose: _closeSub,
        ),
        _ChoiceSheet<bool>(
          isOpen: isOpen && _active == SettingsSubSheet.statFreq,
          title: 'STAT frequency column',
          description: 'Used by the STAT mode (coming in the next phase)',
          selected: cs.statFreq,
          options: const [
            _ChoiceOption<bool>(false, 'Off', 'The data editor has no FREQ column'),
            _ChoiceOption<bool>(true, 'On', 'The data editor has a FREQ column'),
          ],
          onSelect: (id) {
            CasioRuntime.instance.update((c) => c.copyWith(statFreq: id));
            _closeSub();
          },
          onClose: _closeSub,
        ),
        _ChoiceSheet<bool>(
          isOpen: isOpen && _active == SettingsSubSheet.tableFormat,
          title: 'TABLE format',
          description: 'Used by the TABLE mode (coming in the next phase)',
          selected: cs.tableFg,
          options: const [
            _ChoiceOption<bool>(false, 'f(x)', 'One function'),
            _ChoiceOption<bool>(true, 'f(x), g(x)', 'Two functions'),
          ],
          onSelect: (id) {
            CasioRuntime.instance.update((c) => c.copyWith(tableFg: id));
            _closeSub();
          },
          onClose: _closeSub,
        ),
        _ChoiceSheet<VibrationIntensity>(
          isOpen: isOpen && _active == SettingsSubSheet.vibration,
          title: 'Vibration strength',
          description: 'Tune tactile pulse strength for key presses',
          selected: s.vibrationIntensity,
          closeLabel: 'Done',
          options: [
            for (final (id, title, desc) in const [
              (VibrationIntensity.light, 'Light', 'Subtle micro-tick (10ms)'),
              (VibrationIntensity.medium, 'Medium', 'Standard balanced haptic tap (25ms)'),
              (VibrationIntensity.strong, 'Strong', 'Pronounced firm feedback (45ms)'),
              (VibrationIntensity.intense, 'Intense', 'High intensity mechanical pulse (75ms)'),
            ])
              _ChoiceOption<VibrationIntensity>(
                id,
                title,
                desc,
                extra: Pressable(
                  key: ValueKey('vibration-test-${id.name}'),
                  onTap: () => feedback.triggerHaptic(id),
                  pressedScale: 0.9,
                  child: Semantics(
                    button: true,
                    label: 'Test $title',
                    excludeSemantics: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text('Test', style: calcText(size: 11, weight: FontWeight.w600, color: t.primary, lineHeight: 16.5)),
                    ),
                  ),
                ),
              ),
          ],
          onSelect: (id) {
            update((c) => c.copyWith(hapticEnabled: true, vibrationIntensity: id));
            feedback.triggerHaptic(id);
          },
          onClose: _closeSub,
        ),
        M3Sheet(
          isOpen: isOpen && _active == SettingsSubSheet.privacy,
          onClose: _closeSub,
          label: 'Privacy commitment',
          maxWidth: 512,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: t.primaryContainer, borderRadius: const BorderRadius.all(Radius.circular(16))),
                    child: LucideIcon(LucideIconId.shieldCheck, color: t.onPrimaryContainer, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Privacy Commitment',
                            style: calcText(size: 18, weight: FontWeight.w700, color: t.onSurface, lineHeight: 22.5)),
                        Text('Zero telemetry • Local processing • COPPA Compliant',
                            style: calcText(size: 12, weight: FontWeight.w400, color: t.onSurfaceVariant, lineHeight: 16)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, (lead, text)) in kPrivacyPoints.indexed) ...[
                      if (i > 0) const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: t.surfaceContainer, borderRadius: const BorderRadius.all(Radius.circular(20))),
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: lead, style: const TextStyle(fontWeight: FontWeight.w700)),
                            TextSpan(text: ' $text'),
                          ]),
                          style: calcText(size: 12, weight: FontWeight.w400, color: t.onSurface, lineHeight: 19.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Pressable(
                    key: const ValueKey('privacy-standalone'),
                    onTap: () => links.open(kPrivacyPolicyUrl),
                    child: Semantics(
                      link: true,
                      label: 'Standalone Policy',
                      excludeSemantics: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Standalone Policy',
                            style: calcText(size: 12, weight: FontWeight.w600, color: t.primary, lineHeight: 16)
                                .copyWith(decoration: TextDecoration.underline, decorationColor: t.primary),
                          ),
                          const SizedBox(width: 6),
                          LucideIcon(LucideIconId.externalLink, color: t.primary, size: 14),
                        ],
                      ),
                    ),
                  ),
                  Pressable(
                    key: const ValueKey('privacy-close'),
                    onTap: _closeSub,
                    child: Semantics(
                      button: true,
                      label: 'Close',
                      excludeSemantics: true,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Text('Close', style: calcText(size: 12, weight: FontWeight.w600, color: t.primary, lineHeight: 16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        M3Sheet(
          isOpen: isOpen && _active == SettingsSubSheet.resetConfirm,
          onClose: _closeSub,
          label: 'Reset all settings',
          maxWidth: 384,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: t.errorContainer, borderRadius: const BorderRadius.all(Radius.circular(16))),
                    child: LucideIcon(LucideIconId.rotateCcw, color: t.onErrorContainer, size: 20),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Reset all settings?', style: calcText(size: 18, weight: FontWeight.w700, color: t.onSurface, lineHeight: 28)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      'This will restore all default preferences, enable Dynamic system colours, and reset audio/haptics. Your calculation history will not be erased.',
                      style: calcText(size: 12, weight: FontWeight.w400, color: t.onSurfaceVariant, lineHeight: 19.5),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Pressable(
                          key: const ValueKey('reset-cancel'),
                          onTap: _closeSub,
                          child: Semantics(
                            button: true,
                            label: 'Cancel',
                            excludeSemantics: true,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: t.surfaceContainerHigh, borderRadius: pillRadiusAll),
                              child: Text('Cancel', style: calcText(size: 12, weight: FontWeight.w600, color: t.onSurfaceVariant, lineHeight: 16)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Pressable(
                          key: const ValueKey('reset-confirm'),
                          onTap: () => _reset(store),
                          child: Semantics(
                            button: true,
                            label: 'Reset',
                            excludeSemantics: true,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: t.error, borderRadius: pillRadiusAll),
                              child: Text('Reset', style: calcText(size: 12, weight: FontWeight.w600, color: t.onError, lineHeight: 16)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// The five points of the privacy sheet (lead in bold, then the text).
const List<(String, String)> kPrivacyPoints = [
  (
    'Zero Tracking & Telemetry:',
    'OmniCalc has no ads, analytics or tracking. We do not track, profile, collect, or transmit your activity or calculations.'
  ),
  (
    'Local Storage Only:',
    'Your calculations, history and preferences stay on your device. The only internet use is the currency converter downloading public exchange rates, which sends none of your data.'
  ),
  (
    'No Dangerous Permissions:',
    'No microphone, camera, contacts, or storage permissions are required. Sound effects are generated mathematically in real time via Web Audio oscillators'
  ),
  ('Open source:', 'The full source code is public at $kRepoLabel, so these claims can be checked.'),
  ('Developer Contact:', 'Developed by Saketh (adsaketh@gmail.com).'),
];

/// The GitHub mark of the About row (`fill="currentColor"`, 24 x 24 viewBox).
class _GithubPainter extends CustomPainter {
  const _GithubPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(kSettingsPathBuilders[0](), Paint()..color = color..isAntiAlias = true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GithubPainter old) => old.color != color;
}

/// Id of the number-format choice: 0 Norm 1, 1 Norm 2, 100+n Fix n, 200+n Sci n (Sci 0 = 10 digits).
int casioNumberFormatId(CasioSettings c) => switch (c.numberFormat) {
      CasioNumberFormat.norm1 => 0,
      CasioNumberFormat.norm2 => 1,
      CasioNumberFormat.fix => 100 + c.digits,
      CasioNumberFormat.sci => 200 + c.digits,
    };

String casioNumberFormatLabel(CasioSettings c) => switch (c.numberFormat) {
      CasioNumberFormat.norm1 => 'Norm 1',
      CasioNumberFormat.norm2 => 'Norm 2',
      CasioNumberFormat.fix => 'Fix ${c.digits}',
      CasioNumberFormat.sci => 'Sci ${c.digits}',
    };

/// Names of the five CONT levels (SETUP ▸ CONT, manual p.6).
String casioContrastLabel(int level) => switch (level) {
      5 => '5 (normal)',
      _ => '$level',
    };
