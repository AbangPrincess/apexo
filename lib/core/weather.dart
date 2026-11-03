/// Weather for a ride, parsed from an Open-Meteo forecast. Pure Dart.
library;

/// Conditions right now.
class CurrentWeather {
  const CurrentWeather({
    required this.tempC,
    required this.feelsLikeC,
    required this.windKmh,
    required this.windFromDeg,
    required this.precipMm,
    required this.code,
    this.isDay = true,
  });

  final double tempC;
  final double feelsLikeC;
  final double windKmh;

  /// Direction the wind blows from, degrees clockwise from north.
  final double windFromDeg;
  final double precipMm;

  /// WMO weather code.
  final int code;
  final bool isDay;
}

/// One forecast hour, covering [time] to [time] + 1 h.
class HourForecast {
  const HourForecast({
    required this.time,
    required this.tempC,
    required this.rainPct,
    required this.windKmh,
    required this.code,
    this.isDay = true,
  });

  /// Start of the hour, as a UTC instant.
  final DateTime time;
  final double tempC;

  /// Precipitation probability, 0-100.
  final int rainPct;
  final double windKmh;
  final int code;
  final bool isDay;
}

class Weather {
  const Weather({
    required this.current,
    required this.hourly,
    required this.utcOffset,
    required this.fetchedAt,
  });

  final CurrentWeather current;

  /// Sorted by time.
  final List<HourForecast> hourly;

  /// Offset of the forecast location's local time from UTC.
  final Duration utcOffset;
  final DateTime fetchedAt;

  /// Wall-clock time at the forecast location (fields of a UTC DateTime),
  /// so labels do not depend on the device's time zone.
  DateTime localTime(DateTime instant) => instant.toUtc().add(utcOffset);

  /// The hour containing [now] and the [count] - 1 hours after it.
  List<HourForecast> upcoming(DateTime now, int count) =>
      hourly.where((h) => h.time.add(const Duration(hours: 1)).isAfter(now)).take(count).toList();

  /// Temperature, wind and code at [t]: current values when [t] is close to
  /// the fetch time, else the forecast hour containing [t].
  ({double tempC, double windKmh, int code})? conditionsAt(DateTime t) {
    if (t.difference(fetchedAt).abs() <= const Duration(minutes: 30)) {
      return (tempC: current.tempC, windKmh: current.windKmh, code: current.code);
    }
    final h = upcoming(t, 1).firstOrNull;
    if (h == null || h.time.isAfter(t)) return null;
    return (tempC: h.tempC, windKmh: h.windKmh, code: h.code);
  }

  /// Parses `/v1/forecast` with `timezone=auto`, where times are local to the
  /// location ("2026-11-03T14:00") and `utc_offset_seconds` gives the offset.
  factory Weather.fromOpenMeteo(Map<String, dynamic> json, {required DateTime fetchedAt}) {
    final offset = Duration(seconds: _int(json['utc_offset_seconds']));
    final c = json['current'] as Map<String, dynamic>;
    final h = json['hourly'] as Map<String, dynamic>;
    final times = (h['time'] as List).cast<String>();
    List<dynamic> col(String key) => (h[key] as List?) ?? List<dynamic>.filled(times.length, null);
    final temp = col('temperature_2m');
    final rain = col('precipitation_probability');
    final wind = col('wind_speed_10m');
    final code = col('weather_code');
    final day = col('is_day');
    return Weather(
      current: CurrentWeather(
        tempC: _double(c['temperature_2m']),
        feelsLikeC: _double(c['apparent_temperature'] ?? c['temperature_2m']),
        windKmh: _double(c['wind_speed_10m']),
        windFromDeg: _double(c['wind_direction_10m']),
        precipMm: _double(c['precipitation']),
        code: _int(c['weather_code']),
        isDay: c['is_day'] == null || _int(c['is_day']) == 1,
      ),
      hourly: [
        for (var i = 0; i < times.length; i++)
          HourForecast(
            time: _localToUtc(times[i], offset),
            tempC: _double(temp[i]),
            rainPct: _int(rain[i]),
            windKmh: _double(wind[i]),
            code: _int(code[i]),
            isDay: day[i] == null || _int(day[i]) == 1,
          ),
      ],
      utcOffset: offset,
      fetchedAt: fetchedAt,
    );
  }
}

DateTime _localToUtc(String local, Duration offset) {
  final hasZone = local.endsWith('Z') || RegExp(r'[+-]\d\d:?\d\d$').hasMatch(local);
  return hasZone ? DateTime.parse(local).toUtc() : DateTime.parse('${local}Z').subtract(offset);
}

double _double(Object? v) => v is num ? v.toDouble() : 0;
int _int(Object? v) => v is num ? v.round() : 0;

/// "N", "NE", ... for a bearing in degrees.
String compassPoint(double deg) {
  const points = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  return points[((deg % 360) / 45).round() % 8];
}
