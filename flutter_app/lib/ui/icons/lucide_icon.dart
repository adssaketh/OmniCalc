import 'package:flutter/widgets.dart';

import 'lucide_icons_generated.dart';

export 'lucide_icons_generated.dart' show LucideIconId;

/// A lucide icon (24 x 24 viewBox, stroke 2, round caps and joins, no fill), drawn at [size] in [color].
/// The stroke scales with the size (`absoluteStrokeWidth` is off in the web app). [filled] is `fill="currentColor"`:
/// the shape is filled in [color] as well as stroked (the Guide's Play button).
class LucideIcon extends StatelessWidget {
  const LucideIcon(this.id, {super.key, required this.color, this.size = 24, this.filled = false});

  final LucideIconId id;
  final Color color;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LucidePainter(id, color, filled)),
    );
  }
}

class _LucidePainter extends CustomPainter {
  _LucidePainter(this.id, this.color, this.filled);

  final LucideIconId id;
  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final path = kLucideIconBuilders[id]!();
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);
    if (filled) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = color
          ..isAntiAlias = true,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LucidePainter old) => old.id != id || old.color != color || old.filled != filled;
}
