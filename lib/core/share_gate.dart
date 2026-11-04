import 'geo.dart';

/// Decides when a live position is worth a write (SPEC G4 budget): while
/// moving, at most every 5 s and only after 10 m; otherwise a heartbeat every
/// 60 s. A status change skips the distance check but never the 5 s floor.
class ShareGate {
  ShareGate({
    this.minInterval = const Duration(seconds: 5),
    this.minDistanceM = 10,
    this.heartbeat = const Duration(seconds: 60),
  });

  final Duration minInterval;
  final double minDistanceM;
  final Duration heartbeat;

  GeoPoint? _lastPoint;
  DateTime? _lastAt;

  DateTime? get lastWrite => _lastAt;

  bool shouldPublish(GeoPoint p, DateTime now, {bool changed = false}) {
    final last = _lastPoint;
    final at = _lastAt;
    final due =
        last == null ||
        at == null ||
        now.difference(at) >= heartbeat ||
        (now.difference(at) >= minInterval && (changed || distanceM(last, p) >= minDistanceM));
    if (due) {
      _lastPoint = p;
      _lastAt = now;
    }
    return due;
  }

  /// Forgets the last write, so the next position is published at once.
  void reset() {
    _lastPoint = null;
    _lastAt = null;
  }
}
