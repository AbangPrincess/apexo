import 'package:flutter_test/flutter_test.dart';
import 'package:apexo/core/activity_type.dart';
import 'package:apexo/core/geo.dart';
import 'package:apexo/core/units.dart';
import 'package:apexo/data/fake/demo_seed.dart';
import 'package:apexo/data/fake/fake_repository.dart';
import 'package:apexo/data/models/circle.dart';
import 'package:apexo/data/models/circle_alert.dart';
import 'package:apexo/data/models/user.dart';
import 'package:apexo/data/repository.dart';

void main() {
  late FakeRepository repo;

  setUp(() => repo = FakeRepository(simulate: false, latency: Duration.zero));
  tearDown(() => repo.dispose());

  test('demo account sees seeded data', () async {
    await repo.signInDemo();
    final user = repo.currentUser!;
    expect(user.displayName, 'You');

    final activities = await repo.watchActivities(user.uid).first;
    expect(activities, hasLength(6));
    expect(activities.map((a) => a.type).toSet(), ActivityType.values.toSet());

    final circles = await repo.watchCircles(user.uid).first;
    expect(circles.single.name, 'Trail Buddies');
    expect(circles.single.inviteCode, 'TRAIL7');

    final members = await repo.watchMembers(circles.single.id).first;
    expect(members.map((m) => m.displayName), ['You', 'Jero', 'Shane']);
  });

  test('seeded paths are encoded with points >= 10 m apart', () async {
    for (final a in repo.seed.activities) {
      final pts = a.points;
      expect(pts.length, greaterThan(10));
      for (var i = 1; i < pts.length - 1; i++) {
        expect(distanceM(pts[i - 1], pts[i]), greaterThanOrEqualTo(9.9));
      }
      expect(a.distanceM, greaterThan(1000));
    }
  });

  test('Jero leaves his 50 m boundary after about 20 s and one alert fires', () async {
    await repo.signInDemo();
    var steps = 0;
    while (!repo.simulator.alerted && steps < 60) {
      repo.simulator.step();
      steps++;
    }
    expect(steps, inInclusiveRange(15, 25));

    final alerts = await repo.watchAlerts(DemoIds.circle).first;
    final geofence = alerts.where((a) => a.type == AlertType.geofence).toList();
    expect(geofence, hasLength(1));
    expect(geofence.single.distanceM, greaterThan(50));
    expect(geofence.single.message, contains('Jero'));

    for (var i = 0; i < 30; i++) {
      repo.simulator.step();
    }
    final after = await repo.watchAlerts(DemoIds.circle).first;
    expect(after.where((a) => a.type == AlertType.geofence), hasLength(1));

    final jero = (await repo.watchMembers(DemoIds.circle).first).firstWhere(
      (m) => m.uid == DemoIds.jero,
    );
    expect(jero.status, MemberStatus.alert);
    expect(jero.vehicle!.status, VehicleStatus.stolen);
    expect(jero.speedKmh, greaterThan(10));
  });

  test('email accounts: create, sign out, sign in', () async {
    await repo.createAccount(
      displayName: ' Ana ',
      email: 'Ana@Example.com',
      password: 'secret-123',
    );
    expect(repo.currentUser!.displayName, 'Ana');
    expect(await repo.watchCircles(repo.currentUser!.uid).first, isEmpty);
    await repo.signOut();
    expect(repo.currentUser, isNull);

    await expectLater(
      repo.signIn(email: 'ana@example.com', password: 'wrong-pass'),
      throwsA(isA<AuthException>()),
    );
    await expectLater(
      repo.signIn(email: 'nobody@example.com', password: 'secret-123'),
      throwsA(isA<AuthException>()),
    );
    await repo.signIn(email: ' ana@example.com', password: 'secret-123');
    expect(repo.currentUser!.email, 'Ana@Example.com');

    await expectLater(
      repo.createAccount(displayName: 'X', email: 'ana@example.com', password: 'whatever1'),
      throwsA(isA<AuthException>()),
    );
  });

  test('profile settings update the signed-in user', () async {
    await repo.signInDemo();
    await repo.updateProfile(DemoIds.you, units: Units.mi, defaultActivity: ActivityType.driving);
    expect(repo.currentUser!.units, Units.mi);
    expect(repo.currentUser!.defaultActivity, ActivityType.driving);
  });
}
