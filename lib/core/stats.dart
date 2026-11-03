import 'geo.dart';
import 'units.dart';

/// One timestamped GPS fix.
class Fix {
  const Fix(this.lat, this.lng, this.time, {this.accuracyM = 0, this.speedMps});

  final double lat;
  final double lng;
  final DateTime time;
  final double accuracyM;

  /// Speed reported by the device, when it has one.
  final double? speedMps;

  GeoPoint get point => GeoPoint(lat, lng);
}

class SpeedStats {
  const SpeedStats({
    required this.distanceM,
    required this.movingSec,
    required this.avgKmh,
    required this.maxKmh,
    required this.droppedFixes,
  });

  final double distanceM;
  final int movingSec;
  final double avgKmh;
  final double maxKmh;
  final int droppedFixes;

  static const empty = SpeedStats(
    distanceM: 0,
    movingSec: 0,
    avgKmh: 0,
    maxKmh: 0,
    droppedFixes: 0,
  );
}

/// Distance, moving time and average/max speed from raw fixes.
///
/// A fix whose implied speed from the last accepted fix exceeds [maxSpeedMps]
/// is a GPS jump and is dropped. If [reanchorAfter] fixes in a row are dropped,
/// the anchor itself was probably the bad fix, so tracking restarts from the
/// current fix (without adding that gap's distance). Segments slower than
/// [minMovingMps] count as stopped and are left out of moving time and average.
SpeedStats computeSpeedStats(
  List<Fix> fixes, {
  required double maxSpeedMps,
  double minMovingMps = 0.3,
  int reanchorAfter = 3,
}) {
  if (fixes.length < 2) return SpeedStats.empty;
  var anchor = fixes.first;
  var distance = 0.0;
  var movingDistance = 0.0;
  var movingMs = 0;
  var maxMps = 0.0;
  var dropped = 0;
  var rejectedRun = 0;

  for (final fix in fixes.skip(1)) {
    final dtMs = fix.time.difference(anchor.time).inMilliseconds;
    if (dtMs <= 0) {
      dropped++;
      continue;
    }
    final d = distanceM(anchor.point, fix.point);
    final mps = d / (dtMs / 1000);
    if (mps > maxSpeedMps) {
      dropped++;
      rejectedRun++;
      if (rejectedRun >= reanchorAfter) {
        anchor = fix;
        rejectedRun = 0;
      }
      continue;
    }
    rejectedRun = 0;
    distance += d;
    if (mps >= minMovingMps) {
      movingDistance += d;
      movingMs += dtMs;
      if (mps > maxMps) maxMps = mps;
    }
    anchor = fix;
  }

  final movingSec = movingMs ~/ 1000;
  final avgMps = movingMs > 0 ? movingDistance / (movingMs / 1000) : 0.0;
  return SpeedStats(
    distanceM: distance,
    movingSec: movingSec,
    avgKmh: mpsToKmh(avgMps),
    maxKmh: mpsToKmh(maxMps),
    droppedFixes: dropped,
  );
}
