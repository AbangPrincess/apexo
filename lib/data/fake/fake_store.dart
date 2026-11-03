import '../models/activity.dart';
import '../models/circle.dart';
import '../models/circle_alert.dart';
import '../models/user.dart';
import 'demo_simulator.dart';
import 'live_value.dart';

/// The demo backend's "database": one live value per Firestore collection.
class FakeStore {
  final auth = LiveValue<AppUser?>(null);
  final profiles = <String, AppUser>{};
  final circles = LiveValue<List<Circle>>(const []);
  final _vehicles = <String, LiveValue<List<Vehicle>>>{};
  final _activities = <String, LiveValue<List<Activity>>>{};
  final _members = <String, LiveValue<List<Member>>>{};
  final _alerts = <String, LiveValue<List<CircleAlert>>>{};

  LiveValue<List<Vehicle>> vehiclesOf(String uid) =>
      _vehicles.putIfAbsent(uid, () => LiveValue(const []));
  LiveValue<List<Activity>> activitiesOf(String uid) =>
      _activities.putIfAbsent(uid, () => LiveValue(const []));
  LiveValue<List<Member>> membersOf(String cid) =>
      _members.putIfAbsent(cid, () => LiveValue(const []));
  LiveValue<List<CircleAlert>> alertsOf(String cid) =>
      _alerts.putIfAbsent(cid, () => LiveValue(const []));

  void close() {
    auth.close();
    circles.close();
    for (final v in [..._vehicles.values, ..._activities.values]) {
      v.close();
    }
    for (final v in [..._members.values, ..._alerts.values]) {
      v.close();
    }
  }
}

/// Lets the simulator edit one circle's members and alerts.
class CircleWorld implements DemoWorld {
  CircleWorld(this.store, this.circleId);

  final FakeStore store;
  final String circleId;

  @override
  Member? member(String uid) {
    for (final m in store.membersOf(circleId).value) {
      if (m.uid == uid) return m;
    }
    return null;
  }

  @override
  void putMember(Member member) {
    final members = store.membersOf(circleId);
    members.value = [for (final m in members.value) m.uid == member.uid ? member : m];
  }

  @override
  void addAlert(CircleAlert alert) {
    final alerts = store.alertsOf(circleId);
    alerts.value = [alert, ...alerts.value];
  }
}
