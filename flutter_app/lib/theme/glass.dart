import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../state/app_settings.dart';
import 'edge_effects.dart' as fx;
import 'motion.dart';
import 'tokens.dart';

/// Bar style published by the shell (App.tsx puts `data-bars`, `data-glass-edge`, `--glass-fill`, `--glass-blur`,
/// `--glass-fill-strong` on <html>). Everything that draws a `.bar-surface` reads it from here.
@immutable
class ShellStyle {
  const ShellStyle({
    this.barStyle = BarStyle.solid,
    this.glassFillPercent = 33,
    this.glassFillStrongPercent = 69,
    this.glassBlurPx = 22,
    this.glassEdge = true,
  });

  factory ShellStyle.fromSettings(AppSettings s) => ShellStyle(
        barStyle: s.barStyle,
        glassFillPercent: fx.glassFillPercent(s.glassTransparency),
        glassFillStrongPercent: fx.glassFillStrongPercent(s.glassTransparency),
        glassBlurPx: fx.glassBlurPx[s.glassBlur]!,
        glassEdge: s.glassEdge,
      );

  final BarStyle barStyle;
  final int glassFillPercent;
  final int glassFillStrongPercent;
  final double glassBlurPx;
  final bool glassEdge;

  bool get isGlass => barStyle == BarStyle.glass;

  @override
  bool operator ==(Object other) =>
      other is ShellStyle &&
      other.barStyle == barStyle &&
      other.glassFillPercent == glassFillPercent &&
      other.glassFillStrongPercent == glassFillStrongPercent &&
      other.glassBlurPx == glassBlurPx &&
      other.glassEdge == glassEdge;

  @override
  int get hashCode => Object.hash(barStyle, glassFillPercent, glassFillStrongPercent, glassBlurPx, glassEdge);
}

class ShellStyleScope extends InheritedWidget {
  const ShellStyleScope({super.key, required this.style, required super.child});

  final ShellStyle style;

  static ShellStyle of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellStyleScope>()?.style ?? const ShellStyle();

  @override
  bool updateShouldNotify(ShellStyleScope oldWidget) => oldWidget.style != style;
}

/// CSS `blur(r) saturate(1.9) brightness(1.05)`: blur first, then the colour matrix (compose applies the inner filter first).
ui.ImageFilter glassBackdropFilter(double blurPx) {
  const s = 1.9;
  const b = 1.05;
  // saturate(s) matrix of the CSS filter spec, then brightness multiplies every channel.
  const r = 0.213;
  const g = 0.715;
  const bl = 0.072;
  final m = <double>[
    b * (r + (1 - r) * s), b * (g - g * s), b * (bl - bl * s), 0, 0,
    b * (r - r * s), b * (g + (1 - g) * s), b * (bl - bl * s), 0, 0,
    b * (r - r * s), b * (g - g * s), b * (bl + (1 - bl) * s), 0, 0,
    0, 0, 0, 1, 0,
  ];
  return ui.ImageFilter.compose(
    outer: ColorFilter.matrix(m),
    inner: ui.ImageFilter.blur(sigmaX: blurPx, sigmaY: blurPx),
  );
}

const BorderRadius pillRadius = BorderRadius.all(Radius.circular(9999));

/// `.bar-surface`: the floating surfaces (header pill, display card, bottom bar). Solid colour or liquid glass,
/// depending on [ShellStyle]. [tone] is `--bar-tone` (the display card uses a stronger tonal role); [strong] is
/// `.bar-surface-strong` (the answer display, clearly more solid than the other bars).
///
/// Paint order, bottom to top, as in the CSS: outer shadow (clipped away inside the shape, so it never shows through
/// the glass), backdrop blur, background colour, background images, inset rim, then the child.
class BarSurface extends StatelessWidget {
  const BarSurface({
    super.key,
    required this.borderRadius,
    required this.child,
    this.tone,
    this.strong = false,
  });

  final BorderRadius borderRadius;
  final Widget child;
  final Color? tone;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final tokens = M3Theme.of(context);
    final style = ShellStyleScope.of(context);
    final target = tone ?? tokens.surfaceContainer;
    final instant = reduceMotion(context);
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: instant ? Duration.zero : const Duration(milliseconds: 260),
      curve: M3Curves.emphasized,
      builder: (context, color, _) {
        final base = color ?? target;
        return Stack(
          fit: StackFit.passthrough,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _BarShadowPainter(radius: borderRadius, style: style),
              ),
            ),
            Positioned.fill(
              child: ClipRRect(
                borderRadius: borderRadius,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (style.isGlass) BackdropFilter(filter: glassBackdropFilter(style.glassBlurPx), child: const SizedBox.expand()),
                    CustomPaint(
                      painter: _BarFillPainter(
                        radius: borderRadius,
                        style: style,
                        tone: base,
                        strong: strong,
                        onSurface: tokens.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            child,
          ],
        );
      },
    );
  }
}

class _BarShadowPainter extends CustomPainter {
  const _BarShadowPainter({required this.radius, required this.style});

  final BorderRadius radius;
  final ShellStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = radius.toRRect(Offset.zero & size);
    // CSS clips an outer box-shadow to the outside of the border box: it must never tint the inside of a glass bar.
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect((Offset.zero & size).inflate(200)),
      Path()..addRRect(rrect),
    );
    canvas.save();
    canvas.clipPath(outside);
    void shadow(double dy, double blur, double alpha) {
      canvas.drawRRect(
        rrect.shift(Offset(0, dy)),
        Paint()
          ..color = Color.fromRGBO(0, 0, 0, alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2),
      );
    }

    if (style.isGlass) {
      // glass: 0 10px 28px rgb(0 0 0 / 0.16); with the glass edge on: ... / 0.18
      shadow(10, 28, style.glassEdge ? 0.18 : 0.16);
    } else {
      // solid: 0 1px 3px rgb(0 0 0 / 0.06), 0 4px 14px rgb(0 0 0 / 0.05) (first listed is on top)
      shadow(4, 14, 0.05);
      shadow(1, 3, 0.06);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BarShadowPainter old) => old.radius != radius || old.style != style;
}

class _BarFillPainter extends CustomPainter {
  const _BarFillPainter({
    required this.radius,
    required this.style,
    required this.tone,
    required this.strong,
    required this.onSurface,
  });

  final BorderRadius radius;
  final ShellStyle style;
  final Color tone;
  final bool strong;
  final Color onSurface;

  static const Color _clearWhite = Color(0x00FFFFFF);
  static const Color _clearBlack = Color(0x00000000);

  /// `linear-gradient(<angle>deg, ...)` over [rect]: CSS angle 0 points up and turns clockwise.
  static ui.Shader _linear(Rect rect, double degrees, List<Color> colors, List<double> stops) {
    final a = degrees * math.pi / 180;
    final dx = math.sin(a);
    final dy = -math.cos(a);
    final len = (rect.width * dx).abs() + (rect.height * dy).abs();
    final c = rect.center;
    return ui.Gradient.linear(
      Offset(c.dx - dx * len / 2, c.dy - dy * len / 2),
      Offset(c.dx + dx * len / 2, c.dy + dy * len / 2),
      colors,
      stops,
    );
  }

  /// `radial-gradient(120% 130% at 22% -25%, white <a> , transparent 55%)`: an ellipse with radii of 120% of the width
  /// and 130% of the height.
  static void _sheen(Canvas canvas, Rect rect, double whiteAlpha) {
    final cx = rect.left + rect.width * 0.22;
    final cy = rect.top + rect.height * -0.25;
    final rx = rect.width * 1.2;
    final ry = rect.height * 1.3;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(rx, ry);
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        1,
        [Color.fromRGBO(255, 255, 255, whiteAlpha), _clearWhite],
        const [0.0, 0.55],
      );
    canvas.drawRect(Rect.fromLTRB((rect.left - cx) / rx, (rect.top - cy) / ry, (rect.right - cx) / rx, (rect.bottom - cy) / ry), paint);
    canvas.restore();
  }

  /// Inset box-shadow: the area inside the shape that is not inside the shape moved by (dx, dy) and shrunk by [spread].
  static void _inset(Canvas canvas, RRect rrect, double dx, double dy, double blur, double spread, Color color) {
    final bounds = rrect.outerRect.inflate(blur * 3 + dx.abs() + dy.abs() + spread + 8);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(bounds)
      ..addRRect(rrect.shift(Offset(dx, dy)).deflate(spread));
    final paint = Paint()..color = color;
    if (blur > 0) paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2);
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect);
    canvas.save();
    canvas.clipRRect(rrect);

    if (style.isGlass) {
      final fill = (strong ? style.glassFillStrongPercent : style.glassFillPercent) / 100;
      canvas.drawRect(rect, Paint()..color = tone.withValues(alpha: tone.a * fill));
      if (strong) {
        // 155deg, on-surface 7% -> transparent 55% (painted first: it is the last of the three images)
        canvas.drawRect(
          rect,
          Paint()
            ..shader = _linear(
              rect,
              155,
              [onSurface.withValues(alpha: 0.07), onSurface.withValues(alpha: 0)],
              const [0.0, 0.55],
            ),
        );
      }
      // 180deg, white 12% -> transparent 46% -> black 7%  (two stops at 46% keep the fade colour-true: no grey midtones)
      canvas.drawRect(
        rect,
        Paint()
          ..shader = _linear(
            rect,
            180,
            [Color.fromRGBO(255, 255, 255, 0.12), _clearWhite, _clearBlack, Color.fromRGBO(0, 0, 0, 0.07)],
            const [0.0, 0.46, 0.46, 1.0],
          ),
      );
      _sheen(canvas, rect, strong ? 0.30 : 0.34);
      if (style.glassEdge) {
        // Painted last-listed first, so the first listed ends up on top.
        _inset(canvas, rrect, 0, 0, 22, 0, Color.fromRGBO(255, 255, 255, 0.09));
        _inset(canvas, rrect, -1, -1.5, 0, 0, Color.fromRGBO(255, 255, 255, 0.14));
        _inset(canvas, rrect, 1, 1.5, 0, 0, Color.fromRGBO(255, 255, 255, 0.55));
        _inset(canvas, rrect, 0, 0, 0, 1, Color.fromRGBO(255, 255, 255, 0.24));
      }
    } else {
      canvas.drawRect(rect, Paint()..color = tone);
      if (strong) {
        // .bar-surface-strong: a soft light sheen so the display reads as a real screen, not a flat grey block
        canvas.drawRect(
          rect,
          Paint()
            ..shader = _linear(
              rect,
              155,
              [onSurface.withValues(alpha: 0.07), onSurface.withValues(alpha: 0)],
              const [0.0, 0.55],
            ),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BarFillPainter old) =>
      old.radius != radius || old.style != style || old.tone != tone || old.strong != strong || old.onSurface != onSurface;
}
