import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Motion language of OmniCalc (Material 3 Expressive, shared with Ping): `src/motion.ts` and the `--ease-*` tokens and
/// keyframes of `src/index.css`. Numbers are copied, not tuned.
class M3Curves {
  const M3Curves._();

  /// --ease-emphasized: cubic-bezier(0.2, 0, 0, 1)
  static const Cubic emphasized = Cubic(0.2, 0, 0, 1);

  /// --ease-emphasized-decelerate: cubic-bezier(0.05, 0.7, 0.1, 1)
  static const Cubic emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1);

  /// --ease-emphasized-accelerate: cubic-bezier(0.3, 0, 0.8, 0.15)
  static const Cubic emphasizedAccelerate = Cubic(0.3, 0, 0.8, 0.15);

  /// --ease-spring: cubic-bezier(0.34, 1.4, 0.64, 1)
  static const Cubic spring = Cubic(0.34, 1.4, 0.64, 1);

  /// CSS `ease`: cubic-bezier(0.25, 0.1, 0.25, 1)
  static const Cubic cssEase = Cubic(0.25, 0.1, 0.25, 1);

  /// Tailwind's default transition timing (`transition-transform`, `transition-colors`): cubic-bezier(0.4, 0, 0.2, 1)
  static const Cubic tailwind = Cubic(0.4, 0, 0.2, 1);
}

/// `spring` and `springBouncy` of src/motion.ts (motion/react spring parameters: stiffness, damping, mass).
class M3Springs {
  const M3Springs._();

  static const SpringDescription spring = SpringDescription(mass: 0.9, stiffness: 420, damping: 36);
  static const SpringDescription springBouncy = SpringDescription(mass: 0.85, stiffness: 520, damping: 26);
}

/// `fadeFast`: 0.18 s, emphasized.
const Duration fadeFastDuration = Duration(milliseconds: 180);

/// The phone's "remove animations" setting (CSS `prefers-reduced-motion: reduce` in index.css): animations collapse
/// to an instant jump.
bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Base for the one-shot keyframe animations: runs once when the widget first appears (CSS `animation ... backwards`
/// on an element that has just been mounted), or again when [restartKey] changes.
abstract class _OneShot extends StatefulWidget {
  const _OneShot({super.key});
}

abstract class _OneShotState<T extends _OneShot> extends State<T> with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  Duration get total;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: total);
  }

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (reduceMotion(context)) {
        controller.value = 1;
      } else {
        controller.forward();
      }
    }
  }

  void restart() {
    if (reduceMotion(context)) {
      controller.value = 1;
    } else {
      controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

/// `.animate-m3-screen-enter`: opacity 0 -> 1 and translateY 12px -> 0, 380 ms, emphasized decelerate.
/// The shell keys each screen so it replays on every screen change.
class M3ScreenEnter extends _OneShot {
  const M3ScreenEnter({super.key, required this.child});

  final Widget child;

  @override
  State<M3ScreenEnter> createState() => _M3ScreenEnterState();
}

class _M3ScreenEnterState extends _OneShotState<M3ScreenEnter> {
  @override
  Duration get total => const Duration(milliseconds: 380);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = M3Curves.emphasizedDecelerate.transform(controller.value);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// `.animate-fadeIn` (`m3FadeIn`): opacity 0 -> 1 and translateY 4px -> 0, 200 ms, emphasized decelerate.
class M3FadeIn extends _OneShot {
  const M3FadeIn({super.key, required this.child});

  final Widget child;

  @override
  State<M3FadeIn> createState() => _M3FadeInState();
}

class _M3FadeInState extends _OneShotState<M3FadeIn> {
  @override
  Duration get total => const Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = M3Curves.emphasizedDecelerate.transform(controller.value);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, 4 * (1 - t)), child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// `.guide-step` (`guideStepIn`): opacity 0 -> 1 and translateY 8px -> 0, 320 ms, emphasized decelerate, with an
/// optional start delay (the TS sets `animation-delay` inline).
class GuideStepIn extends _OneShot {
  const GuideStepIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<GuideStepIn> createState() => _GuideStepInState();
}

class _GuideStepInState extends _OneShotState<GuideStepIn> {
  @override
  Duration get total => widget.delay + const Duration(milliseconds: 320);

  @override
  Widget build(BuildContext context) {
    final delayFraction = widget.delay.inMicroseconds / total.inMicroseconds;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final raw = ((controller.value - delayFraction) / (1 - delayFraction)).clamp(0.0, 1.0);
        final t = M3Curves.emphasizedDecelerate.transform(raw);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// `.adv-grid > *` (`advKeyIn`): the advanced keypad's keys pop in one after another. opacity 0 -> 1,
/// translateY 10px -> 0, scale 0.9 -> 1, 340 ms emphasized decelerate; the delay is 16 ms per position
/// (position 1 = 16 ms ... position 24 = 384 ms; 25 to 28 also 384 ms). [index] is zero-based.
/// Changing [replayKey] replays it (a tab change replays the whole grid).
class AdvKeyIn extends _OneShot {
  const AdvKeyIn({super.key, required this.index, required this.child, this.replayKey});

  final int index;
  final Widget child;
  final Object? replayKey;

  static Duration delayFor(int index) => Duration(milliseconds: 16 * (index + 1 > 24 ? 24 : index + 1));

  @override
  State<AdvKeyIn> createState() => _AdvKeyInState();
}

class _AdvKeyInState extends _OneShotState<AdvKeyIn> {
  @override
  Duration get total => AdvKeyIn.delayFor(widget.index) + const Duration(milliseconds: 340);

  @override
  void didUpdateWidget(AdvKeyIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.replayKey != widget.replayKey) {
      controller.duration = total;
      restart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final delayFraction = AdvKeyIn.delayFor(widget.index).inMicroseconds / total.inMicroseconds;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final raw = ((controller.value - delayFraction) / (1 - delayFraction)).clamp(0.0, 1.0);
        final t = M3Curves.emphasizedDecelerate.transform(raw);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// `.fx-turn` (`fxTurn`): the fx ADV key spins in when the drawer opens. rotate(-90deg) scale(0.7) -> none,
/// 360 ms, spring curve.
class FxTurn extends _OneShot {
  const FxTurn({super.key, required this.child});

  final Widget child;

  @override
  State<FxTurn> createState() => _FxTurnState();
}

class _FxTurnState extends _OneShotState<FxTurn> {
  @override
  Duration get total => const Duration(milliseconds: 360);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = M3Curves.spring.transform(controller.value);
        return Transform.rotate(
          angle: -1.5707963267948966 * (1 - t),
          child: Transform.scale(scale: 0.7 + 0.3 * t, child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// `.animate-m3-result-update` (`m3ResultUpdate`): 240 ms; scale 0.96 and opacity 0.85 -> scale 1.02 and opacity 1
/// at 60% -> scale 1. Each keyframe interval uses the spring curve. Replays whenever [trigger] changes.
class M3ResultUpdate extends _OneShot {
  const M3ResultUpdate({super.key, required this.trigger, required this.child});

  final Object? trigger;
  final Widget child;

  @override
  State<M3ResultUpdate> createState() => _M3ResultUpdateState();
}

class _M3ResultUpdateState extends _OneShotState<M3ResultUpdate> {
  @override
  Duration get total => const Duration(milliseconds: 240);

  @override
  void didUpdateWidget(M3ResultUpdate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) restart();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final v = controller.value;
        double scale;
        double opacity;
        if (v < 0.6) {
          final t = M3Curves.spring.transform(v / 0.6);
          scale = 0.96 + (1.02 - 0.96) * t;
          opacity = 0.85 + (1.0 - 0.85) * t;
        } else {
          final t = M3Curves.spring.transform((v - 0.6) / 0.4);
          scale = 1.02 + (1.0 - 1.02) * t;
          opacity = 1.0;
        }
        return Opacity(opacity: opacity.clamp(0.0, 1.0), child: Transform.scale(scale: scale, child: child));
      },
      child: widget.child,
    );
  }
}

/// `.m3-key`: every tappable surface springs in a little and shows a tonal state layer, no glows.
///  - pressed: scale 0.95 over 90 ms (spring curve), released: back over 140 ms
///  - state layer in the foreground colour: 14% while pressed (the 8% hover tint is for a real mouse only)
///  - background and foreground colours change over 220 ms, emphasized
class M3Key extends StatefulWidget {
  const M3Key({
    super.key,
    required this.child,
    required this.foreground,
    this.background,
    this.borderRadius = BorderRadius.zero,
    this.onTap,
    this.onLongPress,
    this.onPressedChanged,
    this.semanticLabel,
    this.enabled = true,
  });

  final Widget child;

  /// `currentColor` of the key: used for the state layer.
  final Color foreground;
  final Color? background;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Called with true on press and false on release or cancel.
  final ValueChanged<bool>? onPressedChanged;
  final String? semanticLabel;
  final bool enabled;

  @override
  State<M3Key> createState() => _M3KeyState();
}

class _M3KeyState extends State<M3Key> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
    widget.onPressedChanged?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final instant = reduceMotion(context);
    final scaleDuration = instant ? Duration.zero : Duration(milliseconds: _pressed ? 90 : 140);
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled ? (_) => _set(true) : null,
        onTapUp: widget.enabled ? (_) => _set(false) : null,
        onTapCancel: widget.enabled ? () => _set(false) : null,
        onTap: widget.enabled ? widget.onTap : null,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: scaleDuration,
          curve: M3Curves.spring,
          child: AnimatedContainer(
            duration: instant ? Duration.zero : const Duration(milliseconds: 220),
            curve: M3Curves.emphasized,
            decoration: BoxDecoration(color: widget.background, borderRadius: widget.borderRadius),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                widget.child,
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _pressed ? 0.14 : 0.0,
                      duration: instant ? Duration.zero : const Duration(milliseconds: 120),
                      curve: M3Curves.cssEase,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: widget.foreground, borderRadius: widget.borderRadius),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
