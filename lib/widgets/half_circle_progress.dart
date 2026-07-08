import 'package:flutter/material.dart';
import 'dart:math' as math;

class HalfCircleProgressPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;

  HalfCircleProgressPainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double strokeWidth = 15.0;
    Rect rect = Rect.fromLTWH(0, strokeWidth / 2, size.width, size.height * 2);

    Paint backgroundPaint =
        Paint()
          ..color = backgroundColor
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    Paint shadowPaint =
        Paint()
          ..color = progressColor.withAlpha((0.4 * 255).round())
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    Paint progressPaint =
        Paint()
          ..color = progressColor
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, math.pi, math.pi, false, backgroundPaint);

    if (progress > 0) {
      canvas.drawArc(rect, math.pi, math.pi * progress, false, shadowPaint);
      canvas.drawArc(rect, math.pi, math.pi * progress, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Progress değiştikçe yeniden çizilmesi için
  }
}
