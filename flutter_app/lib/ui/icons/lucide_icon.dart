import 'package:flutter/widgets.dart';

import 'lucide_icons_generated.dart';

export 'lucide_icons_generated.dart' show LucideIconId;

/// A lucide icon (24 x 24 viewBox, stroke 2, round caps and joins, no fill), drawn at [size] in [color].
/// The stroke scales with the size (`absoluteStrokeWidth` is off in the web app).
class LucideIcon extends StatelessWidget {
  const LucideIcon(this.id, {super.key, required this.color, this.size = 24});

  final LucideIconId id;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LucidePainter(id, color)),
    );
  }
}

class _LucidePainter extends CustomPainter {
  _LucidePainter(this.id, this.color);

  final LucideIconId id;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = kLucideIconBuilders[id]!();
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);
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
  bool shouldRepaint(_LucidePainter old) => old.id != id || old.color != color;
}
