import 'package:apexo/data/fake/demo_seed.dart';
import 'package:apexo/data/fake/fake_repository.dart';
import 'package:apexo/data/models/circle.dart';
import 'package:apexo/features/circle/sharing_controller.dart';
import 'package:apexo/features/record/location_source.dart';
import 'package:apexo/features/record/record_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeRepository repo;
  late RecordController record;
  late SharingController sharing;
  final demoSpot = SimulatedLocationSource().start;

  setUp(() {
    repo = FakeRepository(simulate: false, latency: Duration.zero);
    record = RecordController(
      repo,
      device: SimulatedLocationSource(),
      simulator: SimulatedLocationSource(),
    );
    sharing = SharingController(repo, record, readBattery: () async => 77);
  });

  tearDown(() {
    sharing.dispose();
    record.dispose();
    repo.dispose();
  });

  Member me() => repo.store.membersOf(DemoIds.circle).value.firstWhere((m) => m.uid == DemoIds.you);

  test('sharing on publishes my position; pausing hides it again', () async {
    await repo.signInDemo();
    await pumpEventQueue();
    expect(sharing.active, isFalse);
    expect(me().onMap, isFalse);

    expect(await sharing.setSharing(DemoIds.circle, true), isNull);
    await pumpEventQueue();
    expect(sharing.active, isTrue);
    expect(sharing.isSharing(DemoIds.circle), isTrue);
    expect(me().onMap, isTrue);
    expect(me().point, demoSpot);
    expect(me().battery, 77);
    expect(me().status, MemberStatus.parked);

    expect(await sharing.setSharing(DemoIds.circle, false), isNull);
    await pumpEventQueue();
    expect(sharing.active, isFalse);
    expect(me().status, MemberStatus.paused);
    expect(me().onMap, isFalse);
    expect(me().lat, 0, reason: 'members cannot read where I paused');
  });

  test('leaving a shared circle stops sharing; sign-out forgets everything', () async {
    await repo.signInDemo();
    await pumpEventQueue();
    await sharing.setSharing(DemoIds.circle, true);
    await pumpEventQueue();
    expect(sharing.sharingCount, 1);

    await repo.leaveCircle(DemoIds.circle, DemoIds.you);
    await pumpEventQueue();
    expect(sharing.active, isFalse);

    await repo.signOut();
    await pumpEventQueue();
    expect(sharing.sharingCount, 0);
  });
}
