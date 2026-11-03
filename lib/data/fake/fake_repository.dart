import 'dart:async';

import '../../core/activity_type.dart';
import '../../core/units.dart';
import '../models/activity.dart';
import '../models/circle.dart';
import '../models/circle_alert.dart';
import '../models/user.dart';
import '../repository.dart';
import 'demo_seed.dart';
import 'fake_auth.dart';
import 'demo_simulator.dart';
import 'fake_store.dart';

/// In-memory demo backend that mirrors the Firestore layout. Nothing is
/// persisted or logged; everything resets when the app reloads.
class FakeRepository extends AppRepository implements DemoMailbox {
  FakeRepository({
    this.simulate = true,
    this.latency = const Duration(milliseconds: 350),
    DateTime? now,
    FakeAuth? auth,
  }) : seed = DemoSeed.build(now ?? DateTime.now()),
       accounts = auth ?? FakeAuth() {
    _store.profiles[seed.you.uid] = seed.you;
    _store.vehiclesOf(seed.you.uid).value = seed.vehicles;
    _store.activitiesOf(seed.you.uid).value = seed.activities;
    _store.circles.value = [seed.circle];
    _store.membersOf(seed.circle.id).value = seed.members;
    _store.alertsOf(seed.circle.id).value = seed.alerts;
    simulator = DemoSimulator(
      CircleWorld(_store, seed.circle.id),
      loop: seed.jeroLoop,
      boundary: seed.jeroBoundary,
    );
  }

  /// Animate demo members while the demo account is signed in.
  final bool simulate;

  /// Fake network delay for auth calls, so loading states are visible.
  final Duration latency;
  final DemoSeed seed;
  late final DemoSimulator simulator;

  /// Accounts, lockout and the demo outbox (the "auth server").
  final FakeAuth accounts;
  final _store = FakeStore();
  int _nextUid = 1;

  Future<void> _wait() => latency == Duration.zero ? Future.value() : Future.delayed(latency);

  // Auth ---------------------------------------------------------------------

  @override
  bool get isDemo => true;

  @override
  AppUser? get currentUser => _store.auth.value;

  @override
  Stream<AppUser?> authStateChanges() => _store.auth.stream;

  @override
  Future<void> signInDemo() async {
    await _wait();
    _store.auth.value = _store.profiles[DemoIds.you];
    if (simulate) simulator.start();
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _wait();
    final account = accounts.checkPassword(email, password);
    _store.auth.value = _store.profiles[account.uid]?.copyWith(emailVerified: account.verified);
  }

  @override
  Future<void> createAccount({
    required String displayName,
    required String email,
    required String password,
  }) async {
    await _wait();
    final uid = 'user-${_nextUid++}';
    final account = accounts.create(uid, email, password);
    final user = AppUser(
      uid: uid,
      displayName: displayName.trim(),
      email: account.email,
      createdAt: DateTime.now(),
      emailVerified: false,
    );
    _store.profiles[uid] = user;
    // Signed in, but held at the verification screen until verified.
    _store.auth.value = user;
    accounts.sendVerification(account);
  }

  @override
  Future<void> signOut() async {
    simulator.stop();
    _store.auth.value = null;
  }

  @override
  Future<void> sendEmailVerification() async {
    await _wait();
    final account = _currentAccount();
    if (account == null || account.verified) return;
    accounts.sendVerification(account);
  }

  @override
  Future<void> reloadUser() async {
    await _wait();
    final user = _store.auth.value;
    if (user == null) return;
    final account = accounts.byUid(user.uid);
    _store.auth.value = _store.profiles[user.uid]?.copyWith(
      emailVerified: account?.verified ?? true,
    );
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await _wait();
    accounts.sendReset(email);
  }

  FakeAccount? _currentAccount() {
    final user = _store.auth.value;
    return user == null ? null : accounts.byUid(user.uid);
  }

  // Demo mailbox --------------------------------------------------------------

  @override
  List<DemoEmail> inbox(String email) => accounts.inbox(email);

  @override
  Future<void> openVerifyLink(DemoEmail email) async {
    final account = accounts.verify(email);
    final profile = _store.profiles[account.uid];
    if (profile != null) _store.profiles[account.uid] = profile.copyWith(emailVerified: true);
    if (_store.auth.value?.uid == account.uid) _store.auth.value = _store.profiles[account.uid];
  }

  @override
  Future<void> resetPassword(DemoEmail email, String newPassword) async =>
      accounts.reset(email, newPassword);

  // Profile -------------------------------------------------------------------

  @override
  Future<void> updateProfile(
    String uid, {
    String? displayName,
    Units? units,
    ActivityType? defaultActivity,
    String? bio,
    String? hometown,
    String? photoUrl,
    String? coverUrl,
  }) async {
    final current = _store.profiles[uid];
    if (current == null) return;
    final next = current.copyWith(
      displayName: displayName,
      units: units,
      defaultActivity: defaultActivity,
      bio: bio,
      hometown: hometown,
      photoUrl: photoUrl,
      coverUrl: coverUrl,
    );
    _store.profiles[uid] = next;
    if (_store.auth.value?.uid == uid) _store.auth.value = next;
  }

  @override
  Stream<List<Vehicle>> watchVehicles(String uid) => _store.vehiclesOf(uid).stream;

  // Activities ----------------------------------------------------------------

  @override
  Stream<List<Activity>> watchActivities(String uid) => _store.activitiesOf(uid).stream;

  @override
  Future<void> saveActivity(String uid, Activity activity) async {
    final store = _store.activitiesOf(uid);
    store.value = [activity, ...store.value.where((a) => a.id != activity.id)]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  @override
  Future<void> deleteActivity(String uid, String activityId) async {
    final store = _store.activitiesOf(uid);
    store.value = store.value.where((a) => a.id != activityId).toList();
  }

  // Circles -------------------------------------------------------------------

  @override
  Stream<List<Circle>> watchCircles(String uid) =>
      _store.circles.stream.map((all) => all.where((c) => c.memberUids.contains(uid)).toList());

  @override
  Stream<List<Member>> watchMembers(String circleId) => _store.membersOf(circleId).stream;

  @override
  Stream<List<CircleAlert>> watchAlerts(String circleId) => _store.alertsOf(circleId).stream;

  @override
  void dispose() {
    simulator.stop();
    _store.close();
  }
}
