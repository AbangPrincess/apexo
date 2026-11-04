import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/weather_code.dart';

/// What the sky looks like, from a WMO weather code.
enum Sky { clearDay, clearNight, partlyDay, partlyNight, cloudy, fog, drizzle, rain, snow, thunder }

Sky skyFor(int code, {bool isDay = true}) => switch (code) {
  0 || 1 => isDay ? Sky.clearDay : Sky.clearNight,
  2 => isDay ? Sky.partlyDay : Sky.partlyNight,
  45 || 48 => Sky.fog,
  >= 51 && <= 57 => Sky.drizzle,
  >= 61 && <= 67 || >= 80 && <= 82 => Sky.rain,
  >= 71 && <= 77 || 85 || 86 => Sky.snow,
  >= 95 => Sky.thunder,
  _ => Sky.cloudy,
};

/// Line-art weather icons in a single color (the text color unless [color]
/// is given) and no fills: a sun, a crescent moon, clouds, rain, drizzle,
/// snowflakes, a bolt and fog. Where a cloud sits in front of the sun or
/// moon, a thin gap separates them, the way iOS draws its weather symbols.
class WeatherArt extends StatelessWidget {
  const WeatherArt({super.key, required this.code, this.isDay = true, this.size = 24, this.color});

  final int code;
  final bool isDay;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: weatherLabel(code),
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SkyPainter(skyFor(code, isDay: isDay), color ?? AppColors.text)),
    ),
  );
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.sky, this.ink);

  final Sky sky;
  final Color ink;

  /// Line weight in icon units (1 = the icon's width).
  static const _w = 0.075;

  Paint get _line => Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = _w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width, size.height);
    // A layer, so a cloud can erase what is behind it.
    canvas.saveLayer(const Rect.fromLTWH(-0.2, -0.2, 1.4, 1.4), Paint());
    final line = _line;
    switch (sky) {
      case Sky.clearDay:
        _sun(canvas, line, const Offset(0.5, 0.5), 0.17);
      case Sky.clearNight:
        _moon(canvas, line, const Offset(0.52, 0.5), 0.3);
      case Sky.partlyDay:
        _sun(canvas, line, const Offset(0.35, 0.36), 0.12);
        _cloud(canvas, line, const Offset(0.08, 0.1), 0.82);
      case Sky.partlyNight:
        _moon(canvas, line, const Offset(0.38, 0.36), 0.2);
        _cloud(canvas, line, const Offset(0.08, 0.1), 0.82);
      case Sky.cloudy:
        _cloud(canvas, line, Offset.zero, 1);
      case Sky.fog:
        for (final (y, x0, x1) in [(0.76, 0.24, 0.8), (0.9, 0.2, 0.68)]) {
          canvas.drawLine(Offset(x0, y), Offset(x1, y), line);
        }
        _cloud(canvas, line, const Offset(0, -0.14), 0.9);
      case Sky.drizzle:
        for (final (x, y) in [(0.36, 0.76), (0.56, 0.76), (0.46, 0.9), (0.66, 0.9)]) {
          canvas.drawLine(Offset(x, y), Offset(x - 0.02, y + 0.035), line);
        }
        _cloud(canvas, line, const Offset(0, -0.14), 1);
      case Sky.rain:
        for (final x in [0.38, 0.55, 0.72]) {
          canvas.drawLine(Offset(x, 0.72), Offset(x - 0.06, 0.92), line);
        }
        _cloud(canvas, line, const Offset(0, -0.14), 1);
      case Sky.snow:
        for (final c in [
          const Offset(0.34, 0.8),
          const Offset(0.55, 0.88),
          const Offset(0.74, 0.78),
        ]) {
          _flake(canvas, line, c, 0.07);
        }
        _cloud(canvas, line, const Offset(0, -0.14), 1);
      case Sky.thunder:
        _cloud(canvas, line, const Offset(0, -0.14), 1);
        // The bolt hangs in front of the cloud.
        final bolt = Path()
          ..moveTo(0.57, 0.5)
          ..lineTo(0.42, 0.74)
          ..lineTo(0.52, 0.74)
          ..lineTo(0.46, 0.95)
          ..lineTo(0.66, 0.66)
          ..lineTo(0.55, 0.66)
          ..lineTo(0.63, 0.5)
          ..close();
        _inFront(canvas, line, bolt);
    }
    canvas.restore();
    canvas.restore();
  }

  void _sun(Canvas canvas, Paint line, Offset c, double r) {
    canvas.drawCircle(c, r, line);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * (r * 1.6), c + dir * (r * 2.2), line);
    }
  }

  /// The crescent: a disc with a smaller disc cut out of its upper right.
  void _moon(Canvas canvas, Paint line, Offset c, double r) {
    final disc = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final bite = Path()
      ..addOval(Rect.fromCircle(center: c + Offset(r * 0.5, -r * 0.32), radius: r * 0.82));
    canvas.drawPath(Path.combine(PathOperation.difference, disc, bite), line);
  }

  /// A cloud outline. Whatever was drawn under it (and a thin gap around
  /// it) is erased first, so only its outline shows.
  void _cloud(Canvas canvas, Paint line, Offset shift, double scale) {
    var shape = Path()..addOval(Rect.fromCircle(center: const Offset(0.34, 0.58), radius: 0.15));
    for (final part in [
      Path()..addOval(Rect.fromCircle(center: const Offset(0.54, 0.47), radius: 0.21)),
      Path()..addOval(Rect.fromCircle(center: const Offset(0.72, 0.6), radius: 0.13)),
      Path()..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(0.19, 0.57, 0.85, 0.73),
          const Radius.circular(0.08),
        ),
      ),
    ]) {
      shape = Path.combine(PathOperation.union, shape, part);
    }
    // Scale about (0.5, 0.6), then shift.
    final m = Float64List(16)
      ..[0] = scale
      ..[5] = scale
      ..[10] = 1
      ..[15] = 1
      ..[12] = 0.5 + shift.dx - 0.5 * scale
      ..[13] = 0.6 + shift.dy - 0.6 * scale;
    _inFront(canvas, line, shape.transform(m));
  }

  /// Erases what is under [shape] plus a thin gap around it, then outlines it.
  void _inFront(Canvas canvas, Paint line, Path shape) {
    final erase = Paint()..blendMode = BlendMode.clear;
    canvas.drawPath(shape, erase);
    canvas.drawPath(
      shape,
      erase
        ..style = PaintingStyle.stroke
        ..strokeWidth = _w * 3,
    );
    canvas.drawPath(shape, line);
  }

  void _flake(Canvas canvas, Paint line, Offset c, double r) {
    for (var i = 0; i < 3; i++) {
      final a = i * math.pi / 3 + math.pi / 6;
      final d = Offset(math.cos(a), math.sin(a)) * r;
      canvas.drawLine(c - d, c + d, line);
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.sky != sky || old.ink != ink;
}
