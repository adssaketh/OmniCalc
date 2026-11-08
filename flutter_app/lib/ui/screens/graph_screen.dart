import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show InputBorder, InputDecoration, Material, MaterialType, TextField;
import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';

import '../../engine/evaluator.dart';
import '../../engine/js_number.dart';
import '../../engine/types.dart';
import '../../services/feedback_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../icons/lucide_icon.dart';
import '../shell/intrinsic_cache.dart';
import '../widgets/pressable.dart';
import 'screen_utils.dart';

/// Initial `scale` (pixels per unit) of GraphScreen.tsx, and the clamp used by the zoom buttons and the wheel.
const double kGraphDefaultScale = 40;
const double kGraphMinScale = 10;
const double kGraphMaxScale = 250;

/// GraphScreen.tsx sizes the canvas buffer as `rect.size * devicePixelRatio`, scales the context by the same ratio, and
/// then draws with `canvas.width` / `canvas.height` (the buffer size, not the CSS size). On a phone with a ratio above 1
/// the plane's origin therefore lands at `cssSize * ratio / 2`, outside the visible canvas, while the coordinates tooltip
/// uses `clientWidth / 2`. That cannot be what the author meant, so by default the plane is laid out at the CSS size (what
/// the page shows at a ratio of 1). Set this to true to reproduce the buffer-size layout literally.
const bool kGraphReproduceWebPixelRatioQuirk = false;

/// `presets` of GraphScreen.tsx: label and expression, in order.
const List<({String label, String expr})> graphPresets = [
  (label: 'sin(x)', expr: 'sin(x)'),
  (label: 'cos(x)', expr: 'cos(x)'),
  (label: 'tan(x)', expr: 'tan(x)'),
  (label: 'x²', expr: 'x^2'),
  (label: 'x³', expr: 'x^3'),
  (label: '√x', expr: 'sqrt(x)'),
  (label: '1/x', expr: '1/x'),
  (label: 'eˣ', expr: 'e^x'),
  (label: 'ln(x)', expr: 'ln(x)'),
];

/// A grid-line label: the text and the left end of its baseline (`ctx.fillText(text, x, y)`).
class GraphLabel {
  const GraphLabel(this.text, this.at);

  final String text;
  final Offset at;
}

/// One grid line: its x (vertical lines) or y (horizontal lines), and the label drawn beside it unless the unit value
/// reads `'0'`.
class GraphGridLine {
  const GraphGridLine(this.pos, this.label);

  final double pos;
  final GraphLabel? label;
}

/// The origin on the canvas: `ox = width / 2 + origin.x`, `oy = height / 2 + origin.y`.
Offset graphOrigin(double width, double height, Offset origin) => Offset(width / 2 + origin.dx, height / 2 + origin.dy);

/// The vertical grid: `for (let x = ox % step; x < width; x += step)`. JavaScript's `%` keeps the sign of the dividend, so
/// [double.remainder] (not Dart's `%`) is the same operator, and the position is advanced by repeated addition like the
/// loop does. The label is `((x - ox) / scale).toFixed(0)` at `(x + 3, oy - 4)`; `'-0'` (a tiny negative) is drawn, only
/// the exact string `'0'` is skipped.
List<GraphGridLine> graphVerticalLines(double width, double ox, double oy, double scale) {
  final out = <GraphGridLine>[];
  final step = scale;
  for (var x = ox.remainder(step); x < width; x += step) {
    final unitVal = jsToFixed((x - ox) / scale, 0);
    out.add(GraphGridLine(x, unitVal != '0' ? GraphLabel(unitVal, Offset(x + 3, oy - 4)) : null));
  }
  return out;
}

/// The horizontal grid: `for (let y = oy % step; y < height; y += step)`, label `(-(y - oy) / scale).toFixed(0)` at
/// `(ox + 4, y - 3)`.
List<GraphGridLine> graphHorizontalLines(double height, double ox, double oy, double scale) {
  final out = <GraphGridLine>[];
  final step = scale;
  for (var y = oy.remainder(step); y < height; y += step) {
    final unitVal = jsToFixed(-(y - oy) / scale, 0);
    out.add(GraphGridLine(y, unitVal != '0' ? GraphLabel(unitVal, Offset(ox + 4, y - 3)) : null));
  }
  return out;
}

/// The curve: every second pixel column from 0 to [width], `evaluateFunction(expr, (px - ox) / scale, 'rad')`; a value that
/// is not finite, or whose `py` is outside `[-100, height + 100]`, ends the current piece. Each piece is one sub-path
/// (`moveTo` then `lineTo`s); a piece of a single point draws nothing.
List<List<Offset>> graphCurve(String expr, double width, double height, double ox, double oy, double scale) {
  final pieces = <List<Offset>>[];
  List<Offset>? current;
  for (var px = 0; px <= width; px += 2) {
    final mathX = (px - ox) / scale;
    final mathY = MathEvaluator.evaluateFunction(expr, mathX, AngleMode.rad);
    if (!mathY.isNaN && mathY.isFinite) {
      final py = oy - mathY * scale;
      if (py >= -100 && py <= height + 100) {
        final p = Offset(px.toDouble(), py);
        if (current == null) {
          current = [p];
          pieces.add(current);
        } else {
          current.add(p);
        }
      } else {
        current = null;
      }
    } else {
      current = null;
    }
  }
  return pieces;
}

/// The point of the curve under the cursor, `(mx, oy - f(x) * scale)`, or null when `f` is not finite there.
Offset? graphCursorPoint(String expr, double mx, double ox, double oy, double scale) {
  final cursorX = (mx - ox) / scale;
  final cursorY = MathEvaluator.evaluateFunction(expr, cursorX, AngleMode.rad);
  if (!cursorY.isNaN && cursorY.isFinite) return Offset(mx, oy - cursorY * scale);
  return null;
}

/// The x of the coordinates tooltip: `((mouse.x - (clientWidth / 2 + origin.x)) / scale).toFixed(2)`.
String graphTooltipX(double mx, double clientWidth, double originX, double scale) =>
    jsToFixed((mx - (clientWidth / 2 + originX)) / scale, 2);

/// The y of the coordinates tooltip: `evaluateFunction(expr, x, 'rad').toFixed(2)` at the same x.
String graphTooltipY(String expr, double mx, double clientWidth, double originX, double scale) =>
    jsToFixed(MathEvaluator.evaluateFunction(expr, (mx - (clientWidth / 2 + originX)) / scale, AngleMode.rad), 2);

/// Everything `drawGraph` computes that does not depend on the cursor: the grid and the curve.
class GraphFrame {
  const GraphFrame({
    required this.width,
    required this.height,
    required this.ox,
    required this.oy,
    required this.scale,
    required this.vertical,
    required this.horizontal,
    required this.curve,
  });

  factory GraphFrame.compute({
    required String expr,
    required double width,
    required double height,
    required Offset origin,
    required double scale,
  }) {
    final o = graphOrigin(width, height, origin);
    return GraphFrame(
      width: width,
      height: height,
      ox: o.dx,
      oy: o.dy,
      scale: scale,
      vertical: graphVerticalLines(width, o.dx, o.dy, scale),
      horizontal: graphHorizontalLines(height, o.dx, o.dy, scale),
      curve: graphCurve(expr, width, height, o.dx, o.dy, scale),
    );
  }

  /// `canvas.width` / `canvas.height` (what the drawing code calls `width` and `height`).
  final double width;
  final double height;
  final double ox;
  final double oy;

  /// Pixels per unit.
  final double scale;
  final List<GraphGridLine> vertical;
  final List<GraphGridLine> horizontal;
  final List<List<Offset>> curve;
}

/// The colours `drawGraph` resolves per frame: `isDark` picks the grid, label, axis and crosshair alphas; the background
/// is `--m3-surface-container-lowest` and the curve `--m3-primary`.
class GraphColors {
  GraphColors(M3Tokens t)
      : background = t.surfaceContainerLowest,
        grid = t.isDark ? const Color.fromRGBO(255, 255, 255, 0.08) : const Color.fromRGBO(0, 0, 0, 0.07),
        text = t.isDark ? const Color.fromRGBO(255, 255, 255, 0.45) : const Color.fromRGBO(0, 0, 0, 0.55),
        axis = t.isDark ? const Color.fromRGBO(255, 255, 255, 0.35) : const Color.fromRGBO(0, 0, 0, 0.35),
        curve = t.primary,
        cross = t.isDark ? const Color.fromRGBO(255, 255, 255, 0.2) : const Color.fromRGBO(0, 0, 0, 0.2);

  final Color background;
  final Color grid;
  final Color text;
  final Color axis;
  final Color curve;
  final Color cross;

  /// The point on the curve (`ctx.fillStyle = '#10b981'`).
  static const Color point = Color(0xFF10B981);
}

/// Draws the canvas of GraphScreen.tsx in the same order: background, vertical grid (line, then label), horizontal grid,
/// the two axes (1.5 px), the curve (2.5 px, miter joins, butt caps like the canvas defaults), then the crosshair (a
/// 4.5 px dot and two `[3, 3]` dashed lines) when the cursor is over the curve.
class GraphPainter extends CustomPainter {
  GraphPainter({required this.frame, required this.colors, this.mouse, this.cursorPoint});

  final GraphFrame frame;
  final GraphColors colors;

  /// `mouseCoord` (canvas-local), null when the cursor is not over the canvas.
  final Offset? mouse;

  /// [graphCursorPoint] at the mouse x, null when `f` is not finite there.
  final Offset? cursorPoint;

  static final Map<String, TextPainter> _labelCache = <String, TextPainter>{};

  static TextPainter _label(String text, Color color) {
    final key = '${color.toARGB32()}|$text';
    final hit = _labelCache[key];
    if (hit != null) return hit;
    if (_labelCache.length > 400) {
      for (final p in _labelCache.values) {
        p.dispose();
      }
      _labelCache.clear();
    }
    final tp = TextPainter(
      text: TextSpan(text: text, style: appText(size: 10, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    return _labelCache[key] = tp;
  }

  /// `ctx.fillText(text, at.dx, at.dy)`: [at] is the left end of the alphabetic baseline.
  static void _fillText(Canvas canvas, GraphLabel label, Color color) {
    final tp = _label(label.text, color);
    final baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    tp.paint(canvas, Offset(label.at.dx, label.at.dy - baseline));
  }

  Paint _stroke(double width, Color color) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeMiterLimit = 10
    ..color = color
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final f = frame;
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    canvas.drawRect(Rect.fromLTWH(0, 0, f.width, f.height), Paint()..color = colors.background);

    final gridPaint = _stroke(1, colors.grid);
    for (final line in f.vertical) {
      canvas.drawLine(Offset(line.pos, 0), Offset(line.pos, f.height), gridPaint);
      if (line.label != null) _fillText(canvas, line.label!, colors.text);
    }
    for (final line in f.horizontal) {
      canvas.drawLine(Offset(0, line.pos), Offset(f.width, line.pos), gridPaint);
      if (line.label != null) _fillText(canvas, line.label!, colors.text);
    }

    final axisPaint = _stroke(1.5, colors.axis);
    canvas.drawLine(Offset(0, f.oy), Offset(f.width, f.oy), axisPaint);
    canvas.drawLine(Offset(f.ox, 0), Offset(f.ox, f.height), axisPaint);

    final path = Path();
    for (final piece in f.curve) {
      path.moveTo(piece.first.dx, piece.first.dy);
      for (var i = 1; i < piece.length; i++) {
        path.lineTo(piece[i].dx, piece[i].dy);
      }
    }
    canvas.drawPath(path, _stroke(2.5, colors.curve));

    final m = mouse;
    final c = cursorPoint;
    if (m != null && c != null) {
      canvas.drawCircle(c, 4.5, Paint()..color = GraphColors.point..isAntiAlias = true);
      final dashes = Path();
      _dash(dashes, Offset(m.dx, 0), Offset(m.dx, f.height));
      _dash(dashes, Offset(0, c.dy), Offset(f.width, c.dy));
      canvas.drawPath(dashes, _stroke(1, colors.cross));
    }
    canvas.restore();
  }

  /// `setLineDash([3, 3])`: 3 px on, 3 px off, starting "on" at the start of each sub-path.
  static void _dash(Path path, Offset a, Offset b) {
    final len = (b - a).distance;
    if (len == 0 || !len.isFinite) return;
    final dir = (b - a) / len;
    for (var d = 0.0; d < len; d += 6) {
      final end = math.min(d + 3, len);
      path.moveTo(a.dx + dir.dx * d, a.dy + dir.dy * d);
      path.lineTo(a.dx + dir.dx * end, a.dy + dir.dy * end);
    }
  }

  @override
  bool shouldRepaint(GraphPainter old) => true;
}

/// Port of GraphScreen.tsx: a function bar, nine presets and a pannable, zoomable plot with a coordinates readout.
class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  final TextEditingController _expression = TextEditingController(text: 'sin(x)');
  String _activeExpr = 'sin(x)';

  double _scale = kGraphDefaultScale;
  Offset _origin = Offset.zero;
  bool _isDragging = false;

  /// `dragStart`: the pointer position (window coordinates) at the start of the drag minus the origin then.
  Offset _dragStart = Offset.zero;

  /// `mouseCoord`: the cursor, relative to the canvas.
  Offset? _mouse;

  final Set<int> _touches = <int>{};
  bool _multiTouch = false;

  ({String expr, double width, double height, Offset origin, double scale})? _frameKey;
  GraphFrame? _frame;

  @override
  void dispose() {
    _expression.dispose();
    super.dispose();
  }

  void _sound(ClickType type) => playScreenSound(context, type);

  void _plot() {
    _sound(ClickType.op);
    setState(() => _activeExpr = _expression.text);
  }

  void _reset() {
    _sound(ClickType.toggle);
    setState(() {
      _scale = kGraphDefaultScale;
      _origin = Offset.zero;
    });
  }

  void _selectPreset(String expr) {
    _sound(ClickType.toggle);
    _expression.value = TextEditingValue(text: expr, selection: TextSelection.collapsed(offset: expr.length));
    setState(() => _activeExpr = expr);
  }

  void _zoomIn() {
    _sound(ClickType.toggle);
    setState(() => _scale = math.min(kGraphMaxScale, _scale * 1.25));
  }

  void _zoomOut() {
    _sound(ClickType.toggle);
    setState(() => _scale = math.max(kGraphMinScale, _scale / 1.25));
  }

  // ---- pointer handling (the mouse and touch handlers of the canvas) ----------------------------------------------

  bool _isTouch(PointerEvent e) => e.kind == PointerDeviceKind.touch;

  void _onPointerDown(PointerDownEvent e) {
    if (_isTouch(e)) {
      _touches.add(e.pointer);
      // `handleTouchStart` only reacts to a single finger
      if (_touches.length != 1) {
        _multiTouch = true;
        return;
      }
    }
    setState(() {
      _isDragging = true;
      _dragStart = e.position - _origin;
    });
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_isTouch(e) && _touches.length != 1) return;
    setState(() {
      _mouse = e.localPosition;
      if (_isDragging) _origin = e.position - _dragStart;
    });
  }

  void _onPointerUp(PointerUpEvent e) {
    if (_isTouch(e)) {
      _touches.remove(e.pointer);
      final last = _touches.isEmpty;
      final single = !_multiTouch;
      if (last) _multiTouch = false;
      setState(() {
        _isDragging = false;
        // a tap ends with the browser's emulated mouse move to the touch point; a drag already left the cursor there
        if (last && single) _mouse = e.localPosition;
      });
      return;
    }
    setState(() => _isDragging = false);
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (_isTouch(e)) {
      _touches.remove(e.pointer);
      if (_touches.isEmpty) _multiTouch = false;
    }
    setState(() => _isDragging = false);
  }

  void _onPointerSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    // `e.preventDefault()` + the wheel zoom: registering keeps an outer scrollable from scrolling the page as well
    GestureBinding.instance.pointerSignalResolver.register(e, (event) {
      final dy = (event as PointerScrollEvent).scrollDelta.dy;
      final zoomFactor = dy < 0 ? 1.15 : 0.85;
      setState(() => _scale = math.min(kGraphMaxScale, math.max(kGraphMinScale, _scale * zoomFactor)));
    });
  }

  void _onHover(PointerHoverEvent e) => setState(() => _mouse = e.localPosition);

  void _onExit(PointerExitEvent e) => setState(() {
        _isDragging = false;
        _mouse = null;
      });

  // ---- build --------------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final bp = Breakpoints.of(context);
    return CachedIntrinsicHeight(
      estimate: 700,
      measureNatural: true,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: bp.xl ? 1152 : 1024),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Container(
              // `w-full relative rounded-3xl p-5 sm:p-7 overflow-hidden flex flex-col gap-5` on surface-container-low
              clipBehavior: Clip.hardEdge,
              padding: EdgeInsets.all(bp.pick(20.0, sm: 28.0)),
              decoration: BoxDecoration(color: t.surfaceContainerLow, borderRadius: const BorderRadius.all(Radius.circular(24))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _functionBar(t, bp),
                  const SizedBox(height: 20),
                  _presetRow(t),
                  const SizedBox(height: 20),
                  _plotter(context, t, bp),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// `flex flex-col sm:flex-row items-center gap-2.5`: the f(x) input and, beside (or below) it, Plot and Reset.
  Widget _functionBar(M3Tokens t, Breakpoints bp) {
    final style = appText(size: 16, color: t.onSurface, height: 24 / 16, tabular: true);
    final input = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: t.surfaceContainer, borderRadius: const BorderRadius.all(Radius.circular(16))),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 6),
            child: Text(
              'f(x) =',
              style: appText(size: 14, weight: FontWeight.w600, color: t.onSurfaceVariant, height: 20 / 14, tabular: true),
            ),
          ),
          Expanded(
            child: Material(
              type: MaterialType.transparency,
              child: TextField(
                key: const ValueKey('graph-input'),
                controller: _expression,
                style: style,
                cursorColor: t.onSurface,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _plot(),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'e.g. sin(x) * 2',
                  hintStyle: style.copyWith(color: t.onSurface.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final plot = Pressable(
      key: const ValueKey('graph-plot'),
      onTap: _plot,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: t.primary, borderRadius: const BorderRadius.all(Radius.circular(12))),
        child: Text(
          'Plot Function',
          maxLines: 1,
          softWrap: false,
          style: appText(size: 12, weight: FontWeight.w600, color: t.onPrimary, height: 16 / 12),
        ),
      ),
    );
    final reset = Pressable(
      key: const ValueKey('graph-reset'),
      onTap: _reset,
      pressedScale: 0.9,
      child: Semantics(
        button: true,
        label: 'Reset View',
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: t.surfaceContainer, borderRadius: const BorderRadius.all(Radius.circular(12))),
          child: LucideIcon(LucideIconId.rotateCcw, color: t.onSurface, size: 16),
        ),
      ),
    );

    if (bp.sm) {
      return Row(
        children: [
          Expanded(child: input),
          const SizedBox(width: 10),
          plot,
          const SizedBox(width: 8),
          reset,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        input,
        const SizedBox(height: 10),
        Row(children: [Expanded(child: plot), const SizedBox(width: 8), reset]),
      ],
    );
  }

  /// `flex flex-wrap items-center gap-2 text-xs`: the caption and the nine presets.
  Widget _presetRow(M3Tokens t) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(
            'Function Presets:',
            style: appText(size: 12, weight: FontWeight.w500, color: t.onSurfaceVariant, height: 16 / 12),
          ),
        ),
        for (final p in graphPresets) _preset(t, p.label, p.expr),
      ],
    );
  }

  Widget _preset(M3Tokens t, String label, String expr) {
    final active = _activeExpr == expr;
    return Pressable(
      key: ValueKey('graph-preset-$label'),
      onTap: () => _selectPreset(expr),
      child: AnimatedContainer(
        duration: kTailwindDuration,
        curve: kTailwindEase,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? t.primaryContainer : t.surfaceContainer,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: AnimatedDefaultTextStyle(
          duration: kTailwindDuration,
          curve: kTailwindEase,
          style: appText(
            size: 12,
            weight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? t.onPrimaryContainer : t.onSurfaceVariant,
            height: 16 / 12,
            tabular: true,
          ),
          child: Text(label, maxLines: 1, softWrap: false),
        ),
      ),
    );
  }

  /// `relative w-full h-[360px] sm:h-[420px] md:h-[500px] lg:h-[560px] rounded-2xl overflow-hidden`.
  Widget _plotter(BuildContext context, M3Tokens t, Breakpoints bp) {
    final h = bp.pick(360.0, sm: 420.0, md: 500.0, lg: 560.0);
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: Container(
        height: h,
        color: t.surfaceContainerLowest,
        child: LayoutBuilder(
          builder: (context, c) => Stack(
            children: [
              Positioned.fill(child: _canvas(context, t, c.maxWidth, c.maxHeight)),
              Positioned(right: 12, bottom: 12, child: _zoomControls(t)),
              if (_mouse != null) Positioned(left: 12, top: 12, child: _tooltip(t, c.maxWidth)),
            ],
          ),
        ),
      ),
    );
  }

  GraphFrame _frameFor(double width, double height) {
    final key = (expr: _activeExpr, width: width, height: height, origin: _origin, scale: _scale);
    if (_frame == null || _frameKey != key) {
      _frame = GraphFrame.compute(expr: _activeExpr, width: width, height: height, origin: _origin, scale: _scale);
      _frameKey = key;
    }
    return _frame!;
  }

  Widget _canvas(BuildContext context, M3Tokens t, double cssW, double cssH) {
    // `canvas.width = rect.width * ratio` is truncated by the canvas to a whole number
    final k = kGraphReproduceWebPixelRatioQuirk ? MediaQuery.devicePixelRatioOf(context) : 1.0;
    final width = (cssW * k).floorToDouble();
    final height = (cssH * k).floorToDouble();
    final frame = _frameFor(width, height);
    final m = _mouse;
    final cursor = m == null ? null : graphCursorPoint(_activeExpr, m.dx, frame.ox, frame.oy, _scale);
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      // `touch-none`: a finger that starts on the plot pans it, it never scrolls the page
      gestures: <Type, GestureRecognizerFactory>{
        EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
          () => EagerGestureRecognizer(),
          (_) {},
        ),
      },
      child: MouseRegion(
        cursor: _isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
        onHover: _onHover,
        onExit: _onExit,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          onPointerSignal: _onPointerSignal,
          child: CustomPaint(
            key: const ValueKey('graph-canvas'),
            size: Size.infinite,
            painter: GraphPainter(frame: frame, colors: GraphColors(t), mouse: m, cursorPoint: cursor),
          ),
        ),
      ),
    );
  }

  /// `absolute bottom-3 right-3 flex items-center gap-1.5 p-1 rounded-full` on surface-container-high.
  Widget _zoomControls(M3Tokens t) {
    Widget button(String key, String label, LucideIconId icon, VoidCallback onTap) {
      return Pressable(
        key: ValueKey(key),
        onTap: onTap,
        pressedScale: 0.9,
        animated: false,
        child: Semantics(
          button: true,
          label: label,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: LucideIcon(icon, color: t.onSurface, size: 16),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: t.surfaceContainerHigh, borderRadius: const BorderRadius.all(Radius.circular(999))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button('graph-zoom-in', 'Zoom In', LucideIconId.zoomIn, _zoomIn),
          const SizedBox(width: 6),
          button('graph-zoom-out', 'Zoom Out', LucideIconId.zoomOut, _zoomOut),
        ],
      ),
    );
  }

  /// `absolute top-3 left-3 px-3 py-1.5 rounded-full font-mono text-xs flex items-center gap-2`: crosshair icon, x, dot, y.
  Widget _tooltip(M3Tokens t, double cssW) {
    final m = _mouse!;
    // `canvasRef.current.clientWidth` is a whole number
    final clientWidth = cssW.roundToDouble();
    final style = appText(size: 12, color: t.onSurface, height: 16 / 12, tabular: true);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: t.surfaceContainerHigh, borderRadius: const BorderRadius.all(Radius.circular(999))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LucideIcon(LucideIconId.crosshair, color: t.primary, size: 14),
          const SizedBox(width: 8),
          Text('x: ${graphTooltipX(m.dx, clientWidth, _origin.dx, _scale)}', key: const ValueKey('graph-tooltip-x'), style: style),
          const SizedBox(width: 8),
          Text('·', style: style),
          const SizedBox(width: 8),
          Text(
            'y: ${graphTooltipY(_activeExpr, m.dx, clientWidth, _origin.dx, _scale)}',
            key: const ValueKey('graph-tooltip-y'),
            style: style,
          ),
        ],
      ),
    );
  }
}
