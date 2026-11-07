import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../../theme/css_transition.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';

/// `TabItem` of SwipeableTabContainer.tsx. The web app passes a lucide icon component; here [iconBuilder] receives the
/// colour and the size (16, or 14 when compact) the container wants.
class TabItem {
  const TabItem({required this.id, required this.label, this.iconBuilder, this.badge});

  final String id;
  final String label;
  final Widget Function(Color color, double size)? iconBuilder;
  final String? badge;
}

/// The marker of the `.no-swipe` class / `data-no-swipe="true"` attribute: a touch that starts inside it never swipes
/// the tabs (sliders, the graph canvas and similar).
class NoSwipe extends SingleChildRenderObjectWidget {
  const NoSwipe({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => RenderNoSwipe();
}

class RenderNoSwipe extends RenderProxyBox {
  RenderNoSwipe([RenderBox? child]) : super(child);
}

const Cubic _glide = Cubic(0.2, 0.9, 0.2, 1);

/// Port of SwipeableTabContainer.tsx: a gliding pill tab bar plus a content area that follows the finger.
class SwipeableTabContainer extends StatefulWidget {
  const SwipeableTabContainer({
    super.key,
    required this.tabs,
    required this.activeTabId,
    required this.onSelectTab,
    required this.child,
    this.compact = false,
    this.showNavButtons = false,
    this.tabBarBottomPadding,
    this.tabBarBottomMargin,
  });

  final List<TabItem> tabs;
  final String activeTabId;
  final ValueChanged<String> onSelectTab;
  final Widget child;
  final bool compact;
  final bool showNavButtons;

  /// `tabBarClassName` replaces the default `pb-2 mb-3 sm:mb-4` (compact: `pb-1 mb-2`); these two stand in for it.
  final double? tabBarBottomPadding;
  final double? tabBarBottomMargin;

  @override
  State<SwipeableTabContainer> createState() => _SwipeableTabContainerState();
}

class _SwipeableTabContainerState extends State<SwipeableTabContainer> with TickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _rowKey = GlobalKey();
  final GlobalKey _contentKey = GlobalKey();
  final Map<String, GlobalKey> _btnKeys = {};

  late final CssTransitionValue _offset; // translate3d(dragOffset px)
  late final CssTransitionValue _opacity;
  late final CssTransitionValue _pillLeft;
  late final CssTransitionValue _pillWidth;
  late final CssTransitionValue _dragP; // 0 -> 1 while dragging: pill scale and glow, 180 ms

  // gesture state
  int? _pointer;
  Offset? _start;
  final List<_Sample> _samples = [];
  _Lock? _lock;
  double _currentOffset = 0;
  bool _isDragging = false;
  Duration _lastWheel = const Duration(days: -1);

  int get _activeIndex {
    final i = widget.tabs.indexWhere((t) => t.id == widget.activeTabId);
    return i >= 0 ? i : 0;
  }

  @override
  void initState() {
    super.initState();
    const t300 = Duration(milliseconds: 300);
    _offset = CssTransitionValue(vsync: this, duration: t300, curve: _glide);
    _opacity = CssTransitionValue(vsync: this, duration: t300, curve: Curves.ease, initial: 1);
    _pillLeft = CssTransitionValue(vsync: this, duration: t300, curve: _glide);
    _pillWidth = CssTransitionValue(vsync: this, duration: t300, curve: _glide);
    _dragP = CssTransitionValue(vsync: this, duration: const Duration(milliseconds: 180), curve: _glide);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPill(first: true);
      _scrollActiveIntoView(smooth: true);
    });
  }

  @override
  void didUpdateWidget(SwipeableTabContainer old) {
    super.didUpdateWidget(old);
    if (old.activeTabId != widget.activeTabId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollActiveIntoView(smooth: true));
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _offset.dispose();
    _opacity.dispose();
    _pillLeft.dispose();
    _pillWidth.dispose();
    _dragP.dispose();
    super.dispose();
  }

  // ---- measuring -------------------------------------------------------------------------------------------------

  ({double left, double width})? _measure(String id) {
    final btn = _btnKeys[id]?.currentContext?.findRenderObject() as RenderBox?;
    final row = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    if (btn == null || row == null || !btn.attached || !row.attached || !btn.hasSize) return null;
    final left = row.globalToLocal(btn.localToGlobal(Offset.zero)).dx;
    return (left: left, width: btn.size.width);
  }

  double get _containerWidth {
    final box = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    final w = box != null && box.hasSize ? box.size.width : 0.0;
    return w > 0 ? w : 360;
  }

  void _syncPill({bool first = false}) {
    if (!mounted) return;
    final m = _measure(widget.activeTabId);
    if (m == null) return;
    final instant = reduceMotion(context);
    _pillLeft.instant = instant;
    _pillWidth.instant = instant;

    var left = m.left;
    if (_isDragging && _currentOffset != 0) {
      final tabs = widget.tabs;
      final ai = _activeIndex;
      final dragRatio = -_currentOffset / _containerWidth;
      var adj = ai;
      if (_currentOffset < 0 && ai < tabs.length - 1) {
        adj = ai + 1;
      } else if (_currentOffset > 0 && ai > 0) {
        adj = ai - 1;
      }
      final next = _measure(tabs[adj].id);
      if (next != null) left = m.left + (next.left - m.left) * dragRatio.abs();
      // the transition list while dragging has no `left`, so it follows the finger without easing
      _pillLeft.jumpTo(left);
    } else if (first || _pillWidth.value == 0) {
      _pillLeft.jumpTo(left);
    } else {
      _pillLeft.animateTo(left);
    }
    if (first || _pillWidth.value == 0) {
      _pillWidth.jumpTo(m.width);
    } else {
      _pillWidth.animateTo(m.width);
    }
  }

  void _scrollActiveIntoView({required bool smooth}) {
    if (!mounted || !_scroll.hasClients) return;
    final btn = _btnKeys[widget.activeTabId]?.currentContext?.findRenderObject() as RenderBox?;
    final viewport = _scroll.position.context.storageContext.findRenderObject() as RenderBox?;
    if (btn == null || viewport == null || !btn.attached || !viewport.attached) return;
    final btnCenter = btn.localToGlobal(btn.size.center(Offset.zero)).dx;
    final viewCenter = viewport.localToGlobal(viewport.size.center(Offset.zero)).dx;
    final target = math.max(0.0, _scroll.offset + (btnCenter - viewCenter));
    final clamped = target.clamp(_scroll.position.minScrollExtent, _scroll.position.maxScrollExtent).toDouble();
    if (smooth && !reduceMotion(context)) {
      _scroll.animateTo(clamped, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _scroll.jumpTo(clamped);
    }
  }

  // ---- swipe -----------------------------------------------------------------------------------------------------

  /// `shouldIgnoreSwipe`: text fields, no-swipe areas, and anything that scrolls sideways under the finger.
  bool _shouldIgnoreSwipe(PointerDownEvent e) {
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, e.position, e.viewId);
    final content = _contentKey.currentContext?.findRenderObject();
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderEditable || target is RenderNoSwipe) return true;
      if (target is RenderAbstractViewport && !identical(target, content)) {
        final obj = target as RenderObject;
        // only viewports that sit inside the content area
        if (content != null && _isDescendant(obj, content)) {
          final viewport = target as RenderViewportBase;
          final offset = viewport.offset;
          if (viewport.axis == Axis.horizontal &&
              offset is ScrollPosition &&
              offset.hasContentDimensions &&
              offset.maxScrollExtent > 0) {
            return true;
          }
        }
      }
      if (identical(target, content)) break;
    }
    return false;
  }

  bool _isDescendant(RenderObject node, RenderObject ancestor) {
    RenderObject? n = node;
    while (n != null) {
      if (identical(n, ancestor)) return true;
      n = n.parent;
    }
    return false;
  }

  void _onPointerDown(PointerDownEvent e) {
    if (_pointer != null) return;
    if (e.kind == PointerDeviceKind.mouse && e.buttons != kPrimaryButton) return;
    if (_shouldIgnoreSwipe(e)) return;
    _pointer = e.pointer;
    _start = e.position;
    _samples
      ..clear()
      ..add(_Sample(e.position.dx, e.timeStamp));
    _lock = null;
    _currentOffset = 0;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (e.pointer != _pointer || _start == null) return;
    final dx = e.position.dx - _start!.dx;
    final dy = e.position.dy - _start!.dy;

    if (_lock == null) {
      final absDx = dx.abs();
      final absDy = dy.abs();
      if (absDx > 8 || absDy > 8) {
        if (absDy > absDx * 1.15) {
          _lock = _Lock.vertical;
          return;
        } else {
          _lock = _Lock.horizontal;
          _isDragging = true;
          _dragP.animateTo(1);
        }
      } else {
        return;
      }
    }
    if (_lock != _Lock.horizontal) return;

    _samples.add(_Sample(e.position.dx, e.timeStamp));
    if (_samples.length > 5) _samples.removeAt(0);

    var effective = dx;
    final first = _activeIndex == 0;
    final last = _activeIndex == widget.tabs.length - 1;
    if (first && dx > 0) {
      effective = dx * 0.35;
    } else if (last && dx < 0) {
      effective = dx * 0.35;
    }
    _currentOffset = effective;

    _offset.jumpTo(effective);
    _opacity.jumpTo(math.max(0.75, 1 - effective.abs() / 800));
    _syncPill();
  }

  void _onPointerUp(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;

    if (_lock == _Lock.horizontal) {
      var velocity = 0.0;
      if (_samples.length >= 2) {
        final oldest = _samples.first;
        final newest = _samples.last;
        final dt = (newest.time - oldest.time).inMicroseconds / 1000.0;
        if (dt > 0) velocity = (newest.x - oldest.x) / dt; // px/ms
      }

      final dx = _currentOffset;
      final width = _containerWidth;
      final distanceThreshold = width * 0.22;
      const velocityThreshold = 0.35;
      final ai = _activeIndex;
      var target = ai;
      if ((dx < -distanceThreshold || velocity < -velocityThreshold) && ai < widget.tabs.length - 1) {
        target = ai + 1;
      } else if ((dx > distanceThreshold || velocity > velocityThreshold) && ai > 0) {
        target = ai - 1;
      }

      final instant = reduceMotion(context);
      _offset.instant = instant;
      _opacity.instant = instant;
      _isDragging = false;
      _dragP.animateTo(0);
      _offset.animateTo(0);
      _opacity.animateTo(1);
      _currentOffset = 0;

      if (target != ai) {
        widget.onSelectTab(widget.tabs[target].id);
      } else {
        _syncPill();
      }
    } else {
      _isDragging = false;
      _dragP.animateTo(0);
      _offset.jumpTo(0);
      _opacity.jumpTo(1);
      _currentOffset = 0;
    }
    _start = null;
    _lock = null;
  }

  /// Trackpad horizontal swipe / tilt-wheel.
  void _onSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final now = e.timeStamp;
    if (now - _lastWheel < const Duration(milliseconds: 350)) return;
    final dx = e.scrollDelta.dx;
    final dy = e.scrollDelta.dy;
    if (dx.abs() > dy.abs() * 1.5 && dx.abs() > 35) {
      final ai = _activeIndex;
      if (dx > 35 && ai < widget.tabs.length - 1) {
        _lastWheel = now;
        widget.onSelectTab(widget.tabs[ai + 1].id);
      } else if (dx < -35 && ai > 0) {
        _lastWheel = now;
        widget.onSelectTab(widget.tabs[ai - 1].id);
      }
    }
  }

  void _scrollTabs(int dir) {
    if (!_scroll.hasClients) return;
    final target = (_scroll.offset + 160.0 * dir).clamp(_scroll.position.minScrollExtent, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target.toDouble(), duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  // ---- build -----------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 640;
    final compact = widget.compact;
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPill());
    _offset.instant = reduceMotion(context);

    final bottomPad = widget.tabBarBottomPadding ?? (compact ? 4.0 : 8.0);
    final bottomMargin = widget.tabBarBottomMargin ?? (compact ? 8.0 : (wide ? 16.0 : 12.0));
    final inset = compact ? 4.0 : 6.0;

    final tabBar = Padding(
      padding: EdgeInsets.only(bottom: bottomMargin),
      child: Row(
        children: [
          if (widget.showNavButtons && wide) _ChevronButton(left: true, color: t.onSurfaceVariant, hover: t.surfaceContainerHigh, onTap: () => _scrollTabs(-1)),
          Expanded(
            child: Listener(
              onPointerSignal: (e) {
                if (e is PointerScrollEvent && e.scrollDelta.dy.abs() > 5 && e.scrollDelta.dx.abs() < 10 && _scroll.hasClients) {
                  final target = (_scroll.offset + e.scrollDelta.dy).clamp(_scroll.position.minScrollExtent, _scroll.position.maxScrollExtent);
                  _scroll.jumpTo(target.toDouble());
                }
              },
              child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.only(bottom: bottomPad),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: wide ? 0 : box.maxWidth),
                    child: DecoratedBox(
                      key: _rowKey,
                      decoration: BoxDecoration(color: t.surfaceContainer, borderRadius: const BorderRadius.all(Radius.circular(9999))),
                      child: Padding(
                        padding: EdgeInsets.all(inset),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // the pill is the first child of the Stack, so it paints behind the buttons
                            Positioned.fill(
                              child: IgnorePointer(
                                child: AnimatedBuilder(
                                  animation: Listenable.merge([_pillLeft, _pillWidth, _dragP]),
                                  builder: (context, _) => _PillLayer(
                                    left: _pillLeft.value - inset,
                                    width: _pillWidth.value,
                                    drag: _dragP.value,
                                    color: t.primary,
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < widget.tabs.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 4),
                                  _TabButton(
                                    key: _btnKeys.putIfAbsent(widget.tabs[i].id, GlobalKey.new),
                                    tab: widget.tabs[i],
                                    active: widget.tabs[i].id == widget.activeTabId,
                                    compact: compact,
                                    onTap: () => widget.onSelectTab(widget.tabs[i].id),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.showNavButtons && wide) _ChevronButton(left: false, color: t.onSurfaceVariant, hover: t.surfaceContainerHigh, onTap: () => _scrollTabs(1)),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        tabBar,
        Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerUp,
          onPointerSignal: _onSignal,
          child: AnimatedBuilder(
            animation: Listenable.merge([_offset, _opacity]),
            builder: (context, child) => Opacity(
              opacity: _opacity.value.clamp(0.0, 1.0),
              child: Transform.translate(offset: Offset(_offset.value, 0), child: child),
            ),
            child: SizedBox(
              key: _contentKey,
              width: double.infinity,
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}

enum _Lock { horizontal, vertical }

class _Sample {
  const _Sample(this.x, this.time);
  final double x;
  final Duration time;
}

/// The gliding pill: `top-1.5 bottom-1.5` (compact `top-1 bottom-1`) of the row, so it fills the buttons' height.
class _PillLayer extends StatelessWidget {
  const _PillLayer({required this.left, required this.width, required this.drag, required this.color});

  final double left;
  final double width;
  final double drag;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (width <= 0) return const SizedBox.shrink();
    final scale = 1 + 0.06 * drag;
    // rest: 0 2px 8px primary @30%; dragging: 0 0 16px 2px primary + 0 4px 10px rgba(0,0,0,.25)
    final rest = [BoxShadow(color: color.withValues(alpha: 0.3), offset: const Offset(0, 2), blurRadius: 8)];
    final drag1 = [
      BoxShadow(color: color, blurRadius: 16, spreadRadius: 2),
      const BoxShadow(color: Color(0x40000000), offset: Offset(0, 4), blurRadius: 10),
    ];
    final shadows = BoxShadow.lerpList(rest, drag1, drag) ?? rest;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: left,
          top: 0,
          bottom: 0,
          width: width,
          child: Transform.scale(
            scale: scale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.all(Radius.circular(9999)),
                boxShadow: shadows,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatefulWidget {
  const _TabButton({super.key, required this.tab, required this.active, required this.compact, required this.onTap});

  final TabItem tab;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final tab = widget.tab;
    final active = widget.active;
    final compact = widget.compact;
    final fgTarget = active ? t.onPrimary : t.onSurfaceVariant;
    final instant = reduceMotion(context);

    return Semantics(
      button: true,
      selected: active,
      label: tab.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          // `active:scale-95` sits next to `transition-colors`, so the scale is instant
          child: Transform.scale(
            scale: _pressed ? 0.95 : 1,
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: fgTarget),
              duration: instant ? Duration.zero : const Duration(milliseconds: 200),
              curve: const Cubic(0.4, 0, 0.2, 1),
              builder: (context, fg, _) {
                final color = fg ?? fgTarget;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: compact ? 4 : 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tab.iconBuilder != null) ...[
                        tab.iconBuilder!(color, compact ? 14 : 16),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        tab.label,
                        maxLines: 1,
                        softWrap: false,
                        style: appText(size: 12, weight: active ? FontWeight.w700 : FontWeight.w500, color: color, height: 16 / 12),
                      ),
                      if (tab.badge != null) ...[
                        const SizedBox(width: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0.8),
                          decoration: BoxDecoration(
                            color: active ? t.onPrimary : t.surfaceContainerHigh,
                            borderRadius: const BorderRadius.all(Radius.circular(9999)),
                          ),
                          child: Text(
                            tab.badge!,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                              color: active ? t.primary : t.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ],
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

/// lucide `chevron-left` / `chevron-right` in a `p-1` round button, 14 px glyph, 80 % opacity.
class _ChevronButton extends StatefulWidget {
  const _ChevronButton({required this.left, required this.color, required this.hover, required this.onTap});

  final bool left;
  final Color color;
  final Color hover;
  final VoidCallback onTap;

  @override
  State<_ChevronButton> createState() => _ChevronButtonState();
}

class _ChevronButtonState extends State<_ChevronButton> {
  bool _pressed = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.left ? 'Scroll tabs left' : 'Scroll tabs right';
    return Padding(
      padding: EdgeInsets.only(left: widget.left ? 0 : 4, right: widget.left ? 4 : 0),
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: widget.onTap,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: Listener(
            onPointerDown: (_) => setState(() => _pressed = true),
            onPointerUp: (_) => setState(() => _pressed = false),
            onPointerCancel: (_) => setState(() => _pressed = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: Opacity(
                opacity: _hover ? 1 : 0.8,
                child: Transform.scale(
                  scale: _pressed ? 0.9 : 1,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _hover ? widget.hover : const Color(0x00000000),
                      borderRadius: const BorderRadius.all(Radius.circular(9999)),
                    ),
                    child: Center(
                      child: CustomPaint(size: const Size(14, 14), painter: _ChevronPainter(widget.left, widget.color)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter(this.left, this.color);
  final bool left;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final p = Path();
    if (left) {
      p
        ..moveTo(15 * s, 18 * s)
        ..lineTo(9 * s, 12 * s)
        ..lineTo(15 * s, 6 * s);
    } else {
      p
        ..moveTo(9 * s, 18 * s)
        ..lineTo(15 * s, 12 * s)
        ..lineTo(9 * s, 6 * s);
    }
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => old.left != left || old.color != color;
}
