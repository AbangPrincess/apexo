import 'package:apexo/data/fake/demo_seed.dart';
import 'package:apexo/data/fake/fake_repository.dart';
import 'package:apexo/data/models/circle_alert.dart';
import 'package:apexo/features/alerts/alerts_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeRepository repo;
  late AlertsController alerts;

  setUp(() async {
    repo = FakeRepository(simulate: false, latency: Duration.zero);
    alerts = AlertsController(repo);
    await repo.signInDemo();
    await pumpEventQueue();
  });

  tearDown(() {
    alerts.dispose();
    repo.dispose();
  });

  CircleAlert alert(String id, String owner, AlertType type, {Duration ago = Duration.zero}) =>
      CircleAlert(
        id: id,
        type: type,
        ownerUid: owner,
        vehicleId: 'v1',
        vehicleName: 'Blue MTB',
        message: 'Blue MTB is on the move',
        lat: 6.5,
        lng: 124.85,
        distanceM: 80,
        radiusM: 50,
        ts: DateTime.now().subtract(ago),
      );

  test('history is not news; new alerts from others are, mine are not', () async {
    final heard = <String>[];
    alerts.incoming.listen((a) => heard.add(a.id));
    expect(alerts.all.single.type, AlertType.lowbattery, reason: 'the seeded alert');

    await repo.addAlert(DemoIds.circle, alert('a1', DemoIds.jero, AlertType.geofence));
    await repo.addAlert(DemoIds.circle, alert('a2', DemoIds.you, AlertType.geofence));
    await pumpEventQueue();
    expect(heard, ['a1']);
    expect(alerts.unseenCount, 1);
    alerts.markSeen();
    expect(alerts.unseenCount, 0);
  });

  test('one event in two circles shows once; acks go to both', () async {
    final me = repo.currentUser!;
    final second = await repo.createCircle(me, 'Night Riders', sharing: false);
    await pumpEventQueue();
    final a = alert('shared', DemoIds.you, AlertType.geofence);
    await repo.addAlert(DemoIds.circle, a);
    await repo.addAlert(second.id, a);
    await pumpEventQueue();
    expect(alerts.all.where((x) => x.id == 'shared'), hasLength(1));
    expect(alerts.circlesOf('shared'), unorderedEquals([DemoIds.circle, second.id]));

    await alerts.ack(alerts.byId('shared')!);
    await pumpEventQueue();
    for (final c in [DemoIds.circle, second.id]) {
      final stored = repo.store.alertsOf(c).value.firstWhere((x) => x.id == 'shared');
      expect(stored.ackBy, [DemoIds.you]);
    }

    await alerts.recover(alerts.byId('shared')!);
    await pumpEventQueue();
    expect(alerts.byId('shared')!.open, isFalse);
    expect(alerts.byId('shared')!.ackBy, [DemoIds.you], reason: 'recovering keeps acks');
  });

  test('filters: mine, circle, type and date', () async {
    final me = repo.currentUser!;
    final second = await repo.createCircle(me, 'Night Riders', sharing: false);
    await pumpEventQueue();
    await repo.addAlert(DemoIds.circle, alert('jero', DemoIds.jero, AlertType.geofence));
    await repo.addAlert(
      second.id,
      alert('old', DemoIds.you, AlertType.motion, ago: const Duration(days: 10)),
    );
    await pumpEventQueue();

    List<String> ids(List<CircleAlert> list) => [for (final a in list) a.id];
    expect(ids(alerts.filtered(scope: AlertScope.mine)), ['old']);
    expect(ids(alerts.filtered(scope: AlertScope.circle, circleId: second.id)), ['old']);
    expect(ids(alerts.filtered(type: AlertType.geofence)), ['jero']);
    expect(ids(alerts.filtered(period: AlertPeriod.week)), isNot(contains('old')));
    expect(alerts.filtered(), hasLength(3));
  });
}
