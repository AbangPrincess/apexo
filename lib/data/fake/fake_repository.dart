import 'dart:async';

import '../../core/activity_type.dart';
import '../../core/units.dart';
import '../models/activity.dart';
import '../models/circle.dart';
import '../models/circle_alert.dart';
import '../models/user.dart';
import '../repository.dart';
import 'demo_seed.dart';
import 'demo_simulator.dart';
import 'live_value.dart';

/// In-memory demo backend that mirrors the Firestore layout. Nothing is
/// persisted or logged; everything resets when the app reloads.
class FakeRepository extends AppRepository {
  FakeRepository({
    this.simulate = true,
    this.latency = const Duration(milliseconds: 350),
    DateTime? now,
  }) : seed = DemoSeed.build(now ?? DateTime.now()) {
    _profiles[seed.you.uid] = seed.you;
    _vehiclesOf(seed.you.uid).value = seed.vehicles;
    _activitiesOf(seed.you.uid).value = seed.activities;
    _circles.value = [seed.circle];
    _membersOf(seed.circle.id).value = seed.members;
    _alertsOf(seed.circle.id).value = seed.alerts;
    simulator = DemoSimulator(_World(this),
        loop: seed.jeroLoop, boundary: seed.jeroBoundary);
  }

  /// Animate demo members while the demo account is signed in.
  final bool simulate;

  /// Fake network delay for auth calls, so loading states are visible.
  final Duration latency;
  final DemoSeed seed;
  late final DemoSimulator simulator;

  final _auth = LiveValue<AppUser?>(null);
  final _accounts = <String, _Account>{};
  final _profiles = <String, AppUser>{};
  final _vehicles = <String, LiveValue<List<Vehicle>>>{};
  final _activities = <String, LiveValue<List<Activity>>>{};
  final _circles = LiveValue<List<Circle>>(const []);
  final _members = <String, LiveValue<List<Member>>>{};
  final _alerts = <String, LiveValue<List<CircleAlert>>>{};
  int _nextUid = 1;

  LiveValue<List<Vehicle>> _vehiclesOf(String uid) =>
      _vehicles.putIfAbsent(uid, () => LiveValue(const []));
  LiveValue<List<Activity>> _activitiesOf(String uid) =>
      _activities.putIfAbsent(uid, () => LiveValue(const []));
  LiveValue<List<Member>> _membersOf(String cid) =>
      _members.putIfAbsent(cid, () => LiveValue(const []));
  LiveValue<List<CircleAlert>> _alertsOf(String cid) =>
      _alerts.putIfAbsent(cid, () => LiveValue(const []));

  Future<void> _wait() =>
      latency == Duration.zero ? Future.value() : Future.delayed(latency);

  // Auth ---------------------------------------------------------------------

  @override
  bool get isDemo => true;

  @override
  AppUser? get currentUser => _auth.value;

  @override
  Stream<AppUser?> authStateChanges() => _auth.stream;

  @override
  Future<void> signInDemo() async {
    await _wait();
    _auth.value = _profiles[DemoIds.you];
    if (simulate) simulator.start();
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _wait();
    final account = _accounts[email.trim().toLowerCase()];
    // One message for both cases, so the form never reveals which emails exist.
    if (account == null || !account.matches(password)) {
      throw const AuthException('Email or password is incorrect.');
    }
    _auth.value = _profiles[account.uid];
  }

  @override
  Future<void> createAccount({
    required String displayName,
    required String email,
    required String password,
  }) async {
    await _wait();
    final key = email.trim().toLowerCase();
    if (_accounts.containsKey(key)) {
      throw const AuthException('That email already has an account. Sign in instead.');
    }
    final uid = 'user-${_nextUid++}';
    final user = AppUser(
      uid: uid,
      displayName: displayName.trim(),
      email: email.trim(),
      createdAt: DateTime.now(),
    );
    _accounts[key] = _Account(uid, password);
    _profiles[uid] = user;
    _auth.value = user;
  }

  @override
  Future<void> signOut() async {
    simulator.stop();
    _auth.value = null;
  }

  // Profile -------------------------------------------------------------------

  @override
  Future<void> updateProfile(String uid,
      {String? displayName, Units? units, ActivityType? defaultActivity}) async {
    final current = _profiles[uid];
    if (current == null) return;
    final next = current.copyWith(
        displayName: displayName, units: units, defaultActivity: defaultActivity);
    _profiles[uid] = next;
    if (_auth.value?.uid == uid) _auth.value = next;
  }

  @override
  Stream<List<Vehicle>> watchVehicles(String uid) => _vehiclesOf(uid).stream;

  // Activities ----------------------------------------------------------------

  @override
  Stream<List<Activity>> watchActivities(String uid) => _activitiesOf(uid).stream;

  @override
  Future<void> saveActivity(String uid, Activity activity) async {
    final store = _activitiesOf(uid);
    store.value = [activity, ...store.value.where((a) => a.id != activity.id)]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  @override
  Future<void> deleteActivity(String uid, String activityId) async {
    final store = _activitiesOf(uid);
    store.value = store.value.where((a) => a.id != activityId).toList();
  }

  // Circles -------------------------------------------------------------------

  @override
  Stream<List<Circle>> watchCircles(String uid) => _circles.stream
      .map((all) => all.where((c) => c.memberUids.contains(uid)).toList());

  @override
  Stream<List<Member>> watchMembers(String circleId) => _membersOf(circleId).stream;

  @override
  Stream<List<CircleAlert>> watchAlerts(String circleId) => _alertsOf(circleId).stream;

  @override
  void dispose() {
    simulator.stop();
    _auth.close();
    _circles.close();
    for (final v in [..._vehicles.values, ..._activities.values]) {
      v.close();
    }
    for (final v in [..._members.values, ..._alerts.values]) {
      v.close();
    }
  }
}

class _Account {
  _Account(this.uid, this._password);
  final String uid;
  final String _password;
  bool matches(String password) => password == _password;
}

/// Lets the simulator edit the seeded circle without exposing the stores.
class _World implements DemoWorld {
  _World(this.repo);
  final FakeRepository repo;

  LiveValue<List<Member>> get _members => repo._membersOf(DemoIds.circle);

  @override
  Member? member(String uid) {
    for (final m in _members.value) {
      if (m.uid == uid) return m;
    }
    return null;
  }

  @override
  void putMember(Member member) => _members.value = [
        for (final m in _members.value) m.uid == member.uid ? member : m,
      ];

  @override
  void addAlert(CircleAlert alert) {
    final store = repo._alertsOf(DemoIds.circle);
    store.value = [alert, ...store.value];
  }
}
