import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'svg_paths_generated.dart';

enum LogoShape { squircle, circle }

/// `OmniCalcLogo` (src/components/OmniCalcLogo.tsx): a 1024 x 1024 artwork (silver plate, two dark round keys with a
/// minus and a plus, a tall green equals pill), drawn with the same coordinates, gradients and shadows.
class OmniCalcLogo extends StatelessWidget {
  const OmniCalcLogo({super.key, this.size = 32, this.shape = LogoShape.squircle});

  final double size;
  final LogoShape shape;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'OmniCalc Logo',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: RepaintBoundary(child: CustomPaint(painter: _LogoPainter(shape))),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter(this.shape);

  final LogoShape shape;

  static Color _c(int hex, [double a = 1]) => Color.fromRGBO((hex >> 16) & 0xFF, (hex >> 8) & 0xFF, hex & 0xFF, a);

  /// `linear-gradient` of the SVG in objectBoundingBox units from (0%,0%) to (0%,100%).
  static ui.Shader _vertical(Rect r, List<Color> colors, List<double> stops) =>
      ui.Gradient.linear(r.topCenter, r.bottomCenter, colors, stops);

  /// `radialGradient` in objectBoundingBox units (all uses are square boxes): centre at (cx, cy), radius `rad` of the width.
  static ui.Shader _radial(Rect r, double cx, double cy, double rad, List<Color> colors, List<double> stops) =>
      ui.Gradient.radial(Offset(r.left + r.width * cx, r.top + r.height * cy), r.width * rad, colors, stops);

  void _dropShadow(Canvas canvas, Path shape, double dy, double sigma, Color color) {
    canvas.drawPath(
      shape.shift(Offset(0, dy)),
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
    );
  }

  Path _union(List<Path> paths) {
    var out = paths.first;
    for (final p in paths.skip(1)) {
      out = Path.combine(PathOperation.union, out, p);
    }
    return out;
  }

  /// A white symbol capsule (`whiteSymbol` gradient) plus its specular highlight bar.
  void _capsule(Canvas canvas, Rect r, double radius, Rect highlight, double highlightRadius, double highlightAlpha) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    canvas.drawRRect(
      rr,
      Paint()..shader = _vertical(r, [_c(0xFFFFFF), _c(0xFDFDFD), _c(0xEAEDF2)], const [0.0, 0.6, 1.0]),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(highlight, Radius.circular(highlightRadius)),
      Paint()..color = Color.fromRGBO(255, 255, 255, highlightAlpha),
    );
  }

  void _darkButton(Canvas canvas, Offset center, Path highlight) {
    const r = 158.0;
    final box = Rect.fromCircle(center: center, radius: r);
    _dropShadow(canvas, Path()..addOval(box.inflate(2)), 14, 16, const Color.fromRGBO(0, 0, 0, 0.28));
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = _radial(
          box,
          0.38,
          0.32,
          0.65,
          [_c(0x3C3F49), _c(0x2A2C33), _c(0x212227), _c(0x18191D)],
          const [0.0, 0.45, 0.8, 1.0],
        ),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..shader = _vertical(
          box,
          [_c(0x555966), _c(0x363942), _c(0x1E2025), _c(0x121316)],
          const [0.0, 0.35, 0.85, 1.0],
        ),
    );
    canvas.drawPath(highlight, Paint()..color = const Color.fromRGBO(255, 255, 255, 0.16));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1024, size.height / 1024);
    const full = Rect.fromLTWH(0, 0, 1024, 1024);

    // Squircle / circle clip
    if (shape == LogoShape.circle) {
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: const Offset(512, 512), radius: 500)));
    } else {
      canvas.clipRRect(RRect.fromRectAndRadius(full, const Radius.circular(224)));
    }

    // Base background plate: soft silver vignette with a thin rim
    final vignette = _radial(
      full,
      0.5,
      0.45,
      0.65,
      [_c(0xF4F6F9), _c(0xEDF0F4), _c(0xE2E6EC)],
      const [0.0, 0.6, 1.0],
    );
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = _c(0xD5DCE6);
    if (shape == LogoShape.circle) {
      canvas.drawCircle(const Offset(512, 512), 500, Paint()..shader = vignette);
      canvas.drawCircle(const Offset(512, 512), 500, rim);
    } else {
      final rr = RRect.fromRectAndRadius(full, const Radius.circular(224));
      canvas.drawRRect(rr, Paint()..shader = vignette);
      canvas.drawRRect(rr, rim);
    }

    // 1. top left button: minus
    _darkButton(canvas, const Offset(328, 314), kLogoPathBuilders[0]());
    {
      const bar = Rect.fromLTWH(244, 293, 168, 42);
      _dropShadow(canvas, Path()..addRRect(RRect.fromRectAndRadius(bar, const Radius.circular(21))), 4, 4, const Color.fromRGBO(0, 0, 0, 0.35));
      _capsule(canvas, bar, 21, const Rect.fromLTWH(248, 294, 160, 10), 5, 0.7);
    }

    // 2. bottom left button: plus
    _darkButton(canvas, const Offset(328, 710), kLogoPathBuilders[1]());
    {
      const horizontal = Rect.fromLTWH(244, 689, 168, 42);
      const vertical = Rect.fromLTWH(307, 626, 42, 168);
      _dropShadow(
        canvas,
        _union([
          Path()..addRRect(RRect.fromRectAndRadius(horizontal, const Radius.circular(21))),
          Path()..addRRect(RRect.fromRectAndRadius(vertical, const Radius.circular(21))),
        ]),
        4,
        4,
        const Color.fromRGBO(0, 0, 0, 0.35),
      );
      // both capsules, then both highlights (the SVG draws the four rects in this order)
      for (final r in const [horizontal, vertical]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(21)),
          Paint()..shader = _vertical(r, [_c(0xFFFFFF), _c(0xFDFDFD), _c(0xEAEDF2)], const [0.0, 0.6, 1.0]),
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(248, 690, 160, 9), const Radius.circular(4.5)),
        Paint()..color = const Color.fromRGBO(255, 255, 255, 0.7),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(310, 628, 36, 12), const Radius.circular(6)),
        Paint()..color = const Color.fromRGBO(255, 255, 255, 0.7),
      );
    }

    // 3. right button: tall green equals capsule
    {
      const pill = Rect.fromLTWH(536, 157, 320, 710);
      final pillRRect = RRect.fromRectAndRadius(pill, const Radius.circular(160));
      final pillPath = Path()..addRRect(pillRRect);
      // greenShadow: two drop shadows
      _dropShadow(canvas, pillPath, 18, 22, _c(0x047337, 0.35));
      _dropShadow(canvas, pillPath, 8, 10, const Color.fromRGBO(0, 0, 0, 0.2));
      canvas.drawRRect(
        pillRRect,
        Paint()
          ..shader = _vertical(
            pill,
            [_c(0x059E4E), _c(0x08B85B), _c(0x11CB65), _c(0x3FE078), _c(0x6EE787)],
            const [0.0, 0.25, 0.55, 0.8, 1.0],
          ),
      );
      canvas.drawRRect(
        pillRRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..shader = _vertical(
            pill,
            const [Color.fromRGBO(255, 255, 255, 0.75), Color.fromRGBO(255, 255, 255, 0.35), Color.fromRGBO(255, 255, 255, 0.05), Color.fromRGBO(255, 255, 255, 0.45)],
            const [0.0, 0.3, 0.7, 1.0],
          ),
      );
      final sheen = kLogoPathBuilders[2]();
      final sheenBox = sheen.getBounds();
      canvas.drawPath(
        sheen,
        Paint()
          ..shader = ui.Gradient.linear(
            sheenBox.topLeft,
            sheenBox.bottomRight,
            const [Color.fromRGBO(255, 255, 255, 0.65), Color.fromRGBO(255, 255, 255, 0.15), Color.fromRGBO(255, 255, 255, 0.0)],
            const [0.0, 0.45, 1.0],
          ),
      );
      canvas.drawPath(kLogoPathBuilders[3](), Paint()..color = const Color.fromRGBO(255, 255, 255, 0.28));
    }

    // Equals bars
    {
      const upper = Rect.fromLTWH(612, 464, 168, 42);
      const lower = Rect.fromLTWH(612, 534, 168, 42);
      _dropShadow(
        canvas,
        _union([
          Path()..addRRect(RRect.fromRectAndRadius(upper, const Radius.circular(21))),
          Path()..addRRect(RRect.fromRectAndRadius(lower, const Radius.circular(21))),
        ]),
        4,
        4,
        const Color.fromRGBO(0, 0, 0, 0.35),
      );
      _capsule(canvas, upper, 21, const Rect.fromLTWH(616, 465, 160, 9), 4.5, 0.75);
      _capsule(canvas, lower, 21, const Rect.fromLTWH(616, 535, 160, 9), 4.5, 0.75);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.shape != shape;
}
