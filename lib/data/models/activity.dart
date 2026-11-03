import '../../core/activity_summary.dart';
import '../../core/activity_type.dart';
import '../../core/geo.dart';
import '../../core/polyline.dart';
import 'map_read.dart';

enum ActivityVisibility {
  private('Private'),
  circles('Circles');

  const ActivityVisibility(this.label);
  final String label;
}

/// Weather at the start of an activity.
class WeatherSnapshot {
  const WeatherSnapshot({required this.tempC, required this.windKmh, required this.code});

  final double tempC;
  final double windKmh;

  /// WMO weather code (Open-Meteo).
  final int code;

  factory WeatherSnapshot.fromMap(Map<String, dynamic> m) => WeatherSnapshot(
    tempC: readDouble(m['tempC']),
    windKmh: readDouble(m['windKmh']),
    code: readInt(m['code']),
  );

  Map<String, dynamic> toMap() => {'tempC': tempC, 'windKmh': windKmh, 'code': code};
}

/// users/{uid}/activities/{aid}
class Activity implements ActivityFacts {
  Activity({
    required this.id,
    required this.type,
    required this.title,
    required this.startedAt,
    required this.endedAt,
    required this.distanceM,
    required this.movingSec,
    required this.avgKmh,
    required this.maxKmh,
    required this.path,
    this.elevGainM,
    this.weather,
    this.visibility = ActivityVisibility.private,
    this.vehicleId,
  });

  final String id;
  @override
  final ActivityType type;
  final String title;
  @override
  final DateTime startedAt;
  final DateTime endedAt;
  @override
  final double distanceM;
  @override
  final int movingSec;
  final double avgKmh;
  final double maxKmh;
  final double? elevGainM;

  /// Encoded polyline, points at least 10 m apart.
  final String path;
  final WeatherSnapshot? weather;
  final ActivityVisibility visibility;
  final String? vehicleId;

  Activity copyWith({String? title, ActivityVisibility? visibility}) => Activity(
    id: id,
    type: type,
    title: title ?? this.title,
    startedAt: startedAt,
    endedAt: endedAt,
    distanceM: distanceM,
    movingSec: movingSec,
    avgKmh: avgKmh,
    maxKmh: maxKmh,
    path: path,
    elevGainM: elevGainM,
    weather: weather,
    visibility: visibility ?? this.visibility,
    vehicleId: vehicleId,
  );

  /// Decoded once, on first use.
  late final List<GeoPoint> points = decodePolyline(path);

  factory Activity.fromMap(String id, Map<String, dynamic> m) {
    final w = readMap(m['weather']);
    return Activity(
      id: id,
      type: readEnum(ActivityType.values, m['type'], ActivityType.cycling),
      title: readString(m['title'], 'Activity'),
      startedAt: readDate(m['startedAt']),
      endedAt: readDate(m['endedAt']),
      distanceM: readDouble(m['distanceM']),
      movingSec: readInt(m['movingSec']),
      avgKmh: readDouble(m['avgKmh']),
      maxKmh: readDouble(m['maxKmh']),
      elevGainM: m['elevGainM'] is num ? readDouble(m['elevGainM']) : null,
      path: readString(m['path']),
      weather: w == null ? null : WeatherSnapshot.fromMap(w),
      visibility: readEnum(ActivityVisibility.values, m['visibility'], ActivityVisibility.private),
      vehicleId: m['vehicleId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'title': title,
    'startedAt': startedAt,
    'endedAt': endedAt,
    'distanceM': distanceM,
    'movingSec': movingSec,
    'avgKmh': avgKmh,
    'maxKmh': maxKmh,
    if (elevGainM != null) 'elevGainM': elevGainM,
    'path': path,
    if (weather != null) 'weather': weather!.toMap(),
    'visibility': visibility.name,
    if (vehicleId != null) 'vehicleId': vehicleId,
  };
}
