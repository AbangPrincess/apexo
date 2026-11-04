import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../core/geo.dart';
import '../../core/guard_logic.dart';
import '../../core/share_gate.dart';
import '../../core/stats.dart';
import '../../data/models/circle_alert.dart';
import '../../data/models/user.dart';
import '../../data/repository.dart';
import '../alerts/alerts_controller.dart';
import '../record/location_source.dart';
import '../record/record_controller.dart';
import 'guard_reporter.dart';
import 'motion_source.dart';
import 'vehicles_controller.dart';

/// Guard mode for my active vehicle (SPEC P5). ARM sets the boundary at the
/// current spot. While this phone watches it, every fix goes through the
/// geofence rule, a 60 s heartbeat reports the battery, and nudge detection
/// can listen to the accelerometer. Alerts go to every circle I am in.
class GuardController extends ChangeNotifier {
  GuardController(
    AppRepository repo,
    this._vehicles,
    this._alerts,
    this._record, {
    this.readBattery,
    MotionSource? motion,
  }) : _nudges = NudgeWatch(motion ?? DeviceMotionSource()),
       _report = GuardReporter(repo, _vehicles) {
    _vehicles.addListener(_onVehicles);
  }

  final GuardReporter _report;
  final NudgeWatch _nudges;
  final VehiclesController _vehicles;
  final AlertsController _alerts;
  final RecordController _record;
  final Future<int?> Function()? readBattery;

  static const minRadiusM = 20.0;
  static const maxRadiusM = 500.0;
  double radiusM = 50;
  bool motionOn = false;
  NudgeSensitivity sensitivity = NudgeSensitivity.medium;

  GeofenceWatch? _fence;
  BatteryWatch _battery = BatteryWatch();
  final _followGate = ShareGate();
  StreamSubscription<Fix>? _fixSub;
  Timer? _beat;
  GeoPoint? _last;
  String? _watchingId;
  String? _openAlertId;
  bool _busy = false;

  /// The watched vehicle, else the active one.
  Vehicle? get vehicle {
    final id = _watchingId;
    if (id == null) return _vehicles.active;
    return _vehicles.vehicles.where((v) => v.id == id).firstOrNull;
  }

  bool get busy => _busy;
  bool get watching => _fence != null;
  bool get armed => vehicle != null && vehicle!.status != VehicleStatus.ok;
  bool get stolen => vehicle?.status == VehicleStatus.stolen;

  /// The backend says guarded, but this phone is not watching (the app was
  /// closed, or it was armed on another phone).
  bool get armedElsewhere => armed && !watching;
  bool get hasCircles => _vehicles.circleIds.isNotEmpty;
  Boundary? get boundary => _fence?.boundary ?? vehicle?.boundary;
  GeoPoint? get lastPosition => _last;
  double? get distanceM => _last == null ? null : _fence?.distanceFrom(_last!);

  void setRadius(double r) {
    radiusM = r.clamp(minRadiusM, maxRadiusM).roundToDouble();
    notifyListeners();
  }

  void setMotion({bool? on, NudgeSensitivity? level}) {
    motionOn = on ?? motionOn;
    sensitivity = level ?? sensitivity;
    _listenMotion();
    notifyListeners();
  }

  /// Null when armed, else a message to show.
  Future<String?> arm() async {
    final v = _vehicles.active;
    if (v == null) return 'Add a vehicle first.';
    _busy = true;
    notifyListeners();
    try {
      final source = _record.source;
      if (await source.ensureAccess() != LocationAccess.granted) {
        return 'Guard mode needs location access to know if the vehicle moves.';
      }
      final here = await source.currentPosition();
      if (here == null) return "Couldn't find your location. Try again outdoors.";
      final b = Boundary(lat: here.lat, lng: here.lng, radiusM: radiusM);
      await _vehicles.save(
        v.copyWith(status: VehicleStatus.guarding, boundary: b, armedAt: clock.now()),
      );
      _start(v.id, b);
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Watches a vehicle that stayed armed after the app was closed.
  void resume() {
    final v = vehicle;
    final b = v?.boundary;
    if (v == null || b == null || watching) return;
    _start(v.id, b);
    notifyListeners();
  }

  Future<void> disarm() async {
    final v = vehicle;
    _stop();
    if (v != null) await _vehicles.save(v.copyWith(status: VehicleStatus.ok, disarm: true));
    await _report.setRing(alert: false);
    notifyListeners();
  }

  /// Closes this vehicle's open theft alerts, then disarms.
  Future<void> markRecovered() async {
    final v = vehicle;
    final uid = _vehicles.user?.uid;
    if (v != null && uid != null) {
      for (final a in _alerts.openFor(uid, v.id)) {
        await _alerts.recover(a);
      }
    }
    await disarm();
  }

  /// Demo only: carries the parked vehicle out of its boundary.
  void testAlarm() {
    final b = _fence?.boundary;
    if (b == null) return;
    for (final d in [b.radiusM + 25, b.radiusM + 45]) {
      final p = offsetM(b.center, northM: d);
      _onFix(Fix(p.lat, p.lng, clock.now(), accuracyM: 5, speedMps: 4));
    }
  }

  void _start(String vehicleId, Boundary b) {
    _stop();
    _watchingId = vehicleId;
    _fence = GeofenceWatch(b);
    _battery = BatteryWatch();
    _followGate.reset();
    _fixSub = _record.source.guardFixes().listen(_onFix, onError: (Object _) {});
    _beat = Timer.periodic(const Duration(seconds: 60), (_) => _heartbeat());
    _listenMotion();
    _heartbeat();
  }

  void _stop() {
    _fixSub?.cancel();
    _fixSub = null;
    _nudges.stop();
    _beat?.cancel();
    _beat = null;
    _fence = null;
    _watchingId = null;
    _openAlertId = null;
    _last = null;
  }

  void _listenMotion() {
    if (!motionOn || _fence == null) return _nudges.stop();
    _nudges.start(sensitivity, () {
      final v = vehicle;
      if (v != null) _raise(AlertType.motion, '${_report.whose} ${v.name} was moved');
    });
  }

  void _onFix(Fix f) {
    final fence = _fence;
    final v = vehicle;
    if (fence == null || v == null) return;
    final p = GeoPoint(f.lat, f.lng);
    _last = p;
    final event = fence.addFix(p, f.accuracyM);
    final open = _openAlertId;
    if (event == GeofenceEvent.exit) {
      _raise(AlertType.geofence, '${_report.whose} ${v.name} is on the move');
    } else if (fence.tripped && open != null && _followGate.shouldPublish(p, clock.now())) {
      // The alert follows the vehicle, so "Navigate" leads to where it is now.
      _alerts.follow(open, p, fence.distanceFrom(p));
    }
    notifyListeners();
  }

  Future<void> _heartbeat() async {
    final level = await readBattery?.call();
    if (_fence == null) return;
    await _report.heartbeat(level);
    if (level != null && _battery.addLevel(level)) {
      await _raise(AlertType.lowbattery, '${_report.whose} phone battery is at $level%');
    }
  }

  Future<void> _raise(AlertType type, String message) async {
    final v = vehicle;
    final fence = _fence;
    if (v == null || fence == null) return;
    final alert = await _report.raise(
      type: type,
      vehicle: v,
      boundary: fence.boundary,
      at: _last ?? fence.boundary.center,
      message: message,
    );
    if (type == AlertType.geofence) _openAlertId = alert?.id;
  }

  void _onVehicles() {
    final id = _watchingId;
    if (id != null) {
      final v = _vehicles.vehicles.where((v) => v.id == id).firstOrNull;
      final gone = _vehicles.user == null || (_vehicles.loaded && v == null);
      // Disarmed elsewhere (another phone, or deleted): stop watching here.
      if (gone || v?.status == VehicleStatus.ok) _stop();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _stop();
    _vehicles.removeListener(_onVehicles);
    super.dispose();
  }
}
