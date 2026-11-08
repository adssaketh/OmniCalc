import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';

/// Port of AutoFitText.tsx: one line of text that is as large as possible. It shrinks as it gets longer so the number
/// never gets cut off, and grows back when digits are deleted.
///
/// `fit` in the TSX measures the text at [max] and, when it is wider than the box (minus 2 px), uses
/// `max(min, floor(max * available / natural))`. Below [min] the line scrolls sideways in the web app and shows the
/// end of the text; here the text is right-aligned and clipped on the left, which also shows the newest digits (no
/// sideways drag at the smallest size, see PHASE4_NOTES.md).
///
/// Implemented as a render box (not a `LayoutBuilder`) so the shell can ask the screen for its intrinsic height.
class AutoFitText extends LeafRenderObjectWidget {
  const AutoFitText({
    super.key,
    required this.text,
    required this.max,
    required this.min,
    required this.color,
    this.weight = FontWeight.w700,
    this.letterSpacingEm = -0.025,
  });

  final String text;
  final double max;
  final double min;
  final Color color;
  final FontWeight weight;
  final double letterSpacingEm;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderAutoFitText(
        text: text,
        max: max,
        min: min,
        color: color,
        weight: weight,
        letterSpacingEm: letterSpacingEm,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(BuildContext context, RenderAutoFitText renderObject) {
    renderObject
      ..text = text
      ..max = max
      ..min = min
      ..color = color
      ..weight = weight
      ..letterSpacingEm = letterSpacingEm
      ..textDirection = Directionality.of(context);
  }
}

class RenderAutoFitText extends RenderBox {
  RenderAutoFitText({
    required String text,
    required double max,
    required double min,
    required Color color,
    required FontWeight weight,
    required double letterSpacingEm,
    required TextDirection textDirection,
  })  : _text = text,
        _max = max,
        _min = min,
        _color = color,
        _weight = weight,
        _letterSpacingEm = letterSpacingEm,
        _textDirection = textDirection;

  String _text;
  double _max;
  double _min;
  Color _color;
  FontWeight _weight;
  double _letterSpacingEm;
  TextDirection _textDirection;

  /// Font size chosen by the last layout.
  double fontSize = 0;

  String get text => _text;

  set text(String v) {
    if (v == _text) return;
    _text = v;
    markNeedsLayout();
  }

  set max(double v) {
    if (v == _max) return;
    _max = v;
    markNeedsLayout();
  }

  set min(double v) {
    if (v == _min) return;
    _min = v;
    markNeedsLayout();
  }

  set color(Color v) {
    if (v == _color) return;
    _color = v;
    markNeedsPaint();
  }

  set weight(FontWeight v) {
    if (v == _weight) return;
    _weight = v;
    markNeedsLayout();
  }

  set letterSpacingEm(double v) {
    if (v == _letterSpacingEm) return;
    _letterSpacingEm = v;
    markNeedsLayout();
  }

  set textDirection(TextDirection v) {
    if (v == _textDirection) return;
    _textDirection = v;
    markNeedsLayout();
  }

  TextPainter _painterAt(double size) {
    final p = TextPainter(
      text: TextSpan(
        text: _text,
        style: appText(
          size: size,
          weight: _weight,
          color: _color,
          letterSpacingEm: _letterSpacingEm,
          height: 1.12,
          tabular: true,
        ),
      ),
      textDirection: _textDirection,
      maxLines: 1,
    );
    p.layout();
    return p;
  }

  /// The size `fit()` of AutoFitText.tsx picks for a box of [boxWidth].
  double _fitSize(double boxWidth) {
    final available = boxWidth - 2;
    if (available <= 0) return _max;
    final natural = _painterAt(_max).width;
    return natural > available ? math.max(_min, ((_max * available) / natural).floorToDouble()) : _max;
  }

  double _heightFor(double boxWidth) => _painterAt(_fitSize(boxWidth)).height;

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => _painterAt(_max).width;

  @override
  double computeMinIntrinsicHeight(double width) => _heightFor(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _heightFor(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final w = constraints.hasBoundedWidth ? constraints.maxWidth : _painterAt(_max).width;
    return constraints.constrain(Size(w, _heightFor(w)));
  }

  @override
  void performLayout() {
    final w = constraints.hasBoundedWidth ? constraints.maxWidth : _painterAt(_max).width;
    fontSize = _fitSize(w);
    size = constraints.constrain(Size(w, _painterAt(fontSize).height));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final painter = _painterAt(fontSize == 0 ? _max : fontSize);
    final dx = offset.dx + size.width - painter.width;
    context.canvas.save();
    context.canvas.clipRect(offset & size);
    painter.paint(context.canvas, Offset(dx, offset.dy));
    context.canvas.restore();
  }

  @override
  bool hitTestSelf(Offset position) => true;
}
