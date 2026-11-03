import 'activity_type.dart';
import 'geo.dart';
import 'stats.dart';
import 'units.dart';

enum RideState { idle, recording, paused, autoPaused, finished }

/// Turns a raw GPS stream into live ride stats. Time comes only from fix
/// timestamps and the `now` passed in, so it is fully testable.
///
/// Filters: fixes less accurate than [maxAccuracyM] are dropped, and so are
/// fixes implying a speed above the activity's cap (GPS jumps). Auto-pause
/// kicks in after [autoPauseAfter] below the activity's threshold and the
/// clock is rolled back to when the stop began.
class RideTracker {
  RideTracker(
    this.type, {
    this.maxAccuracyM = 30,
    this.autoPauseAfter = const Duration(seconds: 10),
    this.reanchorAfter = 3,
  });

  final ActivityType type;
  final double maxAccuracyM;
  final Duration autoPauseAfter;
  final int reanchorAfter;

  RideState _state = RideState.idle;
  DateTime? _startedAt;
  DateTime? _activeSince;
  Duration _banked = Duration.zero;
  Fix? _anchor;
  int _rejectedRun = 0;
  DateTime? _stillSince;
  double _distanceM = 0;
  double _maxMps = 0;
  double _currentMps = 0;
  int _dropped = 0;
  final List<GeoPoint> _path = [];

  RideState get state => _state;
  DateTime? get startedAt => _startedAt;
  double get distanceM => _distanceM;
  double get currentKmh => _state == RideState.recording ? mpsToKmh(_currentMps) : 0;
  double get maxKmh => mpsToKmh(_maxMps);
  int get droppedFixes => _dropped;
  List<GeoPoint> get path => List.unmodifiable(_path);
  bool get isLive => _state == RideState.recording || _state == RideState.autoPaused;

  Duration movingTimeAt(DateTime now) {
    final since = _activeSince;
    if (since == null) return _banked;
    final live = now.difference(since);
    return live.isNegative ? _banked : _banked + live;
  }

  double avgKmhAt(DateTime now) {
    final s = movingTimeAt(now).inMilliseconds / 1000;
    return s <= 0 ? 0 : mpsToKmh(_distanceM / s);
  }

  void start(DateTime t) {
    if (_state != RideState.idle) return;
    _state = RideState.recording;
    _startedAt = t;
    _activeSince = t;
  }

  void pause(DateTime t) {
    if (!isLive) return;
    if (_state == RideState.recording) _bank(t);
    _state = RideState.paused;
    // The gap while paused is not counted as distance.
    _anchor = null;
    _stillSince = null;
    _currentMps = 0;
  }

  void resume(DateTime t) {
    if (_state != RideState.paused) return;
    _state = RideState.recording;
    _activeSince = t;
  }

  void finish(DateTime t) {
    if (_state == RideState.recording) _bank(t);
    _state = RideState.finished;
    _currentMps = 0;
  }

  /// Returns true when the fix was accepted.
  bool addFix(Fix fix) {
    if (!isLive) return false;
    if (fix.accuracyM > maxAccuracyM) {
      _dropped++;
      return false;
    }
    final anchor = _anchor;
    if (anchor == null) {
      _accept(fix, 0, null);
      return true;
    }
    final dtMs = fix.time.difference(anchor.time).inMilliseconds;
    if (dtMs <= 0) {
      _dropped++;
      return false;
    }
    final d = haversineM(anchor.lat, anchor.lng, fix.lat, fix.lng);
    final implied = d / (dtMs / 1000);
    if (implied > type.speedCapMps) {
      _dropped++;
      // Several rejections in a row mean the anchor itself was the bad fix.
      if (++_rejectedRun >= reanchorAfter) {
        _rejectedRun = 0;
        _anchor = fix;
      }
      return false;
    }
    _rejectedRun = 0;
    _accept(fix, d, implied);
    return true;
  }

  void _accept(Fix fix, double d, double? implied) {
    final reported = fix.speedMps;
    final mps = reported != null && reported >= 0 ? reported : (implied ?? 0);
    _currentMps = mps;
    final slow = mpsToKmh(mps) < type.autoPauseKmh;

    if (_state == RideState.autoPaused) {
      if (!slow) {
        _state = RideState.recording;
        _activeSince = fix.time;
        _stillSince = null;
      }
    } else if (slow) {
      final still = _stillSince ??= fix.time;
      if (fix.time.difference(still) >= autoPauseAfter) {
        _bank(still);
        _state = RideState.autoPaused;
      }
    } else {
      _stillSince = null;
    }

    if (_state == RideState.recording) {
      _distanceM += d;
      if (mps <= type.speedCapMps && mps > _maxMps) _maxMps = mps;
      _path.add(fix.point);
    }
    _anchor = fix;
  }

  void _bank(DateTime until) {
    final since = _activeSince;
    if (since != null && until.isAfter(since)) _banked += until.difference(since);
    _activeSince = null;
  }
}
