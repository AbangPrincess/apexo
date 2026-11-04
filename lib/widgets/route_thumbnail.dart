import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/geo.dart';
import '../core/theme.dart';

/// A route drawn with CustomPainter: no map tiles, so feeds stay light.
class RouteThumbnail extends StatelessWidget {
  const RouteThumbnail({
    super.key,
    required this.points,
    this.height = 120,
    this.color = AppColors.data,
    this.background,
  });

  final List<GeoPoint> points;
  final double height;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Route map',
    image: true,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: background ?? AppColors.surfaceAlt,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: RepaintBoundary(child: CustomPaint(painter: RoutePainter(points, color))),
        ),
      ),
    ),
  );
}

class RoutePainter extends CustomPainter {
  RoutePainter(List<GeoPoint> points, this.color, {this.padding = 14})
    : points = _thin(points, 400);

  final List<GeoPoint> points;
  final Color color;
  final double padding;

  /// Keeps at most [max] points (plus the last) so huge rides paint fast.
  static List<GeoPoint> _thin(List<GeoPoint> pts, int max) {
    if (pts.length <= max) return pts;
    final step = pts.length / max;
    return [for (var i = 0.0; i < pts.length; i += step) pts[i.floor()], pts.last];
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    var minLat = points.first.lat, maxLat = minLat;
    var minLng = points.first.lng, maxLng = minLng;
    for (final p in points) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLng = math.min(minLng, p.lng);
      maxLng = math.max(maxLng, p.lng);
    }
    // Equirectangular projection; longitude shrinks with latitude.
    final kx = math.cos((minLat + maxLat) / 2 * math.pi / 180);
    final w = math.max((maxLng - minLng) * kx, 1e-9);
    final h = math.max(maxLat - minLat, 1e-9);
    final scale = math.min((size.width - padding * 2) / w, (size.height - padding * 2) / h);
    final dx = (size.width - w * scale) / 2;
    final dy = (size.height - h * scale) / 2;
    Offset at(GeoPoint p) =>
        Offset(dx + (p.lng - minLng) * kx * scale, dy + (maxLat - p.lat) * scale);

    final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
    for (final p in points.skip(1)) {
      final o = at(p);
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // Start: volt with an ink ring; finish: ink with a white ring.
    _dot(canvas, at(points.first), AppColors.tracking, ring: AppColors.ink);
    _dot(canvas, at(points.last), AppColors.ink);
  }

  void _dot(Canvas canvas, Offset o, Color fill, {Color ring = Colors.white}) {
    canvas.drawCircle(o, 5.5, Paint()..color = ring);
    canvas.drawCircle(o, 4, Paint()..color = fill);
  }

  @override
  bool shouldRepaint(RoutePainter old) => !identical(old.points, points) || old.color != color;
}
