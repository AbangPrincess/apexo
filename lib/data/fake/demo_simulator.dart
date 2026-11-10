import 'dart:async';
import 'dart:math' as math;

import '../../core/geo.dart';
import '../../core/guard_logic.dart';
import '../../core/units.dart';
import '../models/circle.dart';
import '../models/circle_alert.dart';
import '../models/user.dart';
import 'demo_seed.dart';

/// What the simulator may read and write in the demo backend.
abstract interface class DemoWorld {
  Member? member(String uid);
  void putMember(Member member);
  CircleAlert? alert(String id);

  /// Adds the alert, or replaces the one with the same id.
  void putAlert(CircleAlert alert);
}

/// Moves John around the loop once per [interval]. The bike is guarded with a
/// 50 m boundary, so ~20 s in the geofence trips and an alert is written that
/// then follows the bike. Sarah rides the scooter loop with a short stop
/// every two minutes.
class DemoSimulator {
  DemoSimulator(
    this.world, {
    required List<GeoPoint> loop,
    required this.boundary,
    List<GeoPoint>? sarahLoop,
    this.interval = const Duration(seconds: 1),
  }) : _john = LoopRider(loop),
       _sarah = sarahLoop == null ? null : LoopRider(sarahLoop);

  final DemoWorld world;
  final Boundary boundary;
  final Duration interval;
  final LoopRider _john;
  final LoopRider? _sarah;

  static const idleSteps = 8;
  static const cruiseMps = 5.6;
  static const sarahMps = 7.5;

  late final _fence = GeofenceWatch(boundary);
  Timer? _timer;
  int _steps = 0;
  String? _alertId;

  bool get running => _timer != null;
  bool get alerted => _alertId != null;
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
    if (_steps > idleSteps) _moveJohn(now);
    if (_sarah != null && _steps > idleSteps * 2) {
      _moveSarah(now);
    } else if (_steps % 60 == 0) {
      _heartbeat(DemoIds.sarah, now);
    }
  }

  void _moveJohn(DateTime now) {
    final john = world.member(DemoIds.john);
    if (john == null) return;
    final mps = cruiseMps + 1.2 * math.sin(_steps / 7);
    final prev = _john.position;
    final pos = _john.advance(mps * _secs);

    // Same rule the real guard uses. The demo alerts once per session, so
    // later laps through the boundary stay quiet.
    final exit = _fence.addFix(pos, 5) == GeofenceEvent.exit;

    var status = john.status == MemberStatus.alert ? MemberStatus.alert : MemberStatus.tracking;
    var vehicle = john.vehicle;
    final open = _alertId == null ? null : world.alert(_alertId!);
    if (exit && _alertId == null) {
      status = MemberStatus.alert;
      vehicle = vehicle?.withStatus(VehicleStatus.stolen);
      final name = vehicle?.name ?? 'vehicle';
      _alertId = 'alert-${now.microsecondsSinceEpoch}';
      world.putAlert(
        CircleAlert(
          id: _alertId!,
          type: AlertType.geofence,
          ownerUid: DemoIds.john,
          ownerName: john.displayName,
          vehicleId: 'john-mtb',
          vehicleName: name,
          message: "${john.displayName}'s $name is on the move",
          lat: pos.lat,
          lng: pos.lng,
          distanceM: _fence.distanceFrom(pos),
          radiusM: boundary.radiusM,
          ts: now,
        ),
      );
    } else if (open != null && open.recoveredAt == null && _steps % 5 == 0) {
      // Like the real guard, the open alert follows the vehicle.
      world.putAlert(
        open.copyWith(lat: pos.lat, lng: pos.lng, distanceM: _fence.distanceFrom(pos)),
      );
    }

    world.putMember(
      john.copyWith(
        lat: pos.lat,
        lng: pos.lng,
        speedKmh: mpsToKmh(mps),
        heading: bearingDeg(prev, pos),
        battery: _steps % 90 == 0 ? math.max(5, john.battery - 1) : john.battery,
        status: status,
        vehicle: vehicle,
        ts: now,
      ),
    );
  }

  void _moveSarah(DateTime now) {
    final sarah = world.member(DemoIds.sarah);
    final rider = _sarah;
    if (sarah == null || rider == null) return;
    // Rides for 100 s, then waits 20 s (a light, a shop), and repeats.
    final stopped = _steps % 120 >= 100;
    final mps = stopped ? 0.0 : sarahMps + 1.5 * math.sin(_steps / 9);
    final prev = rider.position;
    final pos = rider.advance(mps * _secs);
    // While stopped only a heartbeat is written, like the real write budget.
    if (stopped && sarah.status == MemberStatus.parked && _steps % 60 != 0) return;
    world.putMember(
      sarah.copyWith(
        lat: pos.lat,
        lng: pos.lng,
        speedKmh: mpsToKmh(mps),
        heading: stopped ? sarah.heading : bearingDeg(prev, pos),
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
