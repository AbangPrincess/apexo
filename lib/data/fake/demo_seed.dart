import 'dart:math' as math;

import '../../core/activity_type.dart';
import '../../core/geo.dart';
import '../../core/polyline.dart';
import '../../core/units.dart';
import '../models/activity.dart';
import '../models/circle.dart';
import '../models/circle_alert.dart';
import '../models/user.dart';

abstract final class DemoIds {
  static const you = 'demo-you';
  static const jero = 'demo-jero';
  static const shane = 'demo-shane';
  static const circle = 'trail-buddies';
  static const inviteCode = 'TRAIL7';
}

/// Koronadal City, South Cotabato.
const koronadal = GeoPoint(6.50, 124.85);

/// Everything the demo backend starts with. Paths are generated, then
/// simplified (>= 10 m) and encoded, exactly like recorded activities.
class DemoSeed {
  DemoSeed._(this.now);

  final DateTime now;

  late final AppUser you = AppUser(
    uid: DemoIds.you,
    displayName: 'You',
    email: 'demo@pedaltrack.app',
    createdAt: now.subtract(const Duration(days: 42)),
  );

  late final List<Vehicle> vehicles = const [
    Vehicle(id: 'v-bike', type: VehicleType.bike, name: 'Trail bike'),
    Vehicle(id: 'v-moto', type: VehicleType.motorbike, name: 'Commuter'),
  ];

  /// Jero's scripted ride; starts at his parking spot.
  late final List<GeoPoint> jeroLoop = _loop(
    offsetM(koronadal, northM: 250, eastM: -350),
    northM: 420, eastM: 600, wobble: 0.06, lobes: 3, n: 240,
  );

  late final Boundary jeroBoundary =
      Boundary(lat: jeroLoop.first.lat, lng: jeroLoop.first.lng, radiusM: 50);

  late final Circle circle = Circle(
    id: DemoIds.circle,
    name: 'Trail Buddies',
    inviteCode: DemoIds.inviteCode,
    ownerUid: DemoIds.you,
    memberUids: const [DemoIds.you, DemoIds.jero, DemoIds.shane],
    createdAt: now.subtract(const Duration(days: 30)),
  );

  late final GeoPoint _shaneSpot = offsetM(koronadal, northM: -420, eastM: -380);

  late final List<Member> members = [
    Member(
      uid: DemoIds.you, displayName: 'You',
      lat: koronadal.lat, lng: koronadal.lng, battery: 86,
      status: MemberStatus.paused, sharing: false,
      ts: now.subtract(const Duration(minutes: 2)),
      vehicle: const MemberVehicle(type: VehicleType.bike, name: 'Trail bike'),
    ),
    Member(
      uid: DemoIds.jero, displayName: 'Jero',
      lat: jeroLoop.first.lat, lng: jeroLoop.first.lng, battery: 64,
      status: MemberStatus.parked, ts: now,
      vehicle: const MemberVehicle(
          type: VehicleType.bike, name: 'Blue MTB', status: VehicleStatus.guarding),
    ),
    Member(
      uid: DemoIds.shane, displayName: 'Shane',
      lat: _shaneSpot.lat, lng: _shaneSpot.lng, battery: 41,
      status: MemberStatus.parked, ts: now.subtract(const Duration(minutes: 3)),
      vehicle: const MemberVehicle(type: VehicleType.motorbike, name: 'Black scooter'),
    ),
  ];

  late final List<CircleAlert> alerts = [
    CircleAlert(
      id: 'alert-seed-1', type: AlertType.lowbattery, ownerUid: DemoIds.shane,
      vehicleName: 'Black scooter', message: "Shane's phone battery is at 15%",
      lat: _shaneSpot.lat, lng: _shaneSpot.lng, distanceM: 0,
      ts: _at(1, 21, 14), ackBy: const [DemoIds.you],
    ),
  ];

  late final List<Activity> activities = [
    _activity('a1', ActivityType.cycling, 'Morning Ride', _at(1, 6, 10),
        _loop(offsetM(koronadal, northM: 300, eastM: -200), northM: 900, eastM: 1300),
        avgKmh: 19.4, elev: 64, vis: ActivityVisibility.circles, vehicleId: 'v-bike',
        weather: const WeatherSnapshot(tempC: 26.5, windKmh: 8, code: 1)),
    _activity('a2', ActivityType.motorcycling, 'Lunch Commute', _at(2, 12, 5),
        _outAndBack(koronadal, lengthM: 2600, bearing: 40),
        avgKmh: 31.5, vehicleId: 'v-moto',
        weather: const WeatherSnapshot(tempC: 31.2, windKmh: 12, code: 2)),
    _activity('a3', ActivityType.driving, 'Market Run', _at(3, 16, 40),
        _loop(offsetM(koronadal, northM: -600, eastM: 500),
            northM: 1200, eastM: 1700, lobes: 4),
        avgKmh: 27.0, weather: const WeatherSnapshot(tempC: 30.1, windKmh: 14, code: 3)),
    _activity('a4', ActivityType.cycling, 'Sunday Hill Loop', _at(5, 5, 45),
        _loop(offsetM(koronadal, northM: 800, eastM: 900),
            northM: 2000, eastM: 2600, wobble: 0.12, lobes: 5),
        avgKmh: 16.8, elev: 212, vis: ActivityVisibility.circles, vehicleId: 'v-bike',
        weather: const WeatherSnapshot(tempC: 24.8, windKmh: 6, code: 0)),
    _activity('a5', ActivityType.cycling, 'Evening Spin', _at(6, 17, 30),
        _loop(koronadal, northM: 650, eastM: 900, phase: 1.2),
        avgKmh: 21.2, elev: 22, vis: ActivityVisibility.circles, vehicleId: 'v-bike',
        weather: const WeatherSnapshot(tempC: 28.4, windKmh: 10, code: 2)),
    _activity('a6', ActivityType.motorcycling, 'Night Ride to Town', _at(9, 19, 20),
        _outAndBack(koronadal, lengthM: 4200, bearing: 200),
        avgKmh: 35.4, vehicleId: 'v-moto',
        weather: const WeatherSnapshot(tempC: 25.9, windKmh: 5, code: 0)),
  ];

  static DemoSeed build(DateTime now) => DemoSeed._(now);

  DateTime _at(int daysAgo, int hour, int minute) =>
      DateTime(now.year, now.month, now.day - daysAgo, hour, minute);

  static Activity _activity(String id, ActivityType type, String title,
      DateTime start, List<GeoPoint> raw,
      {required double avgKmh,
      double? elev,
      ActivityVisibility vis = ActivityVisibility.private,
      WeatherSnapshot? weather,
      String? vehicleId}) {
    final pts = simplifyPath(raw);
    final dist = pathLengthM(pts);
    final moving = (dist / kmhToMps(avgKmh)).round();
    return Activity(
      id: id, type: type, title: title, startedAt: start,
      endedAt: start.add(Duration(seconds: (moving * 1.12).round())),
      distanceM: dist, movingSec: moving, avgKmh: avgKmh,
      maxKmh: avgKmh * 1.48, elevGainM: elev, path: encodePolyline(pts),
      weather: weather, visibility: vis, vehicleId: vehicleId,
    );
  }

  /// A closed, slightly wavy loop around [c].
  static List<GeoPoint> _loop(GeoPoint c,
      {required double northM,
      required double eastM,
      double wobble = 0.08,
      int lobes = 3,
      int n = 160,
      double phase = 0}) {
    final pts = <GeoPoint>[];
    for (var i = 0; i <= n; i++) {
      final t = 2 * math.pi * i / n + phase;
      final r = 1 + wobble * math.sin(lobes * t);
      pts.add(offsetM(c, northM: northM * r * math.sin(t), eastM: eastM * r * math.cos(t)));
    }
    return pts;
  }

  /// Out along [bearing] with gentle bends, back on the other side of the road.
  static List<GeoPoint> _outAndBack(GeoPoint start,
      {required double lengthM, required double bearing, int n = 90}) {
    final b = bearing * math.pi / 180;
    GeoPoint at(double along, double side) => offsetM(start,
        northM: along * math.cos(b) - side * math.sin(b),
        eastM: along * math.sin(b) + side * math.cos(b));
    final out = [
      for (var i = 0; i <= n; i++)
        at(lengthM * i / n, 70 * math.sin(i / n * 3 * math.pi)),
    ];
    final back = [
      for (var i = n; i >= 0; i--)
        at(lengthM * i / n, 70 * math.sin(i / n * 3 * math.pi) + 14),
    ];
    return [...out, ...back];
  }
}
