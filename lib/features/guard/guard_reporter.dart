import 'package:clock/clock.dart';

import '../../core/geo.dart';
import '../../data/models/circle.dart';
import '../../data/models/circle_alert.dart';
import '../../data/models/user.dart';
import '../../data/repository.dart';
import 'vehicles_controller.dart';

/// "John's", but "Your" for the demo account, which is called "You".
String possessive(String name) => name == 'You' ? 'Your' : "$name's";

/// What guard mode writes: alerts to every circle I am in, my ring color,
/// and the heartbeat on my member docs.
class GuardReporter {
  GuardReporter(this._repo, this._vehicles);

  final AppRepository _repo;
  final VehiclesController _vehicles;

  String get whose => possessive(_vehicles.user?.displayName ?? 'A member');

  /// Writes the alert everywhere. Only leaving the boundary marks the
  /// vehicle stolen and turns my ring red; a nudge or low battery is a
  /// warning.
  Future<CircleAlert?> raise({
    required AlertType type,
    required Vehicle vehicle,
    required Boundary boundary,
    required GeoPoint at,
    required String message,
  }) async {
    final user = _vehicles.user;
    if (user == null) return null;
    final now = clock.now();
    final alert = CircleAlert(
      id: 'alert-${user.uid}-${now.microsecondsSinceEpoch}',
      type: type,
      ownerUid: user.uid,
      ownerName: user.displayName,
      vehicleId: vehicle.id,
      vehicleName: vehicle.name,
      message: message,
      lat: at.lat,
      lng: at.lng,
      distanceM: distanceM(boundary.center, at),
      radiusM: type == AlertType.geofence ? boundary.radiusM : 0,
      ts: now,
    );
    for (final c in _vehicles.circleIds) {
      await _repo.addAlert(c, alert);
    }
    if (type == AlertType.geofence) {
      await _vehicles.save(vehicle.copyWith(status: VehicleStatus.stolen));
      await setRing(alert: true);
    }
    return alert;
  }

  /// Fresh "last update" time and battery on my member docs.
  Future<void> heartbeat(int? battery) async {
    final now = clock.now();
    for (final e in _vehicles.myDocs.entries.toList()) {
      await _repo.updateMember(e.key, e.value.copyWith(ts: now, battery: battery));
    }
  }

  Future<void> setRing({required bool alert}) async {
    for (final e in _vehicles.myDocs.entries.toList()) {
      final m = e.value;
      if (alert ? m.status == MemberStatus.alert : m.status != MemberStatus.alert) continue;
      final calm = m.sharing ? MemberStatus.parked : MemberStatus.paused;
      await _repo.updateMember(e.key, m.copyWith(status: alert ? MemberStatus.alert : calm));
    }
  }
}
