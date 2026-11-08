import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../theme/css_transition.dart';
import '../../theme/glass.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../icons/nav_icon.dart';
import '../icons/omnicalc_logo.dart';

/// A 44 x 44 round action (the guide, sound and settings buttons): `w-11 h-11 rounded-full`, shrinks to 90% while pressed
/// (`active:scale-90 transition-transform`: Tailwind's 150 ms default timing).
class ShellIconButton extends StatefulWidget {
  const ShellIconButton({
    super.key,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
    this.background,
    this.size = 44,
  });

  final String semanticLabel;
  final VoidCallback onTap;
  final Widget child;
  final Color? background;
  final double size;

  @override
  State<ShellIconButton> createState() => _ShellIconButtonState();
}

class _ShellIconButtonState extends State<ShellIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.9 : 1,
          duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 150),
          curve: M3Curves.tailwind,
          child: Container(
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: widget.background, shape: BoxShape.circle),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// The three header actions, shared by the header pill, the embedded calculator header and the navigation rail:
/// guide (primary), sound (secondary container when on) and settings.
List<Widget> buildShellActions(
  M3Tokens t, {
  required bool soundEnabled,
  required VoidCallback onToggleSound,
  required VoidCallback onOpenSettings,
  required VoidCallback onOpenGuide,
}) {
  return [
    ShellIconButton(
      semanticLabel: 'How to use OmniCalc',
      onTap: onOpenGuide,
      child: NavIcon(id: NavIconId.guide, size: 22, color: t.primary),
    ),
    ShellIconButton(
      semanticLabel: soundEnabled ? 'Mute key clicks' : 'Enable key clicks',
      onTap: onToggleSound,
      background: soundEnabled ? t.secondaryContainer : null,
      child: NavIcon(
        id: NavIconId.sound,
        active: soundEnabled,
        size: 20,
        color: soundEnabled ? t.onSecondaryContainer : t.onSurfaceVariant,
      ),
    ),
    ShellIconButton(
      semanticLabel: 'Settings',
      onTap: onOpenSettings,
      child: NavIcon(id: NavIconId.settings, size: 20, color: t.onSurface),
    ),
  ];
}

/// Floating glass pill at the top, like Ping's search bar. On the screens that scroll (Converter, Physics, Finance ...)
/// it collapses as you scroll down: the pill SPLITS, like Apple's Liquid Glass.
///
///   Expanded:  [ logo   OmniCalc                      guide sound settings ]
///   Collapsed: ( logo )   [ OmniCalc ]   [ guide sound settings ]
///
/// Port of `Header.tsx` and the `.hdr-*` rules of `index.css`. Four numbers drive it, each with its own timing:
///   hc  the middle pill contracts            560 ms, no delay, cubic-bezier(0.25, 0.8, 0.25, 1)
///   hl  the logo circle pops out             780 ms, 30 ms delay, cubic-bezier(0.34, 1.75, 0.64, 1)
///   hr  the action pill pops out             780 ms, 90 ms delay, cubic-bezier(0.34, 1.75, 0.64, 1)
///   hn  the name glides to the centre        900 ms, 60 ms delay, cubic-bezier(0.34, 1.7, 0.64, 1)
/// plus the name's rubber-band stretch (860 ms after 60 ms) and the logo's pop (560 ms after 240 ms), which restart on
/// every collapse or expand.
class Header extends StatefulWidget {
  const Header({
    super.key,
    required this.soundEnabled,
    required this.onToggleSound,
    required this.onOpenSettings,
    required this.onOpenGuide,
    this.onLogoTap,
    this.collapsed = false,
    this.embedded = false,
  });

  final bool soundEnabled;
  final VoidCallback onToggleSound;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenGuide;

  /// Tapping the round logo (shown when the header is collapsed) scrolls back to the top.
  final VoidCallback? onLogoTap;

  /// The header is collapsed (the shell drives this from the scroll position).
  final bool collapsed;

  /// Calculator: the header row lives inside the answer display card (no pill of its own, no collapsing), so the
  /// header and the display read as one card.
  final bool embedded;

  @override
  State<Header> createState() => _HeaderState();
}

class _HeaderState extends State<Header> with TickerProviderStateMixin {
  late final CssTransitionValue _hc;
  late final CssTransitionValue _hl;
  late final CssTransitionValue _hr;
  late final CssTransitionValue _hn;
  late final AnimationController _move;
  int _dir = 1;

  static const Duration _moveTotal = Duration(milliseconds: 960);

  @override
  void initState() {
    super.initState();
    final start = widget.collapsed ? 1.0 : 0.0;
    _hc = CssTransitionValue(
      vsync: this,
      duration: const Duration(milliseconds: 560),
      curve: const Cubic(0.25, 0.8, 0.25, 1),
      initial: start,
    );
    _hl = CssTransitionValue(
      vsync: this,
      duration: const Duration(milliseconds: 780),
      delay: const Duration(milliseconds: 30),
      curve: const Cubic(0.34, 1.75, 0.64, 1),
      initial: start,
    );
    _hr = CssTransitionValue(
      vsync: this,
      duration: const Duration(milliseconds: 780),
      delay: const Duration(milliseconds: 90),
      curve: const Cubic(0.34, 1.75, 0.64, 1),
      initial: start,
    );
    _hn = CssTransitionValue(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      delay: const Duration(milliseconds: 60),
      curve: const Cubic(0.34, 1.7, 0.64, 1),
      initial: start,
    );
    _move = AnimationController(vsync: this, duration: _moveTotal, value: 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final instant = reduceMotion(context);
    for (final v in [_hc, _hl, _hr, _hn]) {
      v.instant = instant;
    }
  }

  @override
  void didUpdateWidget(Header old) {
    super.didUpdateWidget(old);
    if (old.collapsed != widget.collapsed) {
      final target = widget.collapsed ? 1.0 : 0.0;
      _hc.animateTo(target);
      _hl.animateTo(target);
      _hr.animateTo(target);
      _hn.animateTo(target);
      _dir = widget.collapsed ? 1 : -1;
      if (!reduceMotion(context)) _move.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _hc.dispose();
    _hl.dispose();
    _hr.dispose();
    _hn.dispose();
    _move.dispose();
    super.dispose();
  }

  // ---- keyframes -----------------------------------------------------------------------------------------------

  static const Cubic _kf = Cubic(0.3, 0.7, 0.4, 1);

  /// Piecewise keyframe animation: [offsets] ascending 0..1, the timing function applies inside each interval.
  static double _keyframes(double t, List<double> offsets, List<double> values) {
    for (var i = 1; i < offsets.length; i++) {
      if (t <= offsets[i]) {
        final span = offsets[i] - offsets[i - 1];
        final local = span <= 0 ? 1.0 : (t - offsets[i - 1]) / span;
        return values[i - 1] + (values[i] - values[i - 1]) * _kf.transform(local.clamp(0.0, 1.0));
      }
    }
    return values.last;
  }

  /// `nameRubber`: 860 ms after a 60 ms delay (it stretches along its travel, squashes as it overshoots the middle, settles).
  ({double dx, double sx, double sy}) _rubber() {
    final ms = _move.value * _moveTotal.inMilliseconds;
    final t = ((ms - 60) / 860).clamp(0.0, 1.0);
    const o = [0.0, 0.18, 0.42, 0.62, 0.80, 1.0];
    final d = _dir.toDouble();
    return (
      dx: _keyframes(t, o, [0, -4 * d, 7 * d, -3 * d, 1.5 * d, 0]),
      sx: _keyframes(t, o, const [1, 1.34, 0.88, 1.06, 0.99, 1]),
      sy: _keyframes(t, o, const [1, 0.86, 1.1, 0.97, 1.02, 1]),
    );
  }

  /// `logoPop`: 560 ms after a 240 ms delay, only when collapsing.
  double _logoPop() {
    if (_dir != 1) return 1;
    final ms = _move.value * _moveTotal.inMilliseconds;
    final t = ((ms - 240) / 560).clamp(0.0, 1.0);
    return _keyframes(t, const [0.0, 0.35, 0.70, 1.0], const [1, 0.88, 1.1, 1]);
  }

  // ---- build ---------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final actions = buildShellActions(
      t,
      soundEnabled: widget.soundEnabled,
      onToggleSound: widget.onToggleSound,
      onOpenSettings: widget.onOpenSettings,
      onOpenGuide: widget.onOpenGuide,
    );

    if (widget.embedded) return _buildEmbedded(t, actions);

    final top = math.max(MediaQuery.paddingOf(context).top, 8.0);
    return Padding(
      padding: EdgeInsets.fromLTRB(12, top, 12, 4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1650),
          child: SizedBox(
            height: 56,
            child: LayoutBuilder(
              builder: (context, box) {
                return AnimatedBuilder(
                  animation: Listenable.merge([_hc, _hl, _hr, _hn, _move]),
                  builder: (context, _) => _buildSplit(t, actions, box.maxWidth),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Calculator: the header row inside the display card. `flex items-center gap-0.5 -mt-1`.
  Widget _buildEmbedded(M3Tokens t, List<Widget> actions) {
    final row = SizedBox(
      height: 44,
      child: Row(
        children: [
          const OmniCalcLogo(size: 36),
          const SizedBox(width: 2 + 8),
          // Phase 8b: the name takes the room between the logo and the buttons and only shrinks when it does not fit (narrow
          // phones, large system font). At normal widths it is exactly the natural size, as in the web header.
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'OmniCalc',
                  softWrap: false,
                  style: appText(size: 18, weight: FontWeight.w700, letterSpacingEm: -0.025, color: t.onSurface),
                ),
              ),
            ),
          ),
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            actions[i],
          ],
        ],
      ),
    );
    // margin-top: -4px: the row starts 4px higher and the box is 4px shorter
    return SizedBox(
      height: 40,
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minHeight: 44,
        maxHeight: 44,
        child: Transform.translate(offset: const Offset(0, -4), child: row),
      ),
    );
  }

  Widget _buildSplit(M3Tokens t, List<Widget> actions, double w) {
    final hc = _hc.value;
    final hl = _hl.value;
    final hr = _hr.value;
    final hn = _hn.value;

    // Collapsed width of the middle pill: a fixed size per header width (container query in the CSS)
    final cw = w <= 340 ? 100.0 : (w <= 365 ? 120.0 : 140.0);
    final pillLeft = (64 + (w - 226 - cw) / 2) * hc;
    final pillWidth = w - (w - cw) * hc;

    final rubber = _rubber();
    final nameColor = Color.lerp(t.onSurface, t.primary, hn.clamp(0.0, 1.0))!;
    final nameShift = (w / 2 - 107) * hn;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Piece 1: the logo's own round glass, hidden inside the pill until the header splits
        Positioned(
          left: 0,
          top: 0,
          width: 56,
          height: 56,
          child: IgnorePointer(
            child: Opacity(
              opacity: (hl * 3).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset((1 - hl) * 30, 0),
                child: Transform.scale(
                  scale: math.max(0.0, 0.45 + 0.55 * hl),
                  child: const BarSurface(borderRadius: pillRadius, child: SizedBox.expand()),
                ),
              ),
            ),
          ),
        ),

        // Piece 2: the main pill, full width at rest and a snug pill around the name when collapsed
        Positioned(
          left: pillLeft,
          top: 0,
          width: math.max(0.0, pillWidth),
          height: 56,
          child: const BarSurface(borderRadius: pillRadius, child: SizedBox.expand()),
        ),

        // The name: glides from the left to the middle of the collapsed header, rubber-band style
        Positioned(
          left: 58,
          top: 0,
          height: 56,
          child: IgnorePointer(
            child: Transform.translate(
              offset: Offset(nameShift, 0),
              child: FractionalTranslation(
                translation: Offset(-0.5 * hn, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1,
                  // CSS: transform-origin 0% 50% (collapsing) or 100% 50% (expanding), translateX(dx) scale(sx, sy)
                  child: Transform.translate(
                    offset: Offset(rubber.dx, 0),
                    child: Transform(
                      alignment: _dir == 1 ? Alignment.centerLeft : Alignment.centerRight,
                      transform: Matrix4.diagonal3Values(rubber.sx, rubber.sy, 1),
                      child: Text(
                        'OmniCalc',
                        softWrap: false,
                        style: appText(size: 19, weight: FontWeight.w700, letterSpacingEm: -0.02, color: nameColor),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // The logo button sits above both pieces
        Positioned(
          left: 0,
          top: 0,
          width: 56,
          height: 56,
          child: ShellIconButton(
            semanticLabel: 'OmniCalc, back to top',
            size: 56,
            onTap: widget.onLogoTap ?? () {},
            child: Transform.scale(scale: _logoPop(), child: const OmniCalcLogo(size: 36)),
          ),
        ),

        // Piece 3: actions. Transparent inside the big pill, their own glass pill when collapsed
        Positioned(
          right: 0,
          top: 0,
          height: 56,
          child: Stack(
            clipBehavior: Clip.none,
            // the 44 px buttons are centred in the 56 px pill, like the logo and the name; without this a Stack puts its
            // one non-positioned child at the top, 6 px above the middle
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: (hr * 3).clamp(0.0, 1.0),
                    child: Transform.scale(
                      alignment: Alignment.centerRight,
                      scale: math.max(0.0, 0.55 + 0.45 * hr),
                      child: const BarSurface(borderRadius: pillRadius, child: SizedBox.expand()),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 2),
                      actions[i],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
