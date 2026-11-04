import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:apexo/core/activity_type.dart';
import 'package:apexo/core/geo.dart';
import 'package:apexo/core/ride_tracker.dart';
import 'package:apexo/core/stats.dart';

void main() {
  const origin = GeoPoint(6.5, 124.85);
  final t0 = DateTime(2026, 11, 3, 6);
  DateTime at(int s) => t0.add(Duration(seconds: s));

  /// A fix [east] (and [north]) meters from origin at second [s].
  Fix fix(int s, double east, {double north = 0, double speed = -1, double acc = 5}) {
    final p = offsetM(origin, eastM: east, northM: north);
    return Fix(p.lat, p.lng, at(s), accuracyM: acc, speedMps: speed < 0 ? null : speed);
  }

  test('standing still with GPS scatter: no distance, no speed, no moving time', () {
    for (final type in ActivityType.values) {
      final r = RideTracker(type)..start(t0);
      for (var s = 0; s <= 180; s++) {
        // Wobbles of up to ~8 m inside a 10 m accuracy, like indoors.
        r.addFix(fix(s, 6 * math.sin(s * 1.7), north: 5 * math.cos(s * 2.3), acc: 10, speed: 0.4));
      }
      expect(r.distanceM, 0, reason: type.name);
      expect(r.currentKmh, 0, reason: type.name);
      expect(r.movingTimeAt(at(180)), Duration.zero, reason: type.name);
      expect(r.waiting, isTrue, reason: type.name);
      expect(r.position, isNotNull, reason: 'the map still shows where you are');
    }
  });

  test('scatter without a reported speed (web) is ignored too', () {
    final r = RideTracker(ActivityType.cycling)..start(t0);
    for (var s = 0; s <= 120; s++) {
      r.addFix(fix(s, 7 * math.sin(s * 2.9), north: 6 * math.cos(s * 1.3), acc: 12));
    }
    expect(r.distanceM, 0);
    expect(r.movingTimeAt(at(120)), Duration.zero);
  });

  test('steady ride: distance, moving time, average and max', () {
    final r = RideTracker(ActivityType.cycling)..start(t0);
    expect(r.waiting, isTrue);
    for (var s = 0; s <= 60; s++) {
      r.addFix(fix(s, s * 5.0));
    }
    expect(r.state, RideState.recording);
    expect(r.distanceM, closeTo(300, 6));
    expect(r.movingTimeAt(at(60)).inSeconds, 60);
    expect(r.avgKmhAt(at(60)), closeTo(18, 0.5));
    expect(r.maxKmh, closeTo(18, 0.5));
    expect(r.currentKmh, closeTo(18, 0.5));
    expect(r.path.length, greaterThan(25));
  });

  test('inaccurate fixes and GPS jumps are dropped', () {
    final r = RideTracker(ActivityType.cycling)..start(t0);
    expect(r.addFix(fix(0, 0)), isTrue);
    expect(r.addFix(fix(1, 5, acc: 45)), isFalse); // worse than 30 m
    expect(r.addFix(fix(2, 900)), isFalse); // 450 m/s
    expect(r.droppedFixes, 2);
    for (var s = 3; s <= 12; s++) {
      expect(r.addFix(fix(s, s * 5.0)), isTrue);
    }
    expect(r.distanceM, closeTo(60, 6));
  });

  test('the clock freezes when you stop and resumes when you move', () {
    final r = RideTracker(ActivityType.cycling)..start(t0);
    var east = 0.0;
    for (var s = 0; s <= 30; s++) {
      r.addFix(fix(s, east += 5, speed: 5));
    }
    final ridden = r.movingTimeAt(at(30)).inSeconds;
    for (var s = 31; s <= 50; s++) {
      r.addFix(fix(s, east, speed: 0));
    }
    expect(r.state, RideState.autoPaused);
    expect(r.currentKmh, 0);
    expect(r.movingTimeAt(at(50)).inSeconds, ridden, reason: 'no time counted while still');
    for (var s = 51; s <= 60; s++) {
      r.addFix(fix(s, east += 5, speed: 5));
    }
    expect(r.state, RideState.recording);
    expect(r.movingTimeAt(at(60)).inSeconds, inInclusiveRange(ridden + 8, ridden + 10));
  });

  test('the moving speed depends on the activity type', () {
    // 1.2 m/s = 4.3 km/h: a slow jog counts; a motorbike that slow is just
    // creeping in traffic.
    for (final (type, expected) in [
      (ActivityType.running, RideState.recording),
      (ActivityType.motorcycling, RideState.autoPaused),
    ]) {
      final r = RideTracker(type)..start(t0);
      for (var s = 0; s <= 20; s++) {
        r.addFix(fix(s, s * 1.2, speed: 1.2));
      }
      expect(r.state, expected, reason: type.name);
    }
  });

  test('manual pause excludes time and the distance of the gap', () {
    final r = RideTracker(ActivityType.cycling)..start(t0);
    for (var s = 0; s <= 10; s++) {
      r.addFix(fix(s, s * 5.0));
    }
    r.pause(at(10));
    expect(r.addFix(fix(20, 100)), isFalse);
    r.resume(at(100));
    expect(r.waiting, isFalse);
    for (var s = 100; s <= 110; s++) {
      r.addFix(fix(s, 500 + (s - 100) * 5.0));
    }
    expect(r.distanceM, closeTo(100, 10));
    expect(r.movingTimeAt(at(110)).inSeconds, inInclusiveRange(18, 20));
    r.finish(at(110));
    expect(r.state, RideState.finished);
    expect(r.addFix(fix(120, 600)), isFalse);
  });
}
