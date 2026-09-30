import 'package:flutter/material.dart';

/// Il marchio dell'app: due cerchi, il centro, la lancetta e un'eco.
/// Lo stesso disegno genera l'icona (test_screens/icons_test.dart).
class RadarMark extends StatelessWidget {
  const RadarMark({super.key, required this.size, required this.color, this.stroke = 3.4, this.inner = true});

  final double size;
  final Color color;

  /// Spessore del tratto, sulla griglia 48×48.
  final double stroke;

  /// Cerchio interno: si toglie nelle dimensioni piccole.
  final bool inner;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: RadarPainter(color: color, stroke: stroke, inner: inner),
    ),
  );
}

class RadarPainter extends CustomPainter {
  const RadarPainter({required this.color, required this.stroke, this.inner = true});

  final Color color;
  final double stroke;
  final bool inner;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 48;
    canvas.translate((size.width - 48 * s) / 2, (size.height - 48 * s) / 2);
    canvas.scale(s);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = color;
    const c = Offset(24, 24);
    canvas.drawCircle(c, 20 - stroke / 2, line);
    if (inner) canvas.drawCircle(c, 11, line);
    canvas.drawLine(c, const Offset(34.2, 13.8), line);
    canvas.drawCircle(c, 3.5, fill);
    canvas.drawCircle(const Offset(11.3, 31.4), 1.8, fill);
  }

  @override
  bool shouldRepaint(RadarPainter old) => old.color != color || old.stroke != stroke || old.inner != inner;
}
