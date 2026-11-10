import 'package:apexo/core/activity_type.dart';
import 'package:apexo/core/geo.dart';
import 'package:apexo/core/invite_code.dart';
import 'package:apexo/data/fake/demo_seed.dart';
import 'package:apexo/data/fake/fake_repository.dart';
import 'package:apexo/data/models/activity.dart';
import 'package:apexo/data/models/circle.dart';
import 'package:apexo/data/models/user.dart';
import 'package:apexo/data/repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeRepository repo;

  setUp(() => repo = FakeRepository(simulate: false, latency: Duration.zero));
  tearDown(() => repo.dispose());

  Future<AppUser> demo() async {
    await repo.signInDemo();
    return repo.currentUser!;
  }

  AppUser stranger(String uid, String name) =>
      AppUser(uid: uid, displayName: name, email: '$uid@example.com', createdAt: DateTime(2026));

  Circle circle(String id) => repo.store.circles.value.firstWhere((c) => c.id == id);
  List<Member> members(String id) => repo.store.membersOf(id).value;

  test('create: code without look-alikes, owner is the only member', () async {
    final me = await demo();
    final c = await repo.createCircle(me, '  Night Riders ', sharing: false);
    expect(c.name, 'Night Riders');
    expect(isInviteCodeShape(c.inviteCode), isTrue);
    expect(c.inviteCode, isNot(matches(RegExp('[01OIL]'))));
    expect(c.ownerUid, me.uid);
    expect(members(c.id).single.status, MemberStatus.paused);
    expect(members(c.id).single.onMap, isFalse);
    final mine = await repo.watchCircles(me.uid).first;
    expect(mine.map((c) => c.name), ['Trail Buddies', 'Night Riders']);
    // My "Circles" activities are shared with the new circle too.
    expect(repo.store.feedOf(c.id).value, hasLength(3));
  });

  test('find by code previews the circle, case and spaces ignored', () async {
    await demo();
    final p = await repo.findCircle(' trail 7');
    expect(p!.name, 'Trail Buddies');
    expect(p.memberCount, 3);
    expect(p.ownerName, 'You');
    expect(await repo.findCircle('ZZZ999'), isNull);
  });

  test('join adds only my uid and member doc; joining twice fails', () async {
    final ana = stranger('ana', 'Ana');
    await repo.joinCircle(DemoIds.circle, ana, sharing: true);
    expect(circle(DemoIds.circle).memberUids.last, 'ana');
    final doc = members(DemoIds.circle).last;
    expect(doc.displayName, 'Ana');
    expect(doc.sharing, isTrue);
    expect(doc.onMap, isFalse, reason: 'no position before the first fix');
    expect(
      () => repo.joinCircle(DemoIds.circle, ana, sharing: false),
      throwsA(isA<CircleException>()),
    );
  });

  test('at most 3 circles per user', () async {
    final me = await demo();
    await repo.createCircle(me, 'Two', sharing: false);
    await repo.createCircle(me, 'Three', sharing: false);
    expect(() => repo.createCircle(me, 'Four', sharing: false), throwsA(isA<CircleException>()));
  });

  test('owner leaving passes ownership; the last one out deletes it', () async {
    final me = await demo();
    await repo.leaveCircle(DemoIds.circle, me.uid);
    expect(circle(DemoIds.circle).ownerUid, DemoIds.john);
    expect(members(DemoIds.circle).map((m) => m.uid), isNot(contains(me.uid)));
    expect(repo.store.feedOf(DemoIds.circle).value.where((s) => s.ownerUid == me.uid), isEmpty);

    final solo = await repo.createCircle(me, 'Solo', sharing: false);
    await repo.leaveCircle(solo.id, me.uid);
    expect(repo.store.circles.value.where((c) => c.id == solo.id), isEmpty);
  });

  test('only the owner removes members, and not themselves', () async {
    final me = await demo();
    expect(
      () => repo.removeMember(DemoIds.circle, DemoIds.john, DemoIds.sarah),
      throwsA(isA<CircleException>()),
    );
    expect(
      () => repo.removeMember(DemoIds.circle, me.uid, me.uid),
      throwsA(isA<CircleException>()),
    );
    await repo.removeMember(DemoIds.circle, me.uid, DemoIds.sarah);
    expect(circle(DemoIds.circle).memberUids, isNot(contains(DemoIds.sarah)));
    expect(members(DemoIds.circle).map((m) => m.uid), isNot(contains(DemoIds.sarah)));
    // A late write from the removed member does not bring them back.
    await repo.updateMember(DemoIds.circle, repo.seed.members.last);
    expect(members(DemoIds.circle).map((m) => m.uid), isNot(contains(DemoIds.sarah)));
  });

  test('"Circles" activities reach the circle feed; private or deleted ones leave it', () async {
    final me = await demo();
    final feed = repo.store.feedOf(DemoIds.circle);
    final base = repo.seed.activities.first;
    final ride = Activity(
      id: 'new-ride',
      type: ActivityType.cycling,
      title: 'Dawn Patrol',
      startedAt: DateTime.now(),
      endedAt: DateTime.now(),
      distanceM: base.distanceM,
      movingSec: base.movingSec,
      avgKmh: base.avgKmh,
      maxKmh: base.maxKmh,
      path: base.path,
      visibility: ActivityVisibility.circles,
      vehicleId: 'v-bike',
    );
    await repo.saveActivity(me.uid, ride);
    final shared = feed.value.first;
    expect(shared.activity.title, 'Dawn Patrol');
    expect(shared.ownerName, 'You');
    expect(shared.activity.vehicleId, isNull, reason: 'vehicle stays private');
    // The shared path is thinned to points at least 25 m apart.
    final pts = shared.activity.points;
    for (var i = 1; i < pts.length - 1; i++) {
      expect(distanceM(pts[i - 1], pts[i]), greaterThanOrEqualTo(24.9));
    }

    await repo.saveActivity(me.uid, ride.copyWith(visibility: ActivityVisibility.private));
    expect(feed.value.where((s) => s.id == 'new-ride'), isEmpty);
    await repo.saveActivity(me.uid, ride);
    await repo.deleteActivity(me.uid, ride.id);
    expect(feed.value.where((s) => s.id == 'new-ride'), isEmpty);
  });
}
