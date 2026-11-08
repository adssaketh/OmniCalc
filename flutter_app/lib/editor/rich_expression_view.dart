import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import 'expr_doc.dart';
import 'rich_layout.dart';

/// The expression display with real superscripts and subscripts.
///
/// With [fit] it is AutoFitText.tsx: one line as large as possible, shrinking as it gets longer (same rule: measure at
/// [max], and when wider than the box minus 2 px use `max(min, floor(max * available / natural))`). Without [fit] it is
/// drawn at [max] and as wide as the text (landscape display, inside a horizontal scroll view).
///
/// For text without any group the line is one text run at the same style, so size and look equal the old
/// `AutoFitText`. The caret is drawn only when [showCaret] says so (the controller turns it on while the caret is
/// inside a group, was moved, or the expression has groups), so plain arithmetic looks exactly as before.
class RichExpressionView extends StatefulWidget {
  const RichExpressionView({
    super.key,
    required this.doc,
    required this.max,
    required this.color,
    this.min,
    this.fit = true,
    this.weight = FontWeight.w700,
    this.letterSpacingEm = -0.025,
    this.lineHeightPx,
    this.showCaret = false,
    this.caretColor,
    this.onCaretHit,
  });

  final ExprDoc doc;
  final double max;
  final double? min;
  final bool fit;
  final Color color;
  final FontWeight weight;
  final double letterSpacingEm;

  /// CSS-like line box in px for the base size (the line box scales with every group's size). Null keeps the
  /// 1.12 factor of AutoFitText.
  final double? lineHeightPx;
  final bool showCaret;
  final Color? caretColor;

  /// A tap on the line: where the caret should go.
  final void Function(CaretHit hit)? onCaretHit;

  @override
  State<RichExpressionView> createState() => _RichExpressionViewState();
}

class _RichExpressionViewState extends State<RichExpressionView> {
  final GlobalKey _leafKey = GlobalKey();
  Timer? _blink;
  bool _caretOn = true;
  int _seenVersion = -1;

  @override
  void initState() {
    super.initState();
    _syncBlink();
  }

  @override
  void didUpdateWidget(RichExpressionView old) {
    super.didUpdateWidget(old);
    _syncBlink();
  }

  void _syncBlink() {
    if (widget.doc.version != _seenVersion) {
      _seenVersion = widget.doc.version;
      _caretOn = true; // the caret is solid right after an edit or a move
      if (_blink != null) _restartBlink();
    }
    if (widget.showCaret && _blink == null) {
      _restartBlink();
    } else if (!widget.showCaret && _blink != null) {
      _blink!.cancel();
      _blink = null;
    }
  }

  void _restartBlink() {
    _blink?.cancel();
    _blink = Timer.periodic(const Duration(milliseconds: 530), (_) {
      if (mounted) setState(() => _caretOn = !_caretOn);
    });
  }

  @override
  void dispose() {
    _blink?.cancel();
    super.dispose();
  }

  void _tap(Offset local) {
    final cb = widget.onCaretHit;
    if (cb == null) return;
    final ro = _leafKey.currentContext?.findRenderObject();
    if (ro is RenderRichExpression) cb(ro.caretAt(local));
  }

  @override
  Widget build(BuildContext context) {
    final leaf = RichExpressionLeaf(
      key: _leafKey,
      doc: widget.doc,
      docVersion: widget.doc.version,
      max: widget.max,
      min: widget.min ?? widget.max,
      fit: widget.fit,
      color: widget.color,
      weight: widget.weight,
      letterSpacingEm: widget.letterSpacingEm,
      lineHeightPx: widget.lineHeightPx,
      showCaret: widget.showCaret,
      caretOn: _caretOn,
      caretColor: widget.caretColor ?? widget.color,
    );
    return Semantics(
      label: widget.doc.semanticsLabel,
      child: ExcludeSemantics(
        child: widget.onCaretHit == null
            ? leaf
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _tap(d.localPosition),
                child: leaf,
              ),
      ),
    );
  }
}

/// The drawing part of [RichExpressionView] (public so tests can find its render object).
class RichExpressionLeaf extends LeafRenderObjectWidget {
  const RichExpressionLeaf({
    super.key,
    required this.doc,
    required this.docVersion,
    required this.max,
    required this.min,
    required this.fit,
    required this.color,
    required this.weight,
    required this.letterSpacingEm,
    required this.lineHeightPx,
    required this.showCaret,
    required this.caretOn,
    required this.caretColor,
  });

  final ExprDoc doc;
  final int docVersion;
  final double max;
  final double min;
  final bool fit;
  final Color color;
  final FontWeight weight;
  final double letterSpacingEm;
  final double? lineHeightPx;
  final bool showCaret;
  final bool caretOn;
  final Color caretColor;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderRichExpression(
        doc: doc,
        docVersion: docVersion,
        max: max,
        min: min,
        fit: fit,
        color: color,
        weight: weight,
        letterSpacingEm: letterSpacingEm,
        lineHeightPx: lineHeightPx,
        showCaret: showCaret,
        caretOn: caretOn,
        caretColor: caretColor,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(BuildContext context, RenderRichExpression ro) {
    ro
      ..doc = doc
      ..docVersion = docVersion
      ..max = max
      ..min = min
      ..fit = fit
      ..color = color
      ..weight = weight
      ..letterSpacingEm = letterSpacingEm
      ..lineHeightPx = lineHeightPx
      ..textDirection = Directionality.of(context)
      ..caretColor = caretColor
      ..showCaret = showCaret
      ..caretOn = caretOn;
  }
}

class RenderRichExpression extends RenderBox {
  RenderRichExpression({
    required ExprDoc doc,
    required int docVersion,
    required double max,
    required double min,
    required bool fit,
    required Color color,
    required FontWeight weight,
    required double letterSpacingEm,
    required double? lineHeightPx,
    required bool showCaret,
    required bool caretOn,
    required Color caretColor,
    required TextDirection textDirection,
  })  : _doc = doc,
        _docVersion = docVersion,
        _max = max,
        _min = min,
        _fit = fit,
        _color = color,
        _weight = weight,
        _letterSpacingEm = letterSpacingEm,
        _lineHeightPx = lineHeightPx,
        _showCaret = showCaret,
        _caretOn = caretOn,
        _caretColor = caretColor,
        _textDirection = textDirection;

  ExprDoc _doc;
  int _docVersion;
  double _max;
  double _min;
  bool _fit;
  Color _color;
  FontWeight _weight;
  double _letterSpacingEm;
  double? _lineHeightPx;
  bool _showCaret;
  bool _caretOn;
  Color _caretColor;
  TextDirection _textDirection;

  final Map<double, RowLayout> _layouts = <double, RowLayout>{};

  /// Font size chosen by the last layout.
  double fontSize = 0;

  /// The engine string of the line being drawn (what the old `RenderAutoFitText.text` was).
  String get text => _doc.linear;

  /// Horizontal shift applied when the last paint right-aligned the line (negative when the line is wider than the box).
  double _paintDx = 0;

  void _invalidateLayout() {
    _layouts.clear();
    markNeedsLayout();
  }

  set doc(ExprDoc v) {
    if (identical(v, _doc)) return;
    _doc = v;
    _invalidateLayout();
  }

  set docVersion(int v) {
    if (v == _docVersion) return;
    _docVersion = v;
    _invalidateLayout();
  }

  set max(double v) {
    if (v == _max) return;
    _max = v;
    _invalidateLayout();
  }

  set min(double v) {
    if (v == _min) return;
    _min = v;
    markNeedsLayout();
  }

  set fit(bool v) {
    if (v == _fit) return;
    _fit = v;
    _invalidateLayout();
  }

  set color(Color v) {
    if (v == _color) return;
    _color = v;
    _invalidateLayout();
  }

  set weight(FontWeight v) {
    if (v == _weight) return;
    _weight = v;
    _invalidateLayout();
  }

  set letterSpacingEm(double v) {
    if (v == _letterSpacingEm) return;
    _letterSpacingEm = v;
    _invalidateLayout();
  }

  set lineHeightPx(double? v) {
    if (v == _lineHeightPx) return;
    _lineHeightPx = v;
    _invalidateLayout();
  }

  set textDirection(TextDirection v) {
    if (v == _textDirection) return;
    _textDirection = v;
    _invalidateLayout();
  }

  set showCaret(bool v) {
    if (v == _showCaret) return;
    _showCaret = v;
    markNeedsPaint();
  }

  set caretOn(bool v) {
    if (v == _caretOn) return;
    _caretOn = v;
    markNeedsPaint();
  }

  set caretColor(Color v) {
    if (v == _caretColor) return;
    _caretColor = v;
    markNeedsPaint();
  }

  TextStyle _style(double size) {
    final lh = _lineHeightPx;
    // with a line box in px the glyphs are centred in it (calcText); the box scales with the group's size
    final base = appText(
      size: size,
      weight: _weight,
      color: _color,
      letterSpacingEm: _letterSpacingEm,
      height: lh == null ? 1.12 : lh / _max,
      tabular: true,
    );
    return lh == null ? base : base.copyWith(leadingDistribution: TextLeadingDistribution.even);
  }

  RowLayout _layoutAt(double size) => _layouts.putIfAbsent(
        size,
        () => layoutRow(_doc.root, baseSize: size, styleFor: _style, textDirection: _textDirection),
      );

  /// The size AutoFitText.tsx `fit()` picks for a box of [boxWidth].
  double _sizeFor(double boxWidth) {
    if (!_fit) return _max;
    final available = boxWidth - 2;
    if (available <= 0) return _max;
    final natural = _layoutAt(_max).width;
    return natural > available ? math.max(_min, ((_max * available) / natural).floorToDouble()) : _max;
  }

  double _heightFor(double boxWidth) => _layoutAt(_sizeFor(boxWidth)).height;

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => _layoutAt(_max).width;

  @override
  double computeMinIntrinsicHeight(double width) => _heightFor(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _heightFor(width);

  /// Fit mode fills the box; fixed mode is as wide as the text (but never wider than the box).
  double _widthFor(BoxConstraints c) {
    final natural = _layoutAt(_max).width;
    if (_fit) return c.hasBoundedWidth ? c.maxWidth : natural;
    return c.hasBoundedWidth ? math.min(natural, c.maxWidth) : natural;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final w = _widthFor(constraints);
    return constraints.constrain(Size(w, _heightFor(w)));
  }

  @override
  void performLayout() {
    final w = _widthFor(constraints);
    fontSize = _sizeFor(w);
    size = constraints.constrain(Size(w, _layoutAt(fontSize).height));
  }

  RowLayout get _row => _layoutAt(fontSize == 0 ? _max : fontSize);

  double _alignDx(RowLayout row) {
    var dx = size.width - row.width; // right-aligned, like the old display
    if (_showCaret) {
      final caret = caretGeometry(row, _doc.path, _doc.offset);
      if (caret.x + dx < 0) dx = -caret.x + 2; // keep the caret in view when the line is clipped on the left
    }
    return dx;
  }

  /// The caret position a tap at [local] (box coordinates) means.
  CaretHit caretAt(Offset local) {
    final row = _row;
    return hitTest(row, local.dx - _alignDx(row), local.dy);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final row = _row;
    _paintDx = _alignDx(row);
    final canvas = context.canvas;
    canvas.save();
    canvas.clipRect(offset & size);
    final origin = Offset(offset.dx + _paintDx, offset.dy);
    paintRow(canvas, row, origin);
    if (_showCaret && _caretOn) {
      final caret = caretGeometry(row, _doc.path, _doc.offset);
      canvas.drawRect(caret.rect().shift(origin), Paint()..color = _caretColor);
    }
    canvas.restore();
  }

  @override
  bool hitTestSelf(Offset position) => true;
}
