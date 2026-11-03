import 'dart:math' as math;

import '../../core/geo.dart';

// Route shapes for demo data and the demo GPS.

/// A closed, slightly wavy loop around [c].
List<GeoPoint> demoLoop(
  GeoPoint c, {
  required double northM,
  required double eastM,
  double wobble = 0.08,
  int lobes = 3,
  int n = 160,
  double phase = 0,
}) {
  final pts = <GeoPoint>[];
  for (var i = 0; i <= n; i++) {
    final t = 2 * math.pi * i / n + phase;
    final r = 1 + wobble * math.sin(lobes * t);
    pts.add(offsetM(c, northM: northM * r * math.sin(t), eastM: eastM * r * math.cos(t)));
  }
  return pts;
}

/// Out along [bearing] with gentle bends, back on the other side of the road.
List<GeoPoint> demoOutAndBack(
  GeoPoint start, {
  required double lengthM,
  required double bearing,
  int n = 90,
}) {
  final b = bearing * math.pi / 180;
  GeoPoint at(double along, double side) => offsetM(
    start,
    northM: along * math.cos(b) - side * math.sin(b),
    eastM: along * math.sin(b) + side * math.cos(b),
  );
  final out = [
    for (var i = 0; i <= n; i++) at(lengthM * i / n, 70 * math.sin(i / n * 3 * math.pi)),
  ];
  final back = [
    for (var i = n; i >= 0; i--) at(lengthM * i / n, 70 * math.sin(i / n * 3 * math.pi) + 14),
  ];
  return [...out, ...back];
}
