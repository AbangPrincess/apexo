import '../models/circle_alert.dart';
import '../repository.dart';
import 'fake_store.dart';

/// Alert writes of the demo backend: anyone in the circle may add one, the
/// owner may update theirs, and each member may add only their own ack.
mixin FakeAlerts on AppRepository {
  FakeStore get store;

  @override
  Stream<List<CircleAlert>> watchAlerts(String circleId) => store.alertsOf(circleId).stream;

  @override
  Future<void> addAlert(String circleId, CircleAlert alert) async {
    final alerts = store.alertsOf(circleId);
    alerts.value = [alert, ...alerts.value.where((a) => a.id != alert.id)];
  }

  @override
  Future<void> updateAlert(String circleId, CircleAlert alert) async {
    final alerts = store.alertsOf(circleId);
    alerts.value = [for (final a in alerts.value) a.id == alert.id ? alert : a];
  }

  @override
  Future<void> ackAlert(String circleId, String alertId, String uid) async {
    final alerts = store.alertsOf(circleId);
    alerts.value = [
      for (final a in alerts.value)
        a.id == alertId && !a.ackBy.contains(uid) ? a.copyWith(ackBy: [...a.ackBy, uid]) : a,
    ];
  }
}
