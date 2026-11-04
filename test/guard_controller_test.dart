import 'dart:async';

import 'package:apexo/core/geo.dart';
import 'package:apexo/data/fake/demo_seed.dart';
import 'package:apexo/data/fake/fake_repository.dart';
import 'package:apexo/data/models/circle.dart';
import 'package:apexo/data/models/circle_alert.dart';
import 'package:apexo/data/models/user.dart';
import 'package:apexo/features/alerts/alerts_controller.dart';
import 'package:apexo/features/guard/guard_controller.dart';
import 'package:apexo/features/guard/motion_source.dart';
import 'package:apexo/features/guard/vehicles_controller.dart';
import 'package:apexo/features/record/location_source.dart';
import 'package:apexo/features/record/record_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeMotion implements MotionSource {
  final ctrl = StreamController<MotionSample>.broadcast();

  @override
  Stream<MotionSample> samples() => ctrl.stream;
}

void main() {
  late FakeRepository repo;
  late RecordController record;
  late VehiclesController vehicles;
  late AlertsController alerts;
  late GuardController guard;
  late FakeMotion motion;
  int? battery;
  final spot = SimulatedLocationSource().start;

  setUp(() async {
    battery = 80;
    motion = FakeMotion();
    repo = FakeRepository(simulate: false, latency: Duration.zero);
    record = RecordController(
      repo,
      device: SimulatedLocationSource(),
      simulator: SimulatedLocationSource(),
    );
    vehicles = VehiclesController(repo);
    alerts = AlertsController(repo);
    guard = GuardController(
      repo,
      vehicles,
      alerts,
      record,
      readBattery: () async => battery,
      motion: motion,
    );
    await repo.signInDemo();
    await pumpEventQueue();
  });

  tearDown(() {
    guard.dispose();
    alerts.dispose();
    vehicles.dispose();
    record.dispose();
    repo.dispose();
    motion.ctrl.close();
  });

  Member me() => repo.store.membersOf(DemoIds.circle).value.firstWhere((m) => m.uid == DemoIds.you);
  List<CircleAlert> circleAlerts() => repo.store.alertsOf(DemoIds.circle).value;
  Vehicle bike() => vehicles.vehicles.firstWhere((v) => v.id == 'v-bike');

  test('arming sets the boundary where the phone is and shows it on my pin', () async {
    expect(guard.vehicle!.name, 'Trail bike');
    guard.setRadius(80);
    expect(await guard.arm(), isNull);
    await pumpEventQueue();
    expect(guard.watching, isTrue);
    expect(bike().status, VehicleStatus.guarding);
    expect(bike().boundary!.center, spot);
    expect(bike().boundary!.radiusM, 80);
    expect(me().vehicle!.status, VehicleStatus.guarding);
    expect(me().battery, 80, reason: 'heartbeat reports the battery');
  });

  test('leaving the boundary alerts the circle; recovered closes it', () async {
    await guard.arm();
    await pumpEventQueue();
    guard.testAlarm();
    await pumpEventQueue();

    final a = circleAlerts().first;
    expect(a.type, AlertType.geofence);
    expect(a.message, 'Your Trail bike is on the move');
    expect(a.radiusM, 50);
    expect(a.distanceM, closeTo(95, 1));
    expect(a.open, isTrue);
    expect(guard.stolen, isTrue);
    expect(me().status, MemberStatus.alert);
    expect(me().vehicle!.status, VehicleStatus.stolen);

    // More fixes outside do not repeat the alert.
    guard.testAlarm();
    await pumpEventQueue();
    expect(circleAlerts().where((x) => x.type == AlertType.geofence), hasLength(1));

    await guard.markRecovered();
    await pumpEventQueue();
    expect(circleAlerts().first.recoveredAt, isNotNull);
    expect(bike().status, VehicleStatus.ok);
    expect(bike().boundary, isNull);
    expect(me().status, MemberStatus.paused, reason: 'You are not sharing in the demo');
    expect(guard.watching, isFalse);
  });

  test('low battery warns once and leaves the vehicle guarded', () async {
    battery = 14;
    await guard.arm();
    await pumpEventQueue();
    final low = circleAlerts().where(
      (a) => a.type == AlertType.lowbattery && a.ownerUid == DemoIds.you,
    );
    expect(low.single.message, 'Your phone battery is at 14%');
    expect(bike().status, VehicleStatus.guarding);
  });

  test('movement detection raises a warning when switched on', () async {
    await guard.arm();
    guard.setMotion(on: true);
    await pumpEventQueue();
    final t = DateTime.now();
    for (var i = 0; i < 3; i++) {
      motion.ctrl.add((x: 2.0, y: 0.0, z: 0.0, t: t.add(Duration(milliseconds: i * 100))));
    }
    await pumpEventQueue();
    final moved = circleAlerts().where((a) => a.type == AlertType.motion);
    expect(moved.single.message, 'Your Trail bike was moved');
    expect(bike().status, VehicleStatus.guarding, reason: 'a nudge is a warning only');
  });

  test('the active vehicle shows on my pin; a guarded one cannot be deleted', () async {
    await vehicles.setActive('v-moto');
    await pumpEventQueue();
    expect(me().vehicle!.name, 'Commuter');
    expect(me().vehicle!.type, VehicleType.motorbike);

    await guard.arm();
    await pumpEventQueue();
    await vehicles.delete('v-moto');
    await pumpEventQueue();
    expect(vehicles.vehicles.map((v) => v.id), contains('v-moto'));

    final added = await vehicles.save(
      const Vehicle(id: '', type: VehicleType.car, name: 'Family car'),
    );
    await pumpEventQueue();
    expect(vehicles.vehicles.last.name, 'Family car');
    await vehicles.delete(added.id);
    await pumpEventQueue();
    expect(vehicles.vehicles.map((v) => v.name), isNot(contains('Family car')));
  });

  test('disarmed elsewhere: this phone stops watching', () async {
    await guard.arm();
    await pumpEventQueue();
    await repo.saveVehicle(DemoIds.you, bike().copyWith(status: VehicleStatus.ok, disarm: true));
    await pumpEventQueue();
    expect(guard.watching, isFalse);
    expect(guard.armed, isFalse);
  });

  test('geofence uses the boundary center from arming', () async {
    await guard.arm();
    await pumpEventQueue();
    expect(distanceM(guard.boundary!.center, spot), lessThan(0.01));
  });
}
