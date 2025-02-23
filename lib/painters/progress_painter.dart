import 'package:flutter/material.dart';
import 'dart:math' as math;

class ProgressPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;

  ProgressPainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // 绘制背景圆弧
    paint.color = backgroundColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,  // 从12点钟方向开始
      2 * math.pi,   // 整圆
      false,
      paint,
    );

    // 绘制进度圆弧
    paint.color = progressColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,  // 从12点钟方向开始
      2 * math.pi * progress,  // 根据进度绘制
      false,
      paint,
    );

    // 绘制进度点
    if (progress > 0) {
      final angle = 2 * math.pi * progress - math.pi / 2;
      final pointX = center.dx + radius * math.cos(angle);
      final pointY = center.dy + radius * math.sin(angle);
      
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(pointX, pointY),
        strokeWidth * 0.8,  // 点的大小
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 