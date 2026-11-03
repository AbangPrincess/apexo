import 'package:flutter_test/flutter_test.dart';
import 'package:apexo/core/activity_type.dart';
import 'package:apexo/core/geo.dart';
import 'package:apexo/core/ride_tracker.dart';
import 'package:apexo/core/stats.dart';

void main() {
  const origin = GeoPoint(6.5, 124.85);
  final t0 = DateTime(2026, 11, 3, 6);

  /// A fix [east] meters from origin at second [s].
  Fix fix(int s, double east, {double speed = -1, double acc = 5}) {
    final p = offsetM(origin, eastM: east);
    return Fix(
      p.lat,
      p.lng,
      t0.add(Duration(seconds: s)),
      accuracyM: acc,
      speedMps: speed < 0 ? null : speed,
    );
  }

  test('steady ride: distance, moving time, average and max', () {
    final r = RideTracker(ActivityType.cycling)..start(t0);
    for (var s = 0; s <= 60; s++) {
      r.addFix(fix(s, s * 5.0));
    }
    final end = t0.add(const Duration(seconds: 60));
    expect(r.distanceM, closeTo(300, 1));
    expect(r.movingTimeAt(end).inSeconds, 60);
    expect(r.avgKmhAt(end), closeTo(18, 0.2));
    expect(r.maxKmh, closeTo(18, 0.5));
    expect(r.currentKmh, closeTo(18, 0.5));
    expect(r.path.length, 61);
  });

  test('inaccurate fixes and GPS jumps are dropped', () {
    final r = RideTracker(ActivityType.cycling)..start(t0);
    expect(r.addFix(fix(0, 0)), isTrue);
    expect(r.addFix(fix(1, 5, acc: 45)), isFalse); // worse than 30 m
    expect(r.addFix(fix(2, 900)), isFalse); // 450 m/s
    expect(r.addFix(fix(3, 15)), isTrue);
    expect(r.droppedFixes, 2);
    expect(r.distanceM, closeTo(15, 0.5));
  });

  test('auto-pause stops the clock from when the stop began', () {
    final r = RideTracker(ActivityType.cycling)..start(t0);
    var east = 0.0;
    for (var s = 0; s <= 30; s++) {
      r.addFix(fix(s, east += 5, speed: 5));
    }
    for (var s = 31; s <= 50; s++) {
      r.addFix(fix(s, east, speed: 0));
    }
    expect(r.state, RideState.autoPaused);
    expect(r.currentKmh, 0);
    for (var s = 51; s <= 60; s++) {
      r.addFix(fix(s, east += 5, speed: 5));
    }
    expect(r.state, RideState.recording);
    // 31 s before the stop + 9 s after it.
    expect(r.movingTimeAt(t0.add(const Duration(seconds: 60))).inSeconds, inInclusiveRange(39, 41));
  });

  test('auto-pause threshold depends on the activity type', () {
    for (final (type, expected) in [
      (ActivityType.cycling, RideState.recording),
      (ActivityType.motorcycling, RideState.autoPaused),
    ]) {
      final r = RideTracker(type)..start(t0);
      for (var s = 0; s <= 15; s++) {
        r.addFix(fix(s, s * 0.6, speed: 0.6)); // 2.2 km/h
      }
      expect(r.state, expected, reason: type.name);
    }
  });

  test('manual pause excludes time and the distance of the gap', () {
    final r = RideTracker(ActivityType.cycling)..start(t0);
    r.addFix(fix(0, 0));
    r.addFix(fix(10, 50));
    r.pause(t0.add(const Duration(seconds: 10)));
    expect(r.addFix(fix(20, 100)), isFalse);
    r.resume(t0.add(const Duration(seconds: 100)));
    r.addFix(fix(100, 500));
    r.addFix(fix(110, 550));
    expect(r.distanceM, closeTo(100, 1));
    expect(r.movingTimeAt(t0.add(const Duration(seconds: 110))).inSeconds, 20);
    r.finish(t0.add(const Duration(seconds: 110)));
    expect(r.state, RideState.finished);
    expect(r.addFix(fix(120, 600)), isFalse);
  });
}
