import 'dart:async';
import 'dart:math' as math;

import '../../core/geo.dart';
import '../../core/units.dart';
import '../models/circle.dart';
import '../models/circle_alert.dart';
import '../models/user.dart';
import 'demo_seed.dart';

/// What the simulator may read and write in the demo backend.
abstract interface class DemoWorld {
  Member? member(String uid);
  void putMember(Member member);
  void addAlert(CircleAlert alert);
}

/// Moves Jero around his loop once per [interval]. His bike is guarded with a
/// 50 m boundary, so ~20 s in the geofence trips and an alert is written.
/// Shane rides his scooter loop with a short stop every two minutes.
class DemoSimulator {
  DemoSimulator(
    this.world, {
    required List<GeoPoint> loop,
    required this.boundary,
    List<GeoPoint>? shaneLoop,
    this.interval = const Duration(seconds: 1),
  }) : _jero = LoopRider(loop),
       _shane = shaneLoop == null ? null : LoopRider(shaneLoop);

  final DemoWorld world;
  final Boundary boundary;
  final Duration interval;
  final LoopRider _jero;
  final LoopRider? _shane;

  static const idleSteps = 8;
  static const cruiseMps = 5.6;
  static const shaneMps = 7.5;

  Timer? _timer;
  int _steps = 0;
  int _outsideRun = 0;
  bool _alerted = false;

  bool get running => _timer != null;
  bool get alerted => _alerted;
  double get _secs => interval.inMilliseconds / 1000;

  void start() => _timer ??= Timer.periodic(interval, (_) => step());

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Advances the world by one interval. Public so tests can drive it.
  void step() {
    _steps++;
    final now = DateTime.now();
    if (_steps > idleSteps) _moveJero(now);
    if (_shane != null && _steps > idleSteps * 2) {
      _moveShane(now);
    } else if (_steps % 60 == 0) {
      _heartbeat(DemoIds.shane, now);
    }
  }

  void _moveJero(DateTime now) {
    final jero = world.member(DemoIds.jero);
    if (jero == null) return;
    final mps = cruiseMps + 1.2 * math.sin(_steps / 7);
    final prev = _jero.position;
    final pos = _jero.advance(mps * _secs);

    // Same rule the real guard uses: 2 consecutive fixes outside radius + accuracy.
    final outside = !insideBoundary(pos.lat, pos.lng, boundary, 5);
    _outsideRun = outside ? _outsideRun + 1 : 0;

    var status = jero.status == MemberStatus.alert ? MemberStatus.alert : MemberStatus.tracking;
    var vehicle = jero.vehicle;
    if (_outsideRun >= 2 && !_alerted) {
      _alerted = true;
      status = MemberStatus.alert;
      vehicle = vehicle?.withStatus(VehicleStatus.stolen);
      final name = vehicle?.name ?? 'vehicle';
      world.addAlert(
        CircleAlert(
          id: 'alert-${now.microsecondsSinceEpoch}',
          type: AlertType.geofence,
          ownerUid: DemoIds.jero,
          vehicleName: name,
          message: "${jero.displayName}'s $name is on the move",
          lat: pos.lat,
          lng: pos.lng,
          distanceM: distanceM(boundary.center, pos),
          ts: now,
        ),
      );
    }

    world.putMember(
      jero.copyWith(
        lat: pos.lat,
        lng: pos.lng,
        speedKmh: mpsToKmh(mps),
        heading: bearingDeg(prev, pos),
        battery: _steps % 90 == 0 ? math.max(5, jero.battery - 1) : jero.battery,
        status: status,
        vehicle: vehicle,
        ts: now,
      ),
    );
  }

  void _moveShane(DateTime now) {
    final shane = world.member(DemoIds.shane);
    final rider = _shane;
    if (shane == null || rider == null) return;
    // Rides for 100 s, then waits 20 s (a light, a shop), and repeats.
    final stopped = _steps % 120 >= 100;
    final mps = stopped ? 0.0 : shaneMps + 1.5 * math.sin(_steps / 9);
    final prev = rider.position;
    final pos = rider.advance(mps * _secs);
    // While stopped only a heartbeat is written, like the real write budget.
    if (stopped && shane.status == MemberStatus.parked && _steps % 60 != 0) return;
    world.putMember(
      shane.copyWith(
        lat: pos.lat,
        lng: pos.lng,
        speedKmh: mpsToKmh(mps),
        heading: stopped ? shane.heading : bearingDeg(prev, pos),
        status: stopped ? MemberStatus.parked : MemberStatus.tracking,
        ts: now,
      ),
    );
  }

  void _heartbeat(String uid, DateTime now) {
    final m = world.member(uid);
    if (m != null) world.putMember(m.copyWith(ts: now));
  }
}

/// Walks a closed polyline by distance, wrapping at the end.
class LoopRider {
  LoopRider(this.loop) : _cumulative = _cumulativeDistances(loop);

  final List<GeoPoint> loop;
  final List<double> _cumulative;
  double _traveled = 0;

  GeoPoint get position => _at(_traveled);

  GeoPoint advance(double meters) {
    _traveled = (_traveled + meters) % _cumulative.last;
    return position;
  }

  GeoPoint _at(double d) {
    var i = 1;
    while (i < _cumulative.length - 1 && _cumulative[i] < d) {
      i++;
    }
    final segStart = _cumulative[i - 1];
    final segLen = _cumulative[i] - segStart;
    final f = segLen <= 0 ? 0.0 : ((d - segStart) / segLen).clamp(0.0, 1.0);
    final a = loop[i - 1];
    final b = loop[i];
    return GeoPoint(a.lat + (b.lat - a.lat) * f, a.lng + (b.lng - a.lng) * f);
  }

  static List<double> _cumulativeDistances(List<GeoPoint> pts) {
    final out = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      out.add(out.last + distanceM(pts[i - 1], pts[i]));
    }
    return out;
  }
}
