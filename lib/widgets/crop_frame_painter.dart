import 'package:flutter/material.dart';

/// Dims everything outside the frame and outlines it.
class CropFramePainter extends CustomPainter {
  CropFramePainter(this.frame, {required this.circle});

  final Rect frame;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = Path()..addOval(frame);
    final box = Path()..addRect(frame);
    final shape = circle ? hole : box;
    final dim = Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), shape);
    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: 0.62));
    canvas.drawPath(
      shape,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(CropFramePainter old) => old.frame != frame || old.circle != circle;
}
