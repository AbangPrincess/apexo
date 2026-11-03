import 'package:flutter_test/flutter_test.dart';
import 'package:pedaltrack/core/activity_type.dart';
import 'package:pedaltrack/core/stats.dart';

void main() {
  final t0 = DateTime.utc(2026, 1, 1, 8);
  // 0.0005 deg of longitude on the equator is ~55.6 m; every 10 s = ~20 km/h.
  Fix at(int i, {double lng = 0, int? sec}) =>
      Fix(0, lng == 0 ? i * 0.0005 : lng, t0.add(Duration(seconds: sec ?? i * 10)));

  final capBike = ActivityType.cycling.speedCapMps;

  test('steady ride gives distance, moving time and average', () {
    final fixes = [for (var i = 0; i <= 10; i++) at(i)];
    final s = computeSpeedStats(fixes, maxSpeedMps: capBike);
    expect(s.distanceM, closeTo(555.97, 0.5));
    expect(s.movingSec, 100);
    expect(s.avgKmh, closeTo(20.0, 0.1));
    expect(s.maxKmh, closeTo(20.0, 0.1));
    expect(s.droppedFixes, 0);
  });

  test('a GPS jump in the middle is dropped', () {
    final fixes = [
      for (var i = 0; i <= 5; i++) at(i),
      Fix(0, 0.05, t0.add(const Duration(seconds: 55))), // ~5.3 km in 5 s
      for (var i = 6; i <= 10; i++) at(i),
    ];
    final s = computeSpeedStats(fixes, maxSpeedMps: capBike);
    expect(s.droppedFixes, 1);
    expect(s.distanceM, closeTo(555.97, 0.5));
    expect(s.maxKmh, lessThan(25));
  });

  test('a bad first fix is recovered by re-anchoring', () {
    final fixes = [
      Fix(0.5, 0.5, t0), // far away
      for (var i = 1; i <= 10; i++) at(i),
    ];
    final s = computeSpeedStats(fixes, maxSpeedMps: capBike);
    expect(s.droppedFixes, 3);
    // Tracking restarts at fix 3, so segments 3->10 remain.
    expect(s.distanceM, closeTo(7 * 55.6, 1));
  });

  test('stopped time is excluded from moving time', () {
    final fixes = [
      at(0),
      at(1),
      Fix(0, 0.0005, t0.add(const Duration(seconds: 70))), // stood still 60 s
      Fix(0, 0.0010, t0.add(const Duration(seconds: 80))),
    ];
    final s = computeSpeedStats(fixes, maxSpeedMps: capBike);
    expect(s.movingSec, 20);
    expect(s.avgKmh, closeTo(20.0, 0.1));
  });

  test('too few fixes or duplicate timestamps are safe', () {
    expect(computeSpeedStats([at(0)], maxSpeedMps: capBike).distanceM, 0);
    final dup = computeSpeedStats([at(0), at(1, sec: 0)], maxSpeedMps: capBike);
    expect(dup.droppedFixes, 1);
    expect(dup.avgKmh, 0);
  });

  test('per-type speed caps', () {
    expect(ActivityType.cycling.speedCapMps, 20);
    expect(ActivityType.motorcycling.speedCapMps, 60);
    expect(ActivityType.driving.speedCapMps, 70);
  });
}
