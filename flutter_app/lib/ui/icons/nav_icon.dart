import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'svg_paths_generated.dart';

/// `NavIconId` (src/components/NavIcons.tsx): the calculator modes plus the header actions.
enum NavIconId { standard, scientific, converter, finance, physics, chemistry, grapher, recents, settings, sound, guide }

NavIconId navIconIdFor(String id) => NavIconId.values.firstWhere((e) => e.name == id, orElse: () => NavIconId.standard);

// Indices into kNavIconPathBuilders (pinned by tools/gen_svg_paths.mjs).
const int _converterTop = 0;
const int _converterBottom = 1;
const int _financeBody = 2;
const int _financeDollar = 3;
const int _recentsTrack = 4;
const int _recentsArrow = 5;
const int _recentsTicks = 6;
const int _recentsHands = 7;
const int _settingsFilled = 8;
const int _settingsOutline = 9;
const int _soundBodyOn = 10;
const int _soundWaveSmall = 11;
const int _soundWaveBig = 12;
const int _soundBodyMuted = 13;
const int _soundMuteCross = 14;
const int _guideBook = 15;
const int _guideSpine = 16;
const int _guideSpark = 17;
const int _grapherAxes = 18;
const int _grapherCurve = 19;

/// The vector navigation icons of the web app, drawn in a 24 x 24 box scaled to [size], in the current text colour
/// ([color]). Stroke widths change with [active] exactly as in the TSX.
class NavIcon extends StatelessWidget {
  const NavIcon({super.key, required this.id, required this.color, this.active = false, this.size = 24});

  final NavIconId id;
  final Color color;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: NavIconPainter(id: id, color: color, active: active)),
    );
  }
}

class NavIconPainter extends CustomPainter {
  const NavIconPainter({required this.id, required this.color, required this.active});

  final NavIconId id;
  final Color color;
  final bool active;

  Paint _stroke(double width, {Color? override}) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..color = override ?? color
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.miter
    ..isAntiAlias = true;

  Paint _strokeRound(double width, {Color? override}) => _stroke(width, override: override)
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint get _fill => Paint()
    ..style = PaintingStyle.fill
    ..color = color
    ..isAntiAlias = true;

  Path _path(int i) => kNavIconPathBuilders[i]();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    switch (id) {
      case NavIconId.standard:
      case NavIconId.scientific:
        _calculator(canvas);
      case NavIconId.physics:
        _physics(canvas);
      case NavIconId.chemistry:
        _chemistry(canvas);
      case NavIconId.converter:
        {
          final p = _strokeRound(active ? 2.2 : 1.9);
          canvas.drawPath(_path(_converterTop), p);
          canvas.drawPath(_path(_converterBottom), p);
        }
      case NavIconId.finance:
        {
          final p = _strokeRound(active ? 2 : 1.8);
          canvas.drawPath(_path(_financeBody), p);
          canvas.drawPath(_path(_financeDollar), p);
        }
      case NavIconId.recents:
        _recents(canvas);
      case NavIconId.settings:
        _settings(canvas);
      case NavIconId.sound:
        _sound(canvas);
      case NavIconId.guide:
        _guide(canvas);
      case NavIconId.grapher:
        _grapher(canvas);
    }
    canvas.restore();
  }

  // Calculator: squircle outline, screen display bar, 3 x 2 dot keypad.
  void _calculator(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(4, 2.5, 16, 19), const Radius.circular(4.5)),
      _stroke(active ? 2 : 1.8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(7, 5.5, 10, 3.2), const Radius.circular(1.1)),
      _stroke(active ? 1.6 : 1.4),
    );
    for (final y in const [11.8, 15.0, 18.2]) {
      for (final x in const [8.5, 15.5]) {
        canvas.drawCircle(Offset(x, y), 1.1, _fill);
      }
    }
  }

  // Physics Lab: nucleus and two intersecting orbits tilted -35 and +35 degrees.
  void _physics(Canvas canvas) {
    canvas.drawCircle(const Offset(12, 12), 1.9, _fill);
    for (final deg in const [-35.0, 35.0]) {
      canvas.save();
      canvas.translate(12, 12);
      canvas.rotate(deg * math.pi / 180);
      canvas.drawOval(const Rect.fromLTRB(-9.2, -4, 9.2, 4), _stroke(active ? 2 : 1.8));
      canvas.restore();
    }
  }

  // Chemistry: conical flask (lucide "flask-conical" outline), liquid line, rim.
  void _chemistry(Canvas canvas) {
    final flask = Path()
      ..moveTo(10, 2.5)
      ..lineTo(10, 9.5)
      ..lineTo(4.6, 19.8)
      ..quadraticBezierTo(4.1, 21.5, 5.9, 21.5)
      ..lineTo(18.1, 21.5)
      ..quadraticBezierTo(19.9, 21.5, 19.4, 19.8)
      ..lineTo(14, 9.5)
      ..lineTo(14, 2.5);
    final p = _strokeRound(active ? 2 : 1.8);
    canvas.drawPath(flask, p);
    canvas.drawLine(const Offset(8.5, 2.5), const Offset(15.5, 2.5), p);
    canvas.drawLine(const Offset(7.2, 15.5), const Offset(16.8, 15.5), p);
  }

  void _recents(Canvas canvas) {
    canvas.drawPath(_path(_recentsTrack), _strokeRound(active ? 2.1 : 1.85));
    canvas.drawPath(_path(_recentsArrow), _strokeRound(active ? 2.1 : 1.85));
    canvas.drawPath(_path(_recentsTicks), _strokeRound(active ? 1.5 : 1.3, override: color.withValues(alpha: color.a * 0.6)));
    canvas.drawCircle(const Offset(12, 12), active ? 1.9 : 1.6, _fill);
    canvas.drawPath(_path(_recentsHands), _strokeRound(active ? 2.1 : 1.85));
  }

  void _settings(Canvas canvas) {
    if (active) {
      canvas.drawPath(_path(_settingsFilled)..fillType = PathFillType.evenOdd, _fill);
    } else {
      canvas.drawCircle(const Offset(12, 12), 3.3, _stroke(1.9));
      canvas.drawPath(_path(_settingsOutline), _strokeRound(1.8));
    }
  }

  void _sound(Canvas canvas) {
    if (active) {
      canvas.drawPath(_path(_soundBodyOn), _fill);
      final p = _strokeRound(2.2);
      canvas.drawPath(_path(_soundWaveSmall), p);
      canvas.drawPath(_path(_soundWaveBig), p);
    } else {
      final body = _stroke(1.8)..strokeJoin = StrokeJoin.round;
      canvas.drawPath(_path(_soundBodyMuted), body);
      canvas.drawPath(_path(_soundMuteCross), _strokeRound(2));
    }
  }

  // User guide: open book with a spark above the spine.
  void _guide(Canvas canvas) {
    final book = _path(_guideBook);
    if (active) {
      canvas.drawPath(book, Paint()..style = PaintingStyle.fill..color = color.withValues(alpha: color.a * 0.18));
    }
    canvas.drawPath(book, _stroke(active ? 2 : 1.8)..strokeJoin = StrokeJoin.round);
    canvas.drawPath(_path(_guideSpine), _strokeRound(1.7));
    canvas.drawPath(_path(_guideSpark), _fill);
  }

  void _grapher(Canvas canvas) {
    canvas.drawPath(_path(_grapherAxes), _strokeRound(1.9));
    canvas.drawPath(_path(_grapherCurve), _strokeRound(1.9));
    canvas.drawCircle(const Offset(8, 8.5), 1.3, _fill);
    canvas.drawCircle(const Offset(14.5, 14), 1.3, _fill);
  }

  @override
  bool shouldRepaint(NavIconPainter old) => old.id != id || old.color != color || old.active != active;
}
