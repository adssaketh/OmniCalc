import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../engine/js_number.dart';
import '../state/app_settings.dart';

/// Port of `src/edgeEffects.ts`: how content behaves as it slides under the floating bars (Settings > Bars & scrolling).

/// Fade height is only the short softening right at the bar edge.
const Map<FadeHeight, double> fadePx = {FadeHeight.short: 8, FadeHeight.medium: 16, FadeHeight.tall: 28};

/// Glass blur: content under a glass bar becomes soft colour, never readable ghost text.
const Map<GlassBlur, double> glassBlurPx = {GlassBlur.soft: 14, GlassBlur.medium: 22, GlassBlur.strong: 32};

/// Glass transparency slider (0 = frosted ... 100 = clear) -> how opaque the bar colour is, in percent.
int glassFillPercent(num transparency) {
  final t = math.min(100.0, math.max(0.0, transparency.toDouble()));
  return jsRound(90 - t * 0.82).toInt();
}

/// Display card on glass bars: always clearly more opaque than the bars, so the numbers stay readable.
int glassFillStrongPercent(num transparency) => math.min(94, math.max(62, glassFillPercent(transparency) + 36));

/// Cosine ease: starts and ends flat, so a fade has no visible "start line" or "end line".
double _ease(double t) => 0.5 - 0.5 * math.cos(math.pi * math.min(1.0, math.max(0.0, t)));

const int _steps = 12;

/// Where the bars are, as measured by the shell (`EdgeGeometry` in the TS).
class EdgeGeometry {
  const EdgeGeometry({required this.topEdge, required this.topGlow, required this.bottomH, required this.fadePx});

  /// Where the top bars visually end (distance from the top of the screen).
  final double topEdge;

  /// How far content stays visible under the top bars, measured up from their lower edge.
  final double topGlow;

  /// Height of the bottom bar stack (bar + padding).
  final double bottomH;
  final double fadePx;
}

/// One stop of the mask: [alpha] is the base opacity `a`; the real opacity is `1 - (1 - a) * ft` for a top stop and
/// `1 - (1 - a) * fb` for a bottom stop (the TS multiplies the whole top fade by --ft and the bottom fade by --fb).
class MaskStop {
  const MaskStop({required this.fromBottom, required this.offset, required this.alpha});

  /// true: the position is measured up from the bottom of the scroll area (`calc(100% - Npx)`).
  final bool fromBottom;

  /// Pixels: from the top edge when [fromBottom] is false, from the bottom edge when true.
  final double offset;
  final double alpha;
}

/// `buildEdgeMask`. Null means no mask (the effect is Off). Modelled on Ping:
///  - top: hidden at the very top of the screen, rising smoothly so the content is visible *through* the bar, and fully
///    crisp right at / beyond the bar's lower edge.
///  - bottom: crisp right up to the nav bar's top edge, then softly fading under the bar toward the screen edge.
class EdgeMaskSpec {
  const EdgeMaskSpec(this.stops, {required this.hasBottom});

  final List<MaskStop> stops;
  final bool hasBottom;

  static EdgeMaskSpec? build(EdgeGeometry g, EdgeEffect effect, BarStyle barStyle) {
    if (effect == EdgeEffect.off) return null;
    final glass = barStyle == BarStyle.glass;
    const edgeClear = 10.0;
    final stops = <MaskStop>[];
    // The TS writes `(1 - a).toFixed(3)` and `px.toFixed(1)` into the CSS string; the same rounding is applied here.
    double r3(double a) => 1 - double.parse(jsToFixed(1 - a, 3));
    double r1(double px) => double.parse(jsToFixed(px, 1));
    MaskStop top(double a, double px) => MaskStop(fromBottom: false, offset: r1(px), alpha: r3(a));
    MaskStop bottom(double a, double pxFromBottom) => MaskStop(fromBottom: true, offset: r1(pxFromBottom), alpha: r3(a));

    // ---- top: 0 at the screen edge -> 1 a little below the bar's lower edge
    final rampStart = math.max(edgeClear + 2, g.topEdge - g.topGlow);
    final rampEnd = g.topEdge + g.fadePx;
    stops.add(top(0, 0));
    stops.add(top(0, rampStart));
    for (var i = 1; i <= _steps; i++) {
      final t = i / _steps;
      stops.add(top(_ease(t), rampStart + (rampEnd - rampStart) * t));
    }

    // ---- bottom (positions measured from the bottom of the scroll area)
    if (g.bottomH > 0) {
      final pillTop = math.max(g.bottomH - 4, 0.0);
      final underBar = glass ? (effect == EdgeEffect.blur ? 0.5 : 0.38) : 0.0;
      final farEnd = pillTop + g.fadePx; // crisp above this
      final start = math.max(pillTop - 46, edgeClear + 10);
      stops.add(bottom(1, farEnd));
      for (var i = 1; i <= _steps; i++) {
        final t = i / _steps;
        final d = farEnd - (farEnd - start) * t;
        stops.add(bottom(1 - (1 - underBar) * _ease(t), d));
      }
      stops.add(bottom(underBar, math.max(g.bottomH * 0.4, edgeClear + 9)));
      stops.add(bottom(0, edgeClear));
      stops.add(bottom(0, 0));
      return EdgeMaskSpec(stops, hasBottom: true);
    }
    stops.add(bottom(1, 0));
    return EdgeMaskSpec(stops, hasBottom: false);
  }

  /// The vertical alpha gradient for a scroll area of [height] with the current scroll-driven strengths
  /// [ft] (top, 0..1) and [fb] (bottom, 0..1). Stops that would go backwards are held at the previous position, which is
  /// what CSS does with out-of-order colour stops.
  LinearGradient gradient(double height, double ft, double fb) {
    final colors = <Color>[];
    final positions = <double>[];
    var prev = 0.0;
    for (final s in stops) {
      final px = s.fromBottom ? height - s.offset : s.offset;
      final frac = height <= 0 ? 0.0 : (px / height).clamp(0.0, 1.0);
      final pos = math.max(prev, frac);
      prev = pos;
      final strength = s.fromBottom ? fb : ft;
      final alpha = 1 - (1 - s.alpha) * strength;
      colors.add(Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0)));
      positions.add(pos);
    }
    return LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors, stops: positions);
  }
}

/// The scroll-driven strengths of App.tsx (`--ft`, `--fb`): 0 -> 1 as content really slides under a bar.
class EdgeFade extends ChangeNotifier {
  double _top = 0;
  double _bottom = 0;

  double get top => _top;
  double get bottom => _bottom;

  /// Over [span] px of scrolling the fade eases in; values are quantised to 0.02 like the TS (`Math.round(v * 50) / 50`).
  static const double span = 48;

  static double _q(double v) => (v.clamp(0.0, 1.0) * 50).roundToDouble() / 50;

  void updateFromScroll({required double pixels, required double maxScrollExtent}) {
    final t = _q(pixels / span);
    final b = _q((maxScrollExtent - pixels) / span);
    if (t == _top && b == _bottom) return;
    _top = t;
    _bottom = b;
    // A page that changes height (a tool screen switching tab) reports new scroll metrics while it is being laid out;
    // listeners must not rebuild in the middle of a frame, so they hear about it right after it.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      if (_notifyQueued) return;
      _notifyQueued = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notifyQueued = false;
        if (!_disposed) notifyListeners();
      });
      return;
    }
    notifyListeners();
  }

  bool _notifyQueued = false;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Applies the edge mask to the scroll area (CSS `mask-image` on #app-scroll).
class EdgeMaskBox extends StatelessWidget {
  const EdgeMaskBox({super.key, required this.spec, required this.fade, required this.child});

  final EdgeMaskSpec? spec;
  final EdgeFade fade;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = spec;
    if (s == null) return child;
    return ListenableBuilder(
      listenable: fade,
      child: child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (Rect rect) => s.gradient(rect.height, fade.top, fade.bottom).createShader(rect),
        child: child,
      ),
    );
  }
}

/// One layer of the progressive blur (`BlurLayer` in the TS).
class BlurLayer {
  const BlurLayer({required this.blurPx, required this.height, required this.stops});

  final double blurPx;

  /// Height of the layer, measured from the screen edge.
  final int height;

  /// Mask: (distance from the screen edge in px, alpha).
  final List<(double, double)> stops;
}

/// `buildBlurLayers` ("Fade + blur"): several backdrop-blur layers stacked on each other. Every layer reaches a bit
/// less far from the screen edge than the one below it, so the blur grows smoothly from nothing (far from the bar) to
/// strong (at the bar), instead of one flat smudge.
List<BlurLayer> buildBlurLayers(double barH, double fadePx) {
  final total = barH + fadePx;
  const blurs = [2.5, 4.5, 8.0, 13.0];
  return [
    for (var k = 0; k < blurs.length; k++)
      () {
        final reach = total * (1 - (k / blurs.length) * 0.6);
        final solidTo = math.min(reach * 0.35, barH + 4);
        // The TS writes `toFixed(1)` positions and `toFixed(3)` alphas into the CSS string.
        double r1(double px) => double.parse(jsToFixed(px, 1));
        final stops = <(double, double)>[(0, 1), (r1(solidTo), 1)];
        for (var i = 1; i <= 10; i++) {
          final t = i / 10;
          stops.add((r1(solidTo + (reach - solidTo) * t), double.parse(jsToFixed(1 - _ease(t), 3))));
        }
        return BlurLayer(blurPx: blurs[k], height: jsRound(reach).toInt(), stops: stops);
      }(),
  ];
}

/// The progressive blur toward one screen edge ("Fade + blur"). [strength] is `--ft` or `--fb`.
///
/// The CSS masks a `backdrop-filter` element and fades it with `opacity`. Here the mask is painted with `dstIn` straight
/// onto the blurred backdrop inside the BackdropFilter (a ShaderMask or Opacity *around* a BackdropFilter would blur
/// nothing), and the strength is folded into the mask alpha, which gives the same picture.
class EdgeBlur extends StatelessWidget {
  const EdgeBlur({super.key, required this.layers, required this.strength, required this.atTop});

  final List<BlurLayer> layers;
  final EdgeFade strength;
  final bool atTop;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ListenableBuilder(
          listenable: strength,
          builder: (context, _) {
            final s = atTop ? strength.top : strength.bottom;
            if (s <= 0) return const SizedBox.shrink();
            return Stack(
              children: [
                for (final layer in layers)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: atTop ? 0 : null,
                    bottom: atTop ? null : 0,
                    height: layer.height.toDouble(),
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: layer.blurPx, sigmaY: layer.blurPx),
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _BlurMaskPainter(layer: layer, atTop: atTop, strength: s),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BlurMaskPainter extends CustomPainter {
  const _BlurMaskPainter({required this.layer, required this.atTop, required this.strength});

  final BlurLayer layer;
  final bool atTop;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0) return;
    final colors = <Color>[];
    final positions = <double>[];
    var prev = 0.0;
    for (final (px, a) in layer.stops) {
      final pos = math.max(prev, (px / size.height).clamp(0.0, 1.0));
      prev = pos;
      colors.add(Color.fromRGBO(0, 0, 0, (a * strength).clamp(0.0, 1.0)));
      positions.add(pos);
    }
    final rect = Offset.zero & size;
    final gradient = LinearGradient(
      begin: atTop ? Alignment.topCenter : Alignment.bottomCenter,
      end: atTop ? Alignment.bottomCenter : Alignment.topCenter,
      colors: colors,
      stops: positions,
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect)..blendMode = BlendMode.dstIn);
  }

  @override
  bool shouldRepaint(_BlurMaskPainter old) =>
      old.layer != layer || old.atTop != atTop || old.strength != strength;
}
