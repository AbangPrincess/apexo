import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;

import '../core/geo.dart';
import '../core/weather.dart';

/// Where forecasts come from. Tests pass a fake.
abstract interface class WeatherSource {
  Future<Weather> fetch(GeoPoint at);
}

/// Open-Meteo forecast API (free, no key).
class OpenMeteoSource implements WeatherSource {
  OpenMeteoSource([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  /// Coordinates are rounded to 0.01 deg (about 1 km), finer than the
  /// forecast grid needs, so the exact position never leaves the device.
  static Uri forecastUri(GeoPoint at) => Uri.https('api.open-meteo.com', '/v1/forecast', {
    'latitude': at.lat.toStringAsFixed(2),
    'longitude': at.lng.toStringAsFixed(2),
    'current':
        'temperature_2m,apparent_temperature,precipitation,weather_code,'
        'wind_speed_10m,wind_direction_10m,is_day',
    'hourly': 'temperature_2m,precipitation_probability,wind_speed_10m,weather_code,is_day',
    'forecast_days': '2',
    'timezone': 'auto',
  });

  @override
  Future<Weather> fetch(GeoPoint at) async {
    final res = await _client.get(forecastUri(at)).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw http.ClientException('Weather service returned ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return Weather.fromOpenMeteo(json, fetchedAt: clock.now());
  }
}
