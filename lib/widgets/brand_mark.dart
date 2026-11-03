import 'package:flutter/material.dart';

import '../core/theme.dart';

/// App mark: an apex chevron on an Apex Red tile, with the wordmark when
/// [showName]. Use [onDark] on dark surfaces.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32, this.showName = true, this.onDark = false});

  final double size;
  final bool showName;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Apexo',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(size * 0.3),
            ),
            child: CustomPaint(painter: _ApexGlyph()),
          ),
          if (showName) ...[
            SizedBox(width: size * 0.3),
            Text(
              'Apexo',
              style: TextStyle(
                fontSize: size * 0.58,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: onDark ? Colors.white : AppColors.text,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A racing-line chevron with a volt dot marking the apex.
class _ApexGlyph extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final path = Path()
      ..moveTo(w * 0.24, w * 0.72)
      ..lineTo(w * 0.5, w * 0.3)
      ..lineTo(w * 0.76, w * 0.72);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.13
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(Offset(w * 0.5, w * 0.3), w * 0.075, Paint()..color = Palette.voltYellow);
  }

  @override
  bool shouldRepaint(_ApexGlyph oldDelegate) => false;
}
