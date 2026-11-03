import 'dart:math' as math;

import 'geo.dart';

// Encoded polyline algorithm (precision 5). Only arithmetic is used for the
// sign folding (no `~`), because bitwise NOT is unsigned 32-bit on the web.

String encodePolyline(List<GeoPoint> points, {int precision = 5}) {
  final factor = math.pow(10, precision);
  final out = StringBuffer();
  var lastLat = 0;
  var lastLng = 0;
  for (final p in points) {
    final lat = (p.lat * factor).round();
    final lng = (p.lng * factor).round();
    _writeValue(lat - lastLat, out);
    _writeValue(lng - lastLng, out);
    lastLat = lat;
    lastLng = lng;
  }
  return out.toString();
}

void _writeValue(int delta, StringBuffer out) {
  var v = delta < 0 ? (-delta) * 2 - 1 : delta * 2;
  while (v >= 0x20) {
    out.writeCharCode((0x20 | (v & 0x1f)) + 63);
    v >>= 5;
  }
  out.writeCharCode(v + 63);
}

List<GeoPoint> decodePolyline(String encoded, {int precision = 5}) {
  final factor = math.pow(10, precision).toDouble();
  final points = <GeoPoint>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  int? readValue() {
    var result = 0;
    var shift = 0;
    int b;
    do {
      if (index >= encoded.length) return null;
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final half = result ~/ 2;
    return result.isOdd ? -(half + 1) : half;
  }

  while (index < encoded.length) {
    final dLat = readValue();
    final dLng = readValue();
    if (dLat == null || dLng == null) break; // truncated input
    lat += dLat;
    lng += dLng;
    points.add(GeoPoint(lat / factor, lng / factor));
  }
  return points;
}
