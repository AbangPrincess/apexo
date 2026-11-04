import 'dart:math' as math;

import 'activity_type.dart';
import 'geo.dart';
import 'stats.dart';
import 'units.dart';

enum RideState { idle, recording, paused, autoPaused, finished }

/// Turns a raw GPS stream into live ride stats. Time comes only from fix
/// timestamps and the `now` passed in, so it is fully testable.
///
/// GPS wanders by a few meters even when the phone lies still, so a fix
/// only counts as movement when the straight-line displacement over the
/// last [window] beats the GPS's own margin of error (its accuracy, at least
/// the activity's step) at a speed of at least the activity's
/// [ActivityType.minMovingKmh]. Standing still therefore adds no distance,
/// shows no speed and stops the moving-time clock. Recording starts in
/// [RideState.autoPaused] and waits for the first real movement.
///
/// Fixes less accurate than [maxAccuracyM] are dropped, and so are fixes
/// implying a speed above the activity's cap (GPS jumps).
class RideTracker {
  RideTracker(
    this.type, {
    this.maxAccuracyM = 30,
    this.window = const Duration(seconds: 8),
    this.autoPauseAfter = const Duration(seconds: 5),
    this.reanchorAfter = 3,
  });

  final ActivityType type;
  final double maxAccuracyM;
  final Duration window;
  final Duration autoPauseAfter;
  final int reanchorAfter;

  /// The window must be at least this long before movement is judged.
  static const _minSpan = Duration(seconds: 3);

  RideState _state = RideState.idle;
  DateTime? _startedAt;
  DateTime? _activeSince;
  DateTime? _stoppedAt;
  Duration _banked = Duration.zero;
  final _recent = <Fix>[];
  Fix? _last;
  GeoPoint? _pathEnd;
  DateTime? _lastMoving;
  bool _movingNow = false;
  int _movingRun = 0;
  int _rejectedRun = 0;
  double _distanceM = 0;
  double _maxMps = 0;
  double _currentMps = 0;
  int _dropped = 0;
  final List<GeoPoint> _path = [];

  RideState get state => _state;
  DateTime? get startedAt => _startedAt;
  double get distanceM => _distanceM;
  double get currentKmh => _movingNow ? mpsToKmh(_currentMps) : 0;
  double get maxKmh => mpsToKmh(_maxMps);
  int get droppedFixes => _dropped;
  List<GeoPoint> get path => List.unmodifiable(_path);
  bool get isLive => _state == RideState.recording || _state == RideState.autoPaused;

  /// Where the phone is now (moving or not), for the live map.
  GeoPoint? get position => _last?.point;
  double? get accuracyM => _last?.accuracyM;

  /// Recording but not one real movement yet.
  bool get waiting =>
      _state == RideState.autoPaused && _banked == Duration.zero && _activeSince == null;

  /// The clock runs only while moving; it freezes the moment movement stops.
  Duration movingTimeAt(DateTime now) {
    final since = _activeSince;
    if (since == null) return _banked;
    final end = _movingNow ? now : (_lastMoving ?? since);
    final live = end.difference(since);
    return live.isNegative ? _banked : _banked + live;
  }

  double avgKmhAt(DateTime now) {
    final s = movingTimeAt(now).inMilliseconds / 1000;
    return s <= 0 ? 0 : mpsToKmh(_distanceM / s);
  }

  void start(DateTime t) {
    if (_state != RideState.idle) return;
    _state = RideState.autoPaused;
    _startedAt = t;
    _stoppedAt = t;
  }

  void pause(DateTime t) {
    if (!isLive) return;
    _bank(_movingNow ? t : _lastMoving);
    _state = RideState.paused;
    _stoppedAt = t;
    // The gap while paused is not counted as distance.
    _recent.clear();
    _pathEnd = null;
    _movingNow = false;
    _movingRun = 0;
    _currentMps = 0;
  }

  /// Waits for movement again, like the start.
  void resume(DateTime t) {
    if (_state != RideState.paused) return;
    _state = RideState.autoPaused;
    _stoppedAt = t;
  }

  void finish(DateTime t) {
    if (_state == RideState.recording) _bank(_movingNow ? t : _lastMoving);
    _state = RideState.finished;
    _movingNow = false;
    _currentMps = 0;
  }

  /// Returns true when the fix was used.
  bool addFix(Fix fix) {
    if (!isLive) return false;
    if (fix.accuracyM > maxAccuracyM) {
      _dropped++;
      return false;
    }
    final last = _last;
    if (last != null) {
      final dtMs = fix.time.difference(last.time).inMilliseconds;
      if (dtMs <= 0) {
        _dropped++;
        return false;
      }
      final jumpMps = haversineM(last.lat, last.lng, fix.lat, fix.lng) / (dtMs / 1000);
      if (jumpMps > type.speedCapMps) {
        _dropped++;
        if (++_rejectedRun < reanchorAfter) return false;
        // Several rejections in a row: the earlier fix was the bad one.
        // Start over from here without counting the gap.
        _recent.clear();
        _pathEnd = null;
      }
    }
    _rejectedRun = 0;
    _last = fix;
    _recent.add(fix);
    // Keep just enough history that the oldest fix is about [window] old.
    while (_recent.length > 2 && fix.time.difference(_recent[1].time) >= window) {
      _recent.removeAt(0);
    }
    _judge(fix);
    return true;
  }

  /// Compares the average position of the older half of the window with
  /// the newer half: averaging cancels most GPS scatter, while real
  /// movement survives it. Returns the speed when moving, else null.
  double? _movingMps(Fix fix, double margin) {
    if (_recent.length < 4 || fix.time.difference(_recent.first.time) < _minSpan) return null;
    final half = _recent.length ~/ 2;
    final a = _centroid(_recent.sublist(0, half));
    final b = _centroid(_recent.sublist(half));
    final dt = (b.$2 - a.$2) / 1000;
    if (dt <= 0) return null;
    final disp = haversineM(a.$1.lat, a.$1.lng, b.$1.lat, b.$1.lng);
    final reported = fix.speedMps;
    final mps = reported != null && reported >= 0 ? reported : disp / dt;
    return disp >= margin && mpsToKmh(mps) >= type.minMovingKmh ? mps : null;
  }

  static (GeoPoint, double) _centroid(List<Fix> fixes) {
    var lat = 0.0, lng = 0.0, ms = 0.0;
    for (final f in fixes) {
      lat += f.lat;
      lng += f.lng;
      ms += f.time.millisecondsSinceEpoch;
    }
    final n = fixes.length;
    return (GeoPoint(lat / n, lng / n), ms / n);
  }

  void _judge(Fix fix) {
    final first = _recent.first;
    final margin = math.max(type.minStepM, fix.accuracyM);
    final mps = _movingMps(fix, margin);
    // Starting needs two moving judgements in a row; one wild fix is not enough.
    _movingRun = mps == null ? 0 : _movingRun + 1;
    final moving = mps != null && (_movingNow || _movingRun >= 2);

    if (!moving) {
      _movingNow = false;
      _currentMps = 0;
      final since = _lastMoving;
      if (_state == RideState.recording &&
          since != null &&
          fix.time.difference(since) >= autoPauseAfter) {
        _bank(since);
        _state = RideState.autoPaused;
        _stoppedAt = since;
      }
      return;
    }

    if (_state == RideState.autoPaused) {
      // Movement began at the last fix still close to where the window
      // started, but never before the stop (or the start).
      var began = first;
      for (final f in _recent) {
        if (haversineM(first.lat, first.lng, f.lat, f.lng) > margin / 2) break;
        began = f;
      }
      final stopped = _stoppedAt;
      _activeSince = stopped != null && began.time.isBefore(stopped) ? stopped : began.time;
      _state = RideState.recording;
      if (_pathEnd == null) {
        _path.add(began.point);
        _pathEnd = began.point;
      }
    }
    _movingNow = true;
    _lastMoving = fix.time;
    _currentMps = mps;
    if (mps <= type.speedCapMps && mps > _maxMps) _maxMps = mps;

    // Path points are at least a step apart, wider when the GPS is unsure,
    // so zig-zag from scatter barely adds distance.
    final end = _pathEnd ?? fix.point;
    _pathEnd ??= fix.point;
    final seg = haversineM(end.lat, end.lng, fix.lat, fix.lng);
    if (seg >= math.max(type.minStepM, fix.accuracyM / 2)) {
      _distanceM += seg;
      _path.add(fix.point);
      _pathEnd = fix.point;
    }
  }

  void _bank(DateTime? until) {
    final since = _activeSince;
    if (since != null && until != null && until.isAfter(since)) {
      _banked += until.difference(since);
    }
    _activeSince = null;
  }
}
