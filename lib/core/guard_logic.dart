import 'dart:math' as math;

import 'geo.dart';

enum GeofenceEvent { exit, reentry }

/// SPEC P5 geofence rule: an exit counts only after 2 consecutive fixes
/// outside radius + accuracy, alerts once per exit, and re-arms after 2
/// consecutive fixes back inside, so GPS jitter at the edge cannot repeat it.
class GeofenceWatch {
  GeofenceWatch(this.boundary, {this.fixesNeeded = 2});

  final Boundary boundary;
  final int fixesNeeded;
  int _outside = 0;
  int _inside = 0;
  bool _tripped = false;

  /// True from an exit until the vehicle is back inside.
  bool get tripped => _tripped;

  double distanceFrom(GeoPoint p) => distanceM(boundary.center, p);

  GeofenceEvent? addFix(GeoPoint p, double accuracyM) {
    if (insideBoundary(p.lat, p.lng, boundary, accuracyM)) {
      _outside = 0;
      _inside++;
      if (_tripped && _inside >= fixesNeeded) {
        _tripped = false;
        return GeofenceEvent.reentry;
      }
      return null;
    }
    _inside = 0;
    _outside++;
    if (!_tripped && _outside >= fixesNeeded) {
      _tripped = true;
      return GeofenceEvent.exit;
    }
    return null;
  }
}

/// Low-battery alert once at [low] percent, re-armed after charging past
/// [reset] so a level hovering at 15 % cannot repeat it.
class BatteryWatch {
  BatteryWatch({this.low = 15, this.reset = 20});

  final int low;
  final int reset;
  bool _fired = false;

  bool addLevel(int percent) {
    if (percent >= reset) _fired = false;
    if (percent > low || _fired) return false;
    _fired = true;
    return true;
  }
}

enum NudgeSensitivity {
  low('Low', 3.0),
  medium('Medium', 1.5),
  high('High', 0.8);

  const NudgeSensitivity(this.label, this.thresholdMs2);
  final String label;

  /// Linear acceleration (gravity removed) that counts as a jolt, in m/s².
  final double thresholdMs2;
}

/// Accelerometer nudges: [jolts] above the threshold within [window] count
/// as movement, then it stays quiet for [cooldown]. Single bumps (a passing
/// truck, wind) do not trigger it.
class NudgeDetector {
  NudgeDetector(
    this.sensitivity, {
    this.jolts = 3,
    this.window = const Duration(seconds: 2),
    this.cooldown = const Duration(minutes: 5),
  });

  final NudgeSensitivity sensitivity;
  final int jolts;
  final Duration window;
  final Duration cooldown;
  final _hits = <DateTime>[];
  DateTime? _lastAlert;

  /// [x], [y], [z] are linear acceleration without gravity.
  bool add(double x, double y, double z, DateTime t) {
    final jolt = math.sqrt(x * x + y * y + z * z);
    if (jolt < sensitivity.thresholdMs2) return false;
    final last = _lastAlert;
    if (last != null && t.difference(last) < cooldown) return false;
    _hits
      ..add(t)
      ..removeWhere((h) => t.difference(h) > window);
    if (_hits.length < jolts) return false;
    _hits.clear();
    _lastAlert = t;
    return true;
  }
}
