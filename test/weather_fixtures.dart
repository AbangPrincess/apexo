import 'package:clock/clock.dart';
import 'package:apexo/core/geo.dart';
import 'package:apexo/core/weather.dart';
import 'package:apexo/data/weather_source.dart';

/// Koronadal is UTC+8.
const manila = Duration(hours: 8);

HourForecast hourAt(
  DateTime time, {
  double tempC = 24,
  int rainPct = 0,
  double windKmh = 5,
  int code = 1,
  bool isDay = true,
}) => HourForecast(
  time: time,
  tempC: tempC,
  rainPct: rainPct,
  windKmh: windKmh,
  code: code,
  isDay: isDay,
);

CurrentWeather currentWith({
  double tempC = 24,
  double windKmh = 5,
  int code = 1,
  double precipMm = 0,
  bool isDay = true,
}) => CurrentWeather(
  tempC: tempC,
  feelsLikeC: tempC + 2,
  windKmh: windKmh,
  windFromDeg: 45,
  precipMm: precipMm,
  code: code,
  isDay: isDay,
);

/// [count] calm, dry hours from [start]; [overrides] replaces hours by index.
Weather weatherFrom(
  DateTime start, {
  CurrentWeather? current,
  int count = 24,
  Map<int, HourForecast Function(DateTime t)> overrides = const {},
  DateTime? fetchedAt,
}) => Weather(
  current: current ?? currentWith(),
  hourly: [for (var i = 0; i < count; i++) (overrides[i] ?? hourAt)(start.add(Duration(hours: i)))],
  utcOffset: manila,
  fetchedAt: fetchedAt ?? start,
);

/// A pleasant day around the current (possibly faked) time. Counts calls and
/// can be switched to fail like an offline device.
class FakeWeatherSource implements WeatherSource {
  int calls = 0;
  bool offline = false;
  GeoPoint? lastPoint;

  @override
  Future<Weather> fetch(GeoPoint at) async {
    calls++;
    lastPoint = at;
    if (offline) throw Exception('offline');
    final now = clock.now().toUtc();
    final start = DateTime.utc(now.year, now.month, now.day, now.hour - 2);
    return weatherFrom(
      start,
      count: 30,
      current: currentWith(tempC: 27, windKmh: 9, code: 2),
      overrides: {
        for (var i = 0; i < 30; i++)
          i: (t) {
            final local = t.add(manila).hour;
            return hourAt(
              t,
              tempC: 26 + (i % 5).toDouble(),
              rainPct: 10,
              windKmh: 8,
              code: i.isEven ? 1 : 2,
              isDay: local >= 6 && local < 18,
            );
          },
      },
      fetchedAt: clock.now(),
    );
  }
}
