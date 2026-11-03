import 'dart:math' as math;

/// Mean Earth radius in meters (IUGG).
const double earthRadiusM = 6371008.8;

/// A WGS84 coordinate. Pure Dart so lib/core stays free of map packages.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) => other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'GeoPoint($lat, $lng)';
}

/// A circular guard zone around a parked vehicle.
class Boundary {
  const Boundary({required this.lat, required this.lng, required this.radiusM});

  final double lat;
  final double lng;
  final double radiusM;

  GeoPoint get center => GeoPoint(lat, lng);

  Map<String, dynamic> toMap() => {'lat': lat, 'lng': lng, 'radiusM': radiusM};

  factory Boundary.fromMap(Map<String, dynamic> m) => Boundary(
    lat: (m['lat'] as num).toDouble(),
    lng: (m['lng'] as num).toDouble(),
    radiusM: (m['radiusM'] as num).toDouble(),
  );
}

double _rad(double deg) => deg * math.pi / 180;
double _deg(double rad) => rad * 180 / math.pi;

/// Great-circle distance in meters.
double haversineM(double lat1, double lng1, double lat2, double lng2) {
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final s1 = math.sin(dLat / 2);
  final s2 = math.sin(dLng / 2);
  final a = s1 * s1 + math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * s2 * s2;
  return 2 * earthRadiusM * math.asin(math.min(1.0, math.sqrt(a)));
}

double distanceM(GeoPoint a, GeoPoint b) => haversineM(a.lat, a.lng, b.lat, b.lng);

/// Total length of a path in meters.
double pathLengthM(List<GeoPoint> path) {
  var total = 0.0;
  for (var i = 1; i < path.length; i++) {
    total += distanceM(path[i - 1], path[i]);
  }
  return total;
}

/// Initial bearing from [a] to [b], 0-360 degrees clockwise from north.
double bearingDeg(GeoPoint a, GeoPoint b) {
  final lat1 = _rad(a.lat);
  final lat2 = _rad(b.lat);
  final dLng = _rad(b.lng - a.lng);
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return (_deg(math.atan2(y, x)) + 360) % 360;
}

/// Moves [origin] by meters north/east (flat-earth approximation, fine below ~20 km).
GeoPoint offsetM(GeoPoint origin, {double northM = 0, double eastM = 0}) {
  final dLat = _deg(northM / earthRadiusM);
  final dLng = _deg(eastM / (earthRadiusM * math.cos(_rad(origin.lat))));
  return GeoPoint(origin.lat + dLat, origin.lng + dLng);
}

/// True when a fix is inside [boundary]. The fix's accuracy radius is added to
/// the boundary radius so a noisy fix near the edge is not treated as an exit.
bool insideBoundary(double lat, double lng, Boundary boundary, [double accuracyM = 0]) {
  final slack = accuracyM.isFinite && accuracyM > 0 ? accuracyM : 0;
  return haversineM(lat, lng, boundary.lat, boundary.lng) <= boundary.radiusM + slack;
}

/// Drops points closer than [minSpacingM] to the previously kept point.
/// The first and last points are always kept.
List<GeoPoint> simplifyPath(List<GeoPoint> path, {double minSpacingM = 10}) {
  if (path.length <= 2) return List.of(path);
  final out = <GeoPoint>[path.first];
  for (var i = 1; i < path.length - 1; i++) {
    if (distanceM(out.last, path[i]) >= minSpacingM) out.add(path[i]);
  }
  if (out.length > 1 && distanceM(out.last, path.last) < minSpacingM) {
    out.removeLast();
  }
  out.add(path.last);
  return out;
}
