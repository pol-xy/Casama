import 'package:flutter/material.dart';

/// Custom vector icon representing an open Lost & Found box with angled side
/// flaps, two peeking item silhouettes, and a centered `?` mark.
class CasamaLostFoundIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final String? semanticLabel;

  const CasamaLostFoundIcon({
    super.key,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ??
        IconTheme.of(context).color ??
        Theme.of(context).iconTheme.color ??
        Colors.black;

    final paint = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _CasamaLostFoundIconPainter(color: resolvedColor),
      ),
    );

    if (semanticLabel == null) return paint;
    return Semantics(label: semanticLabel, child: paint);
  }
}

class _CasamaLostFoundIconPainter extends CustomPainter {
  final Color color;

  const _CasamaLostFoundIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final strokeW = (s * 0.085).clamp(1.2, 3.2);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    Offset p(double x, double y) => Offset(x * s, y * s);

    // 1. Open box front body with rounded bottom corners
    final bodyPath = Path()
      ..moveTo(0.18 * s, 0.42 * s)
      ..lineTo(0.82 * s, 0.42 * s)
      ..lineTo(0.82 * s, 0.77 * s)
      ..quadraticBezierTo(0.82 * s, 0.85 * s, 0.74 * s, 0.85 * s)
      ..lineTo(0.26 * s, 0.85 * s)
      ..quadraticBezierTo(0.18 * s, 0.85 * s, 0.18 * s, 0.77 * s)
      ..close();
    canvas.drawPath(bodyPath, strokePaint);

    // 2. Angled open side flaps flaring outward
    final leftFlap = Path()
      ..moveTo(0.18 * s, 0.42 * s)
      ..lineTo(0.07 * s, 0.27 * s)
      ..lineTo(0.30 * s, 0.24 * s)
      ..lineTo(0.38 * s, 0.42 * s);
    canvas.drawPath(leftFlap, strokePaint);

    final rightFlap = Path()
      ..moveTo(0.82 * s, 0.42 * s)
      ..lineTo(0.93 * s, 0.27 * s)
      ..lineTo(0.70 * s, 0.24 * s)
      ..lineTo(0.62 * s, 0.42 * s);
    canvas.drawPath(rightFlap, strokePaint);

    // 3. Two minimal item silhouettes peeking from the top opening
    final leftPeek = Path()
      ..moveTo(0.37 * s, 0.42 * s)
      ..lineTo(0.37 * s, 0.22 * s)
      ..quadraticBezierTo(0.37 * s, 0.17 * s, 0.42 * s, 0.17 * s)
      ..lineTo(0.47 * s, 0.17 * s)
      ..quadraticBezierTo(0.51 * s, 0.17 * s, 0.51 * s, 0.22 * s)
      ..lineTo(0.51 * s, 0.42 * s);
    canvas.drawPath(leftPeek, strokePaint);

    final rightPeek = Path()
      ..moveTo(0.54 * s, 0.42 * s)
      ..lineTo(0.57 * s, 0.23 * s)
      ..lineTo(0.65 * s, 0.25 * s)
      ..lineTo(0.62 * s, 0.42 * s);
    canvas.drawPath(rightPeek, strokePaint);

    // 4. Centered '?' mark on the front face of the box
    final qPath = Path()
      ..moveTo(0.43 * s, 0.55 * s)
      ..cubicTo(
        0.43 * s,
        0.49 * s,
        0.57 * s,
        0.49 * s,
        0.57 * s,
        0.56 * s,
      )
      ..cubicTo(
        0.57 * s,
        0.61 * s,
        0.50 * s,
        0.61 * s,
        0.50 * s,
        0.67 * s,
      );
    canvas.drawPath(qPath, strokePaint);

    canvas.drawCircle(p(0.50, 0.76), strokeW * 0.62, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _CasamaLostFoundIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
