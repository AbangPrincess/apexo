import 'package:apexo/core/activity_type.dart';
import 'package:apexo/data/firebase/fb_util.dart';
import 'package:apexo/data/firebase/firebase_repository.dart';
import 'package:apexo/data/models/activity.dart';
import 'package:apexo/data/models/circle.dart';
import 'package:apexo/data/models/circle_alert.dart';
import 'package:apexo/data/models/user.dart';
import 'package:apexo/data/repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

void main() {
  late FakeFirebaseFirestore db;
  final repos = <FirebaseRepository>[];

  setUp(() => db = FakeFirebaseFirestore());
  tearDown(() {
    for (final r in repos) {
      r.dispose();
    }
    repos.clear();
  });

  Future<FirebaseRepository> signedIn(String uid, String name, {MockFirebaseAuth? auth}) async {
    final user = MockUser(uid: uid, email: '$uid@example.com', displayName: name);
    final repo = FirebaseRepository(
      auth: auth ?? MockFirebaseAuth(signedIn: true, mockUser: user),
      db: db,
    );
    repos.add(repo);
    await repo.authStateChanges().first;
    await pumpEventQueue();
    return repo;
  }

  Activity ride(String id, ActivityVisibility vis) => Activity(
    id: id,
    type: ActivityType.cycling,
    title: 'Dawn Patrol',
    startedAt: DateTime(2026, 11, 4, 6),
    endedAt: DateTime(2026, 11, 4, 7),
    distanceM: 12000,
    movingSec: 2700,
    avgKmh: 16,
    maxKmh: 31,
    path: '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
    visibility: vis,
  );

  test('first verified sign-in creates the profile from Auth', () async {
    final ana = await signedIn('ana', 'Ana');
    expect(ana.currentUser!.displayName, 'Ana');
    expect(ana.isDemo, isFalse);
    final doc = await db.collection('users').doc('ana').get();
    expect(doc.data()!['displayName'], 'Ana');
    expect(doc.data()!['units'], 'km');
  });

  test('create, find by code and join; members write only their own docs', () async {
    final ana = await signedIn('ana', 'Ana');
    final c = await ana.createCircle(ana.currentUser!, 'Night Riders', sharing: false);
    final code = await db.collection('inviteCodes').doc(c.inviteCode).get();
    expect(code.data()!['circleId'], c.id);
    expect(code.data()!['memberCount'], 1);

    final ben = await signedIn('ben', 'Ben');
    final p = await ben.findCircle(c.inviteCode.toLowerCase());
    expect(p!.name, 'Night Riders');
    expect(p.ownerName, 'Ana');
    await ben.joinCircle(c.id, ben.currentUser!, sharing: true);

    final circle = Circle.fromMap(c.id, (await db.collection('circles').doc(c.id).get()).data()!);
    expect(circle.memberUids, ['ana', 'ben']);
    expect((await db.collection('inviteCodes').doc(c.inviteCode).get()).data()!['memberCount'], 2);
    final members = await ben.watchMembers(c.id).first;
    expect(members.map((m) => m.displayName), ['Ana', 'Ben']);
    expect(members.last.sharing, isTrue);
    expect(members.last.onMap, isFalse);
    expect(await ben.findCircle('ZZZ999'), isNull);
  });

  test('"Circles" activities fan out to the feed; private ones are removed', () async {
    final ana = await signedIn('ana', 'Ana');
    final c = await ana.createCircle(ana.currentUser!, 'Night Riders', sharing: false);
    await ana.saveActivity('ana', ride('r1', ActivityVisibility.circles));
    final feed = await ana.watchCircleFeed(c.id).first;
    expect(feed.single.id, 'r1');
    expect(feed.single.ownerName, 'Ana');
    expect((await db.collection('circles/${c.id}/feed').doc('ana_r1').get()).exists, isTrue);

    await ana.saveActivity('ana', ride('r1', ActivityVisibility.private));
    expect(await ana.watchCircleFeed(c.id).first, isEmpty);
    expect(await ana.watchActivities('ana').first, hasLength(1));
  });

  test('owner leaving hands over; last one out deletes circle and code', () async {
    final ana = await signedIn('ana', 'Ana');
    final c = await ana.createCircle(ana.currentUser!, 'Night Riders', sharing: false);
    final ben = await signedIn('ben', 'Ben');
    await ben.findCircle(c.inviteCode);
    await ben.joinCircle(c.id, ben.currentUser!, sharing: false);
    await ana.watchMembers(c.id).first;

    await ana.leaveCircle(c.id, 'ana');
    final after = (await db.collection('circles').doc(c.id).get()).data()!;
    expect(after['ownerUid'], 'ben');
    expect(after['memberUids'], ['ben']);
    final code = (await db.collection('inviteCodes').doc(c.inviteCode).get()).data()!;
    expect(code['ownerName'], 'Ben');
    expect(code['memberCount'], 1);

    await ben.leaveCircle(c.id, 'ben');
    expect((await db.collection('circles').doc(c.id).get()).exists, isFalse);
    expect((await db.collection('inviteCodes').doc(c.inviteCode).get()).exists, isFalse);
  });

  test('a removed member cannot be brought back by a late write', () async {
    final ana = await signedIn('ana', 'Ana');
    final c = await ana.createCircle(ana.currentUser!, 'Night Riders', sharing: false);
    final ben = await signedIn('ben', 'Ben');
    await ben.findCircle(c.inviteCode);
    await ben.joinCircle(c.id, ben.currentUser!, sharing: true);
    final benDoc = (await ben.watchMembers(c.id).first).firstWhere((m) => m.uid == 'ben');

    await expectLater(ben.removeMember(c.id, 'ben', 'ana'), throwsA(isA<CircleException>()));
    await ana.removeMember(c.id, 'ana', 'ben');
    await ben.updateMember(c.id, benDoc.copyWith(lat: 6.5, lng: 124.85));
    expect((await db.collection('circles/${c.id}/members').doc('ben').get()).exists, isFalse);
  });

  test('alerts: acks add only my uid and survive the owner closing it', () async {
    final ana = await signedIn('ana', 'Ana');
    final c = await ana.createCircle(ana.currentUser!, 'Night Riders', sharing: false);
    final alert = CircleAlert(
      id: 'a1',
      type: AlertType.geofence,
      ownerUid: 'ana',
      vehicleName: 'Blue MTB',
      message: "Ana's Blue MTB is on the move",
      lat: 6.5,
      lng: 124.85,
      distanceM: 80,
      radiusM: 50,
      ts: DateTime(2026, 11, 4, 22),
    );
    await ana.addAlert(c.id, alert);
    await ana.ackAlert(c.id, 'a1', 'ana');
    final stored = (await ana.watchAlerts(c.id).first).single;
    await ana.updateAlert(c.id, stored.copyWith(recoveredAt: DateTime(2026, 11, 4, 23)));

    final doc = (await db.collection('circles/${c.id}/alerts').doc('a1').get()).data()!;
    expect(doc['ackBy'], ['ana']);
    expect(doc['recoveredAt'], isNotNull);
  });

  test('wrong passwords lock sign-in after five tries', () async {
    final auth = MockFirebaseAuth();
    whenCalling(
      Invocation.method(#signInWithEmailAndPassword, null),
    ).on(auth).thenThrow(FirebaseAuthException(code: 'invalid-credential'));
    final repo = FirebaseRepository(auth: auth, db: db);
    repos.add(repo);
    AuthException? last;
    for (var i = 0; i < 5; i++) {
      try {
        await repo.signIn(email: 'Ana@Example.com', password: 'nope');
      } on AuthException catch (e) {
        last = e;
      }
    }
    expect(last!.retryAfter, isNotNull);
    expect(last.message, startsWith('Too many attempts'));
  });

  test('changedFields compares Timestamps with DateTimes and nested maps', () {
    final t = DateTime(2026, 11, 4, 8);
    final before = {
      'ts': Timestamp.fromDate(t),
      'battery': 80,
      'vehicle': {'type': 'bike', 'name': 'Blue MTB'},
    };
    expect(
      changedFields(before, {
        'ts': t,
        'battery': 80.0,
        'vehicle': {'type': 'bike', 'name': 'Blue MTB'},
      }),
      isEmpty,
    );
    expect(changedFields(before, {'ts': t, 'battery': 79}), {'battery': 79});
    expect(changedFields(null, {'battery': 79}), {'battery': 79});
  });

  test('vehicles and the active one live on the profile', () async {
    final ana = await signedIn('ana', 'Ana');
    await ana.saveVehicle(
      'ana',
      const Vehicle(id: 'v-1', type: VehicleType.bike, name: 'Blue MTB'),
    );
    await ana.updateProfile('ana', activeVehicleId: 'v-1');
    expect((await ana.watchVehicles('ana').first).single.name, 'Blue MTB');
    await pumpEventQueue();
    expect(ana.currentUser!.activeVehicleId, 'v-1');
  });
}
