import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/motion.dart';
import '../../theme/spring_value.dart';
import '../../theme/tokens.dart';

/// `src/utils/sheetDrag.ts`: a drag on the handle of at least this many px (6) starts moving the sheet.
const double kSheetDragStartPx = 6;

/// Dragged further than this (110 px) the sheet closes.
const double kSheetDismissDistancePx = 110;

/// Or moved at least 24 px and faster than this (0.6 px per ms, a flick).
const double kSheetDismissFlickPxPerMs = 0.6;

/// `shouldDismiss`.
bool shouldDismissSheet(double dy, double velocity) =>
    dy > kSheetDismissDistancePx || (dy > 24 && velocity > kSheetDismissFlickPxPerMs);

/// `Sheet.tsx`: a bottom sheet that becomes a centred card from 640 px wide. Dimmed scrim (black at 45 %), a drag
/// handle on phones, spring slide in and out (`spring` of src/motion.ts), the whole layer fading with `fadeFast`.
///
/// The pill at the top is a real handle: drag it down (or flick) and the panel follows the finger and closes past
/// 110 px or on a flick, otherwise it springs back in 260 ms; a tap on it closes the sheet.
///
/// [children] are the flex-column children of the panel. Put the one that is `flex-1 min-h-0` in a [Flexible] (or an
/// [Expanded] when [fixedHeight] is true). The widget stays in the tree while [isOpen] is false and draws nothing once
/// its exit animation has finished, like the web component under `AnimatePresence`.
///
/// Give it the whole window (it fills the space it is given): `Positioned.fill` in the shell's overlay stack.
class M3Sheet extends StatefulWidget {
  const M3Sheet({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.label,
    required this.children,
    this.maxWidth = 512,
    this.fixedHeight = false,
  });

  final bool isOpen;
  final VoidCallback onClose;

  /// The dialog's accessible name.
  final String label;
  final List<Widget> children;

  /// `sm:max-w-*` of the centred layout (lg 512, md 448, sm 384, xl 576, 2xl 672).
  final double maxWidth;

  /// Settings and Guide: `h-[92vh] sm:h-[88vh] sm:max-h-[880px]` (on a phone `max-h-[88vh]` wins over 92vh).
  final bool fixedHeight;

  @override
  State<M3Sheet> createState() => _M3SheetState();
}

class _M3SheetState extends State<M3Sheet> with TickerProviderStateMixin {
  late final SpringValue _slide; // 1 = fully below the screen, 0 = in place
  late final AnimationController _fadeController;
  late final Animation<double> _fade;
  late final AnimationController _back;

  final ValueNotifier<double> _dragDy = ValueNotifier<double>(0);
  final ValueNotifier<double> _scrim = ValueNotifier<double>(1);

  bool _present = false;
  bool _internal = false; // a change made from didUpdateWidget: no setState from the listeners

  Timer? _resetTimer;
  double _backFromDy = 0;
  double _backFromScrim = 1;

  bool _active = false;
  bool _moved = false;
  int _pointer = -1;
  double _startY = 0;
  double _lastY = 0;
  double _lastT = 0;
  double _velocity = 0;

  @override
  void initState() {
    super.initState();
    _slide = SpringValue(vsync: this, spring: M3Springs.spring, initial: 1)..addListener(_onTick);
    _fadeController = AnimationController(vsync: this, duration: fadeFastDuration)..addListener(_onTick);
    _fade = CurvedAnimation(parent: _fadeController, curve: M3Curves.emphasized, reverseCurve: M3Curves.emphasized.flipped);
    _back = AnimationController(vsync: this, duration: const Duration(milliseconds: 260))..addListener(_onBack);
    if (widget.isOpen) _present = true; // the first frame already shows it; the animation starts after it
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.isOpen && _slide.value == 1 && !_slide.isAnimating && _fadeController.isDismissed) _open();
  }

  @override
  void didUpdateWidget(M3Sheet old) {
    super.didUpdateWidget(old);
    if (widget.isOpen && !old.isOpen) {
      _open();
    } else if (!widget.isOpen && old.isOpen) {
      _close();
    }
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _slide.dispose();
    _fadeController.dispose();
    _back.dispose();
    _dragDy.dispose();
    _scrim.dispose();
    super.dispose();
  }

  void _open() {
    _internal = true;
    _resetTimer?.cancel();
    if (!_present) {
      _present = true;
      _dragDy.value = 0;
      _scrim.value = 1;
      _back.stop();
    }
    _slide.instant = reduceMotion(context);
    _slide.animateTo(0);
    if (reduceMotion(context)) {
      _fadeController.value = 1;
    } else {
      _fadeController.forward();
    }
    _internal = false;
  }

  void _close() {
    _internal = true;
    _slide.instant = reduceMotion(context);
    _slide.animateTo(1);
    if (reduceMotion(context)) {
      _fadeController.value = 0;
      _present = false;
    } else {
      _fadeController.reverse();
    }
    _internal = false;
  }

  void _onTick() {
    if (_internal || !mounted) return;
    if (!widget.isOpen && _present && !_slide.isAnimating && _fadeController.isDismissed) {
      setState(() => _present = false);
    }
  }

  // --- drag handle -------------------------------------------------------------------------------------------------

  void _setDrag(double dy) {
    _dragDy.value = dy;
    _scrim.value = math.max(0.15, 1 - dy / 420);
  }

  void _springBack() {
    if (_dragDy.value == 0 && _scrim.value == 1) return;
    if (reduceMotion(context)) {
      _dragDy.value = 0;
      _scrim.value = 1;
      return;
    }
    _backFromDy = _dragDy.value;
    _backFromScrim = _scrim.value;
    _back.forward(from: 0);
  }

  void _onBack() {
    final t = _back.value;
    _dragDy.value = _backFromDy * (1 - M3Curves.emphasized.transform(t));
    _scrim.value = _backFromScrim + (1 - _backFromScrim) * t; // linear, as `opacity 260ms linear`
  }

  double _ms(Duration d) => d.inMicroseconds / 1000.0;

  void _onPointerDown(PointerDownEvent e) {
    if (_active) return;
    _active = true;
    _moved = false;
    _pointer = e.pointer;
    _startY = _lastY = e.position.dy;
    _lastT = _ms(e.timeStamp);
    _velocity = 0;
    _back.stop();
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_active || e.pointer != _pointer) return;
    final dy = e.position.dy - _startY;
    if (!_moved && dy.abs() > kSheetDragStartPx) _moved = true;
    if (!_moved) return;
    final t = _ms(e.timeStamp);
    final dt = t - _lastT;
    if (dt > 0) {
      // smoothed speed, so one jittery sample does not decide a flick
      _velocity = 0.7 * _velocity + 0.3 * ((e.position.dy - _lastY) / dt);
      _lastY = e.position.dy;
      _lastT = t;
    }
    _setDrag(math.max(0, dy));
  }

  void _finish(PointerEvent e, {required bool cancelled}) {
    if (!_active || e.pointer != _pointer) return;
    _active = false;
    if (cancelled) {
      _springBack(); // the system took the touch away: just spring back
      return;
    }
    if (!_moved) {
      widget.onClose();
      return;
    }
    final dy = math.max(0.0, e.position.dy - _startY);
    if (shouldDismissSheet(dy, _velocity)) {
      widget.onClose();
      // if the owner decides to keep the sheet open, bring it back instead of leaving it half-way down
      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(milliseconds: 450), () {
        if (mounted) _springBack();
      });
    } else {
      _springBack();
    }
  }

  // --- build -------------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!_present) return const SizedBox.shrink();
    final t = M3Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final sm = size.width >= 640;
    final tall = size.height * 0.88;
    final panelWidth = sm ? math.min(widget.maxWidth, size.width) : size.width;
    final fixed = widget.fixedHeight;
    final panelMaxHeight = fixed && sm ? math.min(tall, 880.0) : tall;
    final radius = sm
        ? const BorderRadius.all(Radius.circular(32))
        : const BorderRadius.vertical(top: Radius.circular(32));

    final panelBody = Stack(
      fit: StackFit.passthrough,
      children: [
        Column(
          mainAxisSize: fixed ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!sm) const SizedBox(height: 18), // `h-[18px]`, the room of the handle
            ...widget.children,
          ],
        ),
        if (!sm)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 30,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: (e) => _finish(e, cancelled: false),
              onPointerCancel: (e) => _finish(e, cancelled: true),
              child: Semantics(
                button: true,
                label: 'Drag down or tap to close',
                onTap: widget.onClose,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: t.outlineVariant, borderRadius: const BorderRadius.all(Radius.circular(9999))),
                      child: const SizedBox(width: 40, height: 6),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    Widget panel = DecoratedBox(
      decoration: BoxDecoration(
        color: t.surfaceContainerLow,
        borderRadius: radius,
        // shadow-2xl
        boxShadow: const [BoxShadow(color: Color(0x40000000), offset: Offset(0, 25), blurRadius: 50, spreadRadius: -12)],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: DefaultTextStyle.merge(style: TextStyle(color: t.onSurface), child: panelBody),
      ),
    );
    panel = fixed
        ? SizedBox(width: panelWidth, height: panelMaxHeight, child: panel)
        : ConstrainedBox(
            constraints: BoxConstraints(maxWidth: panelWidth, minWidth: panelWidth, maxHeight: panelMaxHeight),
            child: panel,
          );

    return SizedBox.expand(
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: widget.label,
        child: FadeTransition(
          opacity: _fade,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClose,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _scrim,
                    builder: (context, v, _) => ColoredBox(color: Color.fromRGBO(0, 0, 0, 0.45 * v)),
                  ),
                ),
              ),
              Align(
                alignment: sm ? Alignment.center : Alignment.bottomCenter,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_slide, _dragDy]),
                  child: panel,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, _dragDy.value),
                    child: FractionalTranslation(translation: Offset(0, _slide.value), child: child),
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

/// `AnimatePresence` + `motion.div` with `initial={{ height: 0, opacity: 0 }}` and `transition={{ height: spring,
/// opacity: { duration: 0.2 } }}` (Settings' glass options and the Guide's section bodies): the child grows from nothing
/// with the sheet spring while it fades in over 200 ms, and shrinks away the same way. It is built without animating
/// when it starts shown (`initial={false}`).
class SpringReveal extends StatefulWidget {
  const SpringReveal({super.key, required this.show, required this.child});

  final bool show;
  final Widget child;

  @override
  State<SpringReveal> createState() => _SpringRevealState();
}

class _SpringRevealState extends State<SpringReveal> with TickerProviderStateMixin {
  late final SpringValue _height;
  late final AnimationController _opacity;
  late bool _present;
  bool _internal = false;

  @override
  void initState() {
    super.initState();
    _present = widget.show;
    _height = SpringValue(vsync: this, spring: M3Springs.spring, initial: widget.show ? 1 : 0)..addListener(_onTick);
    _opacity = AnimationController(vsync: this, duration: const Duration(milliseconds: 200), value: widget.show ? 1 : 0)
      ..addListener(_onTick);
  }

  @override
  void didUpdateWidget(SpringReveal old) {
    super.didUpdateWidget(old);
    if (widget.show == old.show) return;
    _internal = true;
    final instant = reduceMotion(context);
    _height.instant = instant;
    if (widget.show) {
      _present = true;
      _height.animateTo(1);
      instant ? _opacity.value = 1 : _opacity.forward();
    } else {
      _height.animateTo(0);
      if (instant) {
        _opacity.value = 0;
        _present = false;
      } else {
        _opacity.reverse();
      }
    }
    _internal = false;
  }

  void _onTick() {
    if (_internal || !mounted) return;
    if (!widget.show && _present && !_height.isAnimating && _opacity.isDismissed) setState(() => _present = false);
  }

  @override
  void dispose() {
    _height.dispose();
    _opacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_present) return const SizedBox(width: double.infinity);
    return AnimatedBuilder(
      animation: Listenable.merge([_height, _opacity]),
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: Curves.easeInOut.transform(_opacity.value.clamp(0.0, 1.0)),
        child: ClipRect(
          child: Align(alignment: Alignment.topCenter, heightFactor: math.max(0.0, _height.value), child: child),
        ),
      ),
    );
  }
}
