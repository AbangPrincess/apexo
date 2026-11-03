/// Distance units stored on the profile as 'km' | 'mi'.
enum Units { km, mi }

const double kmPerMile = 1.609344;

double kmToMi(double km) => km / kmPerMile;
double miToKm(double mi) => mi * kmPerMile;
double mpsToKmh(double mps) => mps * 3.6;
double kmhToMps(double kmh) => kmh / 3.6;

extension UnitsLabels on Units {
  String get distanceLabel => this == Units.km ? 'km' : 'mi';
  String get speedLabel => this == Units.km ? 'km/h' : 'mph';
}

/// Distance number only, e.g. "12.34" (2 decimals below 100, else 1).
String formatDistance(double meters, Units units) {
  final km = meters / 1000;
  final v = units == Units.km ? km : kmToMi(km);
  return v.toStringAsFixed(v.abs() < 100 ? 2 : 1);
}

/// Speed number only, e.g. "18.4".
String formatSpeed(double kmh, Units units) {
  final v = units == Units.km ? kmh : kmToMi(kmh);
  return v.toStringAsFixed(1);
}

/// Stopwatch style: "45:09" or "1:05:09".
String formatDuration(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = (s % 60).toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$sec';
  return '$m:$sec';
}

/// Compact: "1h 05m" or "42m" or "35s".
String formatDurationShort(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  if (m > 0) return '${m}m';
  return '${s}s';
}
