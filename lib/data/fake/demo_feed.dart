import '../../core/activity_type.dart';
import '../../core/geo.dart';
import '../models/activity.dart';
import '../models/shared_activity.dart';
import '../models/user.dart';
import 'demo_routes.dart';
import 'demo_seed.dart';

/// Trail Buddies' shared feed: John's and Sarah's rides plus the demo
/// user's own "Circles" activities, newest first.
List<SharedActivity> demoCircleFeed(DemoSeed seed) {
  final now = seed.now;
  DateTime at(int daysAgo, int hour, int minute) =>
      DateTime(now.year, now.month, now.day - daysAgo, hour, minute);
  AppUser friend(String uid, String name) =>
      AppUser(uid: uid, displayName: name, email: '', createdAt: now);
  final john = friend(DemoIds.john, 'John');
  final sarah = friend(DemoIds.sarah, 'Sarah');

  final items = [
    SharedActivity.of(
      sarah,
      DemoSeed.buildActivity(
        'sarah-1',
        ActivityType.motorcycling,
        'Coffee Run',
        at(1, 7, 15),
        demoOutAndBack(koronadal, lengthM: 3100, bearing: 120),
        avgKmh: 28.6,
        vis: ActivityVisibility.circles,
        weather: const WeatherSnapshot(tempC: 25.4, windKmh: 7, code: 1),
      ),
      now,
    ),
    SharedActivity.of(
      john,
      DemoSeed.buildActivity(
        'john-1',
        ActivityType.cycling,
        'Ridge Trail Loop',
        at(2, 5, 30),
        demoLoop(
          offsetM(koronadal, northM: 1200, eastM: -900),
          northM: 1500,
          eastM: 2100,
          wobble: 0.14,
          lobes: 6,
        ),
        avgKmh: 15.2,
        elev: 286,
        vis: ActivityVisibility.circles,
        weather: const WeatherSnapshot(tempC: 23.9, windKmh: 5, code: 0),
      ),
      now,
    ),
    SharedActivity.of(
      john,
      DemoSeed.buildActivity(
        'john-2',
        ActivityType.cycling,
        'Recovery Spin',
        at(4, 17, 50),
        demoLoop(koronadal, northM: 700, eastM: 1000, phase: 2.1),
        avgKmh: 18.1,
        elev: 18,
        vis: ActivityVisibility.circles,
      ),
      now,
    ),
    SharedActivity.of(
      sarah,
      DemoSeed.buildActivity(
        'sarah-2',
        ActivityType.running,
        'Morning Jog',
        at(3, 5, 40),
        demoLoop(offsetM(koronadal, northM: -300, eastM: 200), northM: 450, eastM: 650, phase: 0.7),
        avgKmh: 8.6,
        elev: 12,
        vis: ActivityVisibility.circles,
      ),
      now,
    ),
    for (final a in seed.activities)
      if (a.visibility == ActivityVisibility.circles) SharedActivity.of(seed.you, a, now),
  ];
  return items..sort((a, b) => b.activity.startedAt.compareTo(a.activity.startedAt));
}
