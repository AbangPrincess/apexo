import 'dart:math';

import '../../core/invite_code.dart';
import '../models/activity.dart';
import '../models/circle.dart';
import '../models/circle_alert.dart';
import '../models/shared_activity.dart';
import '../models/user.dart';
import '../repository.dart';
import 'fake_store.dart';

/// Circle operations of the demo backend, done the way the Firestore client
/// will do them in P6: users write only their own uid and member doc, and
/// the owner may also remove others.
mixin FakeCircles on AppRepository {
  FakeStore get store;
  Duration get latency;

  final _random = Random.secure();
  int _nextCircle = 1;

  Future<void> _delay() => latency == Duration.zero ? Future.value() : Future.delayed(latency);

  List<Circle> circlesOf(String uid) => [
    for (final c in store.circles.value)
      if (c.memberUids.contains(uid)) c,
  ];

  @override
  Stream<List<Circle>> watchCircles(String uid) => store.circles.stream.map(
    (all) => [
      for (final c in all)
        if (c.memberUids.contains(uid)) c,
    ],
  );

  @override
  Stream<List<Member>> watchMembers(String circleId) => store.membersOf(circleId).stream;

  @override
  Stream<List<CircleAlert>> watchAlerts(String circleId) => store.alertsOf(circleId).stream;

  @override
  Stream<List<SharedActivity>> watchCircleFeed(String circleId) => store.feedOf(circleId).stream;

  @override
  Future<Circle> createCircle(AppUser owner, String name, {required bool sharing}) async {
    await _delay();
    final clean = name.trim();
    if (clean.isEmpty) throw const CircleException('Give your circle a name.');
    _checkLimit(owner.uid);
    final taken = {for (final c in store.circles.value) c.inviteCode};
    var code = generateInviteCode(_random);
    while (taken.contains(code)) {
      code = generateInviteCode(_random);
    }
    final circle = Circle(
      id: 'circle-${_nextCircle++}',
      name: clean,
      inviteCode: code,
      ownerUid: owner.uid,
      memberUids: [owner.uid],
      createdAt: DateTime.now(),
    );
    store.membersOf(circle.id).value = [_newMember(owner, sharing)];
    _backfill(circle.id, owner);
    store.circles.value = [...store.circles.value, circle];
    return circle;
  }

  @override
  Future<CirclePreview?> findCircle(String inviteCode) async {
    await _delay();
    final code = normalizeInviteCode(inviteCode);
    for (final c in store.circles.value) {
      if (c.inviteCode != code) continue;
      final owner = store.membersOf(c.id).value.where((m) => m.uid == c.ownerUid).firstOrNull;
      return CirclePreview(
        id: c.id,
        name: c.name,
        memberCount: c.memberUids.length,
        ownerName: owner?.displayName ?? 'the owner',
      );
    }
    return null;
  }

  @override
  Future<void> joinCircle(String circleId, AppUser user, {required bool sharing}) async {
    await _delay();
    final c = _circle(circleId);
    if (c.memberUids.contains(user.uid)) throw CircleException("You're already in ${c.name}.");
    _checkLimit(user.uid);
    final members = store.membersOf(circleId);
    members.value = [...members.value, _newMember(user, sharing)];
    _backfill(circleId, user);
    _putCircle(_withMembers(c, [...c.memberUids, user.uid]));
  }

  @override
  Future<void> leaveCircle(String circleId, String uid) async {
    await _delay();
    final c = _circle(circleId);
    final rest = [
      for (final u in c.memberUids)
        if (u != uid) u,
    ];
    if (rest.isEmpty) {
      store.circles.value = [
        for (final x in store.circles.value)
          if (x.id != circleId) x,
      ];
      store.membersOf(circleId).value = const [];
      store.alertsOf(circleId).value = const [];
      store.feedOf(circleId).value = const [];
      return;
    }
    _putCircle(_withMembers(c, rest, owner: c.ownerUid == uid ? rest.first : null));
    _drop(circleId, uid);
  }

  @override
  Future<void> removeMember(String circleId, String ownerUid, String memberUid) async {
    await _delay();
    final c = _circle(circleId);
    if (c.ownerUid != ownerUid) {
      throw const CircleException('Only the circle owner can remove members.');
    }
    if (memberUid == ownerUid) throw const CircleException('Use Leave circle to leave.');
    _putCircle(
      _withMembers(c, [
        for (final u in c.memberUids)
          if (u != memberUid) u,
      ]),
    );
    _drop(circleId, memberUid);
  }

  @override
  Future<void> updateMember(String circleId, Member member) async {
    final members = store.membersOf(circleId);
    // Removed meanwhile: a late write must not re-add them.
    if (!members.value.any((m) => m.uid == member.uid)) return;
    members.value = [for (final m in members.value) m.uid == member.uid ? member : m];
  }

  /// Mirrors a saved (or deleted, when [activity] is null) activity into the
  /// owner's circle feeds, like the client-side batch write in P6.
  void syncFeeds(String uid, String activityId, Activity? activity) {
    final owner = store.profiles[uid];
    final shared =
        activity != null && activity.visibility == ActivityVisibility.circles && owner != null
        ? SharedActivity.of(owner, activity, DateTime.now())
        : null;
    for (final c in circlesOf(uid)) {
      final feed = store.feedOf(c.id);
      final rest = [
        for (final s in feed.value)
          if (s.ownerUid != uid || s.id != activityId) s,
      ];
      feed.value = shared == null ? rest : _sorted([shared, ...rest]);
    }
  }

  /// A new member's recent "Circles" activities appear in the circle too.
  void _backfill(String circleId, AppUser user) {
    final mine = store
        .activitiesOf(user.uid)
        .value
        .where((a) => a.visibility == ActivityVisibility.circles)
        .take(20);
    if (mine.isEmpty) return;
    final feed = store.feedOf(circleId);
    final now = DateTime.now();
    feed.value = _sorted([
      ...feed.value.where((s) => s.ownerUid != user.uid),
      for (final a in mine) SharedActivity.of(user, a, now),
    ]);
  }

  void _drop(String circleId, String uid) {
    final members = store.membersOf(circleId);
    members.value = [
      for (final m in members.value)
        if (m.uid != uid) m,
    ];
    final feed = store.feedOf(circleId);
    feed.value = [
      for (final s in feed.value)
        if (s.ownerUid != uid) s,
    ];
  }

  void _checkLimit(String uid) {
    if (circlesOf(uid).length >= maxCirclesPerUser) {
      throw const CircleException(
        'You can be in up to $maxCirclesPerUser circles. Leave one to make room.',
      );
    }
  }

  Circle _circle(String id) {
    for (final c in store.circles.value) {
      if (c.id == id) return c;
    }
    throw const CircleException('That circle no longer exists.');
  }

  void _putCircle(Circle c) =>
      store.circles.value = [for (final x in store.circles.value) x.id == c.id ? c : x];

  static Circle _withMembers(Circle c, List<String> uids, {String? owner}) => Circle(
    id: c.id,
    name: c.name,
    inviteCode: c.inviteCode,
    ownerUid: owner ?? c.ownerUid,
    memberUids: uids,
    createdAt: c.createdAt,
  );

  Member _newMember(AppUser user, bool sharing) {
    final vehicles = store.vehiclesOf(user.uid).value;
    final v = vehicles.isEmpty ? null : vehicles.first;
    // No position until the first fix; 0,0 keeps the pin off the map.
    return Member(
      uid: user.uid,
      displayName: user.displayName,
      lat: 0,
      lng: 0,
      ts: DateTime.now(),
      status: sharing ? MemberStatus.parked : MemberStatus.paused,
      sharing: sharing,
      vehicle: v == null ? null : MemberVehicle(type: v.type, name: v.name, status: v.status),
    );
  }

  static List<SharedActivity> _sorted(List<SharedActivity> list) =>
      list..sort((a, b) => b.activity.startedAt.compareTo(a.activity.startedAt));
}
