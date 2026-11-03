import 'package:flutter_test/flutter_test.dart';
import 'package:apexo/core/geo.dart';
import 'package:apexo/core/polyline.dart';

void main() {
  const center = GeoPoint(6.50, 124.85);

  group('haversine and path length', () {
    test('one degree of longitude on the equator is ~111.2 km', () {
      expect(haversineM(0, 0, 0, 1), closeTo(111195, 2));
    });

    test('0.01 degree of latitude near Koronadal is ~1.11 km', () {
      expect(haversineM(6.50, 124.85, 6.51, 124.85), closeTo(1111.95, 0.5));
    });

    test('same point is zero', () {
      expect(distanceM(center, center), 0);
    });

    test('path length sums segments', () {
      const path = [GeoPoint(0, 0), GeoPoint(0, 0.001), GeoPoint(0, 0.002)];
      expect(pathLengthM(path), closeTo(222.39, 0.05));
      expect(pathLengthM(const []), 0);
      expect(pathLengthM(const [GeoPoint(1, 1)]), 0);
    });

    test('offset and bearing agree', () {
      final p = offsetM(center, northM: 300, eastM: 400);
      expect(distanceM(center, p), closeTo(500, 1));
      expect(bearingDeg(center, offsetM(center, northM: 100)), closeTo(0, 0.01));
      expect(bearingDeg(center, offsetM(center, eastM: 100)), closeTo(90, 0.01));
    });
  });

  group('insideBoundary', () {
    final boundary = Boundary(lat: center.lat, lng: center.lng, radiusM: 50);

    test('inside, outside and accuracy slack', () {
      final near = offsetM(center, northM: 40);
      final far = offsetM(center, northM: 60);
      expect(insideBoundary(near.lat, near.lng, boundary), isTrue);
      expect(insideBoundary(far.lat, far.lng, boundary), isFalse);
      expect(insideBoundary(far.lat, far.lng, boundary, 15), isTrue);
    });

    test('negative or invalid accuracy adds no slack', () {
      final far = offsetM(center, northM: 60);
      expect(insideBoundary(far.lat, far.lng, boundary, -30), isFalse);
      expect(insideBoundary(far.lat, far.lng, boundary, double.nan), isFalse);
    });

    test('boundary map round trip', () {
      final copy = Boundary.fromMap(boundary.toMap());
      expect(copy.radiusM, 50);
      expect(copy.center, center);
    });
  });

  group('simplifyPath', () {
    test('keeps points at least 10 m apart and both ends', () {
      final raw = [for (var i = 0; i <= 34; i++) offsetM(center, eastM: i * 3.0)];
      final out = simplifyPath(raw);
      expect(out.first, raw.first);
      expect(out.last, raw.last);
      for (var i = 1; i < out.length; i++) {
        expect(distanceM(out[i - 1], out[i]), greaterThanOrEqualTo(9.99));
      }
      expect(out.length, lessThan(raw.length));
    });

    test('short paths are returned unchanged', () {
      final two = [center, offsetM(center, northM: 2)];
      expect(simplifyPath(two), two);
      expect(simplifyPath(const []), isEmpty);
    });
  });

  group('polyline', () {
    test('matches the reference encoding', () {
      const pts = [GeoPoint(38.5, -120.2), GeoPoint(40.7, -120.95), GeoPoint(43.252, -126.453)];
      expect(encodePolyline(pts), '_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      final back = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(back.length, 3);
      expect(back[2].lat, closeTo(43.252, 1e-6));
      expect(back[2].lng, closeTo(-126.453, 1e-6));
    });

    test('round trips local coordinates within 1e-5 degrees', () {
      final pts = [
        for (var i = 0; i < 50; i++)
          offsetM(center, northM: i * 13.0 - 200, eastM: (i % 7) * -21.0),
      ];
      final back = decodePolyline(encodePolyline(pts));
      expect(back.length, pts.length);
      for (var i = 0; i < pts.length; i++) {
        expect(back[i].lat, closeTo(pts[i].lat, 1e-5));
        expect(back[i].lng, closeTo(pts[i].lng, 1e-5));
      }
    });

    test('empty and truncated input are safe', () {
      expect(encodePolyline(const []), '');
      expect(decodePolyline(''), isEmpty);
      expect(decodePolyline('_p~iF~ps|U_ulL').length, 1);
    });
  });
}
