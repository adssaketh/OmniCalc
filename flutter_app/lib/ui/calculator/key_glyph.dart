import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../editor/rich_layout.dart' show BigOp, bigOpWidthEm, paintBigOp;

/// The structure keys (∫ Σ ∏, fractions, roots, |x|, log with base) are drawn the way the display shows them once they
/// are typed: limit boxes above and below the sign and a body box after it, a box over a bar over a box, a box under a
/// radical. The label string keeps the `▭` character (screen reader text and tests look keys up by it); this file only
/// decides how that label is drawn.
enum KeyGlyphKind { integral, sigma, prod, fraction, mixedFraction, sqrt, cbrt, nRoot, abs, logBase }

KeyGlyphKind? keyGlyphKind(String label) => switch (label) {
      '∫▭▭' => KeyGlyphKind.integral,
      'Σ▭▭' => KeyGlyphKind.sigma,
      '∏▭▭' => KeyGlyphKind.prod,
      '▭/▭' => KeyGlyphKind.fraction,
      'a▭/▭' => KeyGlyphKind.mixedFraction,
      '√▭' => KeyGlyphKind.sqrt,
      '∛▭' => KeyGlyphKind.cbrt,
      'ⁿ√▭' => KeyGlyphKind.nRoot,
      '|▭|' => KeyGlyphKind.abs,
      'log▭▭' => KeyGlyphKind.logBase,
      _ => null,
    };

/// A structure drawn at font size [u] (its sign is about one em tall) in [color], using the surrounding text style for
/// the few letters it contains (`a`, `log`, the 3 of a cube root).
class KeyGlyph extends StatelessWidget {
  const KeyGlyph({super.key, required this.kind, required this.u, required this.color});

  final KeyGlyphKind kind;
  final double u;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.copyWith(color: color, fontWeight: FontWeight.w500, height: 1.0);
    final painter = _GlyphPainter(kind, u, color, style);
    return SizedBox(
      width: painter.size.width,
      height: painter.size.height,
      child: CustomPaint(painter: painter),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.kind, this.u, this.color, this.style) {
    stroke = math.max(1.0, 0.085 * u);
    size = _measure();
  }

  final KeyGlyphKind kind;
  final double u;
  final Color color;
  final TextStyle style;
  late final double stroke;
  late final Size size;

  // ---- shared pieces -------------------------------------------------------------------------------------------------

  Paint get _line => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = stroke
    ..strokeJoin = StrokeJoin.miter
    ..isAntiAlias = true;

  void _box(Canvas canvas, double x, double y, double w, double h) {
    canvas.drawRect(Rect.fromLTWH(x + stroke / 2, y + stroke / 2, w - stroke, h - stroke), _line);
  }

  TextPainter _text(String s, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style.copyWith(fontSize: fontSize)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return tp;
  }

  // Big operators: limit box, sign, limit box in a column, then the body box.
  double get _bigU => u * 1.15;
  double get _limit => 0.5 * _bigU;
  double get _gap => 0.07 * _bigU;
  double get _opH => 0.95 * _bigU;
  double get _bodyW => 0.6 * _bigU;

  BigOp? get _bigOp => switch (kind) {
        KeyGlyphKind.integral => BigOp.integral,
        KeyGlyphKind.sigma => BigOp.sigma,
        KeyGlyphKind.prod => BigOp.prod,
        _ => null,
      };

  // Fraction: box, bar, box.
  double get _fBox => 0.62 * u;
  double get _fGap => 0.1 * u;
  double get _fW => _fBox + 0.4 * u;
  double get _fH => _fBox + _fGap + stroke + _fGap + _fBox;

  // Roots: radical, then a box under the overline.
  double get _rBox => 0.62 * u;
  double get _rGap => 0.12 * u;
  double get _rW => 0.55 * u;
  double get _rH => stroke + _rGap + _rBox + 0.1 * u;
  double get _idxBox => 0.34 * u;

  Size _measure() {
    final big = _bigOp;
    if (big != null) {
      final colW = math.max(bigOpWidthEm(big) * _opH, _limit);
      return Size(colW + 0.14 * _bigU + _bodyW, _limit + _gap + _opH + _gap + _limit);
    }
    switch (kind) {
      case KeyGlyphKind.fraction:
        return Size(_fW, _fH);
      case KeyGlyphKind.mixedFraction:
        return Size(_text('a', u).width + 0.12 * u + _fW, _fH);
      case KeyGlyphKind.sqrt:
        return Size(_rW + 0.15 * u + _rBox + 0.15 * u, _rH);
      case KeyGlyphKind.cbrt:
        return Size(_text('3', 0.5 * u).width + 0.04 * u + _rW + 0.15 * u + _rBox + 0.15 * u, _rH);
      case KeyGlyphKind.nRoot:
        return Size(_idxBox + 0.04 * u + _rW + 0.15 * u + _rBox + 0.15 * u, _rH);
      case KeyGlyphKind.abs:
        return Size(_rBox + 0.5 * u, 1.0 * u);
      case KeyGlyphKind.logBase:
        final log = _text('log', u);
        return Size(log.width + 0.04 * u + _idxBox + 0.12 * u + _rBox, 1.35 * u);
      default:
        return Size.zero;
    }
  }

  // ---- painting ------------------------------------------------------------------------------------------------------

  @override
  void paint(Canvas canvas, Size _) {
    final big = _bigOp;
    if (big != null) {
      final colW = math.max(bigOpWidthEm(big) * _opH, _limit);
      final opW = bigOpWidthEm(big) * _opH;
      _box(canvas, (colW - _limit) / 2, 0, _limit, _limit);
      paintBigOp(canvas, big, Rect.fromLTWH((colW - opW) / 2, _limit + _gap, opW, _opH), color);
      _box(canvas, (colW - _limit) / 2, _limit + _gap + _opH + _gap, _limit, _limit);
      _box(canvas, colW + 0.14 * _bigU, _limit + _gap, _bodyW, _opH);
      return;
    }
    switch (kind) {
      case KeyGlyphKind.fraction:
        _fraction(canvas, 0);
      case KeyGlyphKind.mixedFraction:
        final a = _text('a', u);
        a.paint(canvas, Offset(0, (size.height - a.height) / 2));
        _fraction(canvas, a.width + 0.12 * u);
      case KeyGlyphKind.sqrt:
        _radical(canvas, 0);
      case KeyGlyphKind.cbrt:
        final three = _text('3', 0.5 * u);
        three.paint(canvas, const Offset(0, 0));
        _radical(canvas, three.width + 0.04 * u);
      case KeyGlyphKind.nRoot:
        _box(canvas, 0, 0, _idxBox, _idxBox);
        _radical(canvas, _idxBox + 0.04 * u);
      case KeyGlyphKind.abs:
        final bar = _line;
        canvas.drawLine(Offset(stroke / 2, 0), Offset(stroke / 2, size.height), bar);
        canvas.drawLine(Offset(size.width - stroke / 2, 0), Offset(size.width - stroke / 2, size.height), bar);
        _box(canvas, (size.width - _rBox) / 2, (size.height - _rBox) / 2, _rBox, _rBox);
      case KeyGlyphKind.logBase:
        final log = _text('log', u);
        final midY = size.height * 0.42;
        log.paint(canvas, Offset(0, midY - log.height / 2));
        _box(canvas, log.width + 0.04 * u, size.height - _idxBox, _idxBox, _idxBox);
        _box(canvas, log.width + 0.04 * u + _idxBox + 0.12 * u, midY - _rBox / 2, _rBox, _rBox);
      default:
        break;
    }
  }

  void _fraction(Canvas canvas, double x) {
    final bx = x + (_fW - _fBox) / 2;
    _box(canvas, bx, 0, _fBox, _fBox);
    final barY = _fBox + _fGap + stroke / 2;
    canvas.drawLine(Offset(x, barY), Offset(x + _fW, barY), _line);
    _box(canvas, bx, _fBox + _fGap + stroke + _fGap, _fBox, _fBox);
  }

  /// The radical sign starting at [x], its overline and the box under it.
  void _radical(Canvas canvas, double x) {
    final h = size.height;
    final path = Path()
      ..moveTo(x, h * 0.62)
      ..lineTo(x + _rW * 0.28, h * 0.54)
      ..lineTo(x + _rW * 0.55, h - stroke / 2)
      ..lineTo(x + _rW, stroke / 2)
      ..lineTo(size.width, stroke / 2);
    canvas.drawPath(path, _line);
    _box(canvas, x + _rW + 0.15 * u * 0.5, stroke + _rGap, _rBox, _rBox);
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.kind != kind || old.u != u || old.color != color || old.style != style;
}
