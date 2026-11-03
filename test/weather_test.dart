import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:apexo/core/geo.dart';
import 'package:apexo/core/time_format.dart';
import 'package:apexo/core/weather.dart';
import 'package:apexo/data/weather_source.dart';
import 'package:apexo/features/weather/weather_controller.dart';

import 'weather_fixtures.dart';

/// Trimmed real response (Koronadal, timezone=auto).
const sample = '''
{"latitude":6.5026364,"longitude":124.88255,"utc_offset_seconds":28800,"timezone":"Asia/Manila",
"current":{"time":"2026-11-03T23:00","interval":900,"temperature_2m":24.7,
"apparent_temperature":30.3,"precipitation":0.00,"weather_code":1,"wind_speed_10m":0.4,
"wind_direction_10m":333,"is_day":0},
"hourly":{"time":["2026-11-03T23:00","2026-11-04T00:00","2026-11-04T01:00"],
"temperature_2m":[24.7,24.2,null],"precipitation_probability":[5,12,40],
"wind_speed_10m":[0.4,1.8,3.1],"weather_code":[1,2,61],"is_day":[0,0,0]}}
''';

void main() {
  final fetchedAt = DateTime.utc(2026, 11, 3, 15, 5);

  group('Weather.fromOpenMeteo', () {
    final w = Weather.fromOpenMeteo(jsonDecode(sample), fetchedAt: fetchedAt);

    test('reads current conditions', () {
      expect(w.current.tempC, 24.7);
      expect(w.current.feelsLikeC, 30.3);
      expect(w.current.windFromDeg, 333);
      expect(w.current.isDay, isFalse);
      expect(compassPoint(w.current.windFromDeg), 'NW');
    });

    test('local times become UTC instants; labels use the location clock', () {
      expect(w.utcOffset, manila);
      expect(w.hourly.first.time, DateTime.utc(2026, 11, 3, 15));
      expect(formatHour(w.localTime(w.hourly[1].time)), '12 AM');
      expect(w.hourly[2].rainPct, 40);
      expect(w.hourly[2].tempC, 0, reason: 'nulls read as 0, not a crash');
    });

    test('upcoming starts with the hour in progress', () {
      final hours = w.upcoming(DateTime.utc(2026, 11, 3, 15, 40), 6);
      expect(hours.length, 3);
      expect(w.upcoming(DateTime.utc(2026, 11, 3, 16, 1), 6).first.code, 2);
    });

    test('conditionsAt uses current values near the fetch, else the forecast hour', () {
      expect(w.conditionsAt(fetchedAt.add(const Duration(minutes: 20)))!.tempC, 24.7);
      expect(w.conditionsAt(DateTime.utc(2026, 11, 3, 16, 30))!.code, 2);
      expect(w.conditionsAt(DateTime.utc(2026, 11, 5)), isNull);
    });
  });

  group('OpenMeteoSource', () {
    test('asks for a rounded location and parses the reply', () async {
      Uri? asked;
      final source = OpenMeteoSource(
        MockClient((req) async {
          asked = req.url;
          return http.Response(sample, 200);
        }),
      );
      final w = await source.fetch(const GeoPoint(6.503512, 124.844871));
      expect(asked!.host, 'api.open-meteo.com');
      expect(asked!.queryParameters['latitude'], '6.50');
      expect(asked!.queryParameters['longitude'], '124.84');
      expect(asked!.queryParameters['timezone'], 'auto');
      expect(asked!.queryParameters['hourly'], contains('precipitation_probability'));
      expect(w.hourly, hasLength(3));
    });

    test('throws on a server error', () {
      final source = OpenMeteoSource(MockClient((_) async => http.Response('oops', 500)));
      expect(source.fetch(const GeoPoint(0, 0)), throwsA(isA<http.ClientException>()));
    });
  });

  group('WeatherController', () {
    var now = DateTime.utc(2026, 11, 3, 0);
    final fakeClock = Clock(() => now);

    test('caches for 15 minutes and keeps the last result when offline', () {
      return withClock(fakeClock, () async {
        final source = FakeWeatherSource();
        final wc = WeatherController(source);
        await wc.load();
        await wc.load();
        expect(source.calls, 1);
        expect(source.lastPoint, WeatherPlace.koronadal.point);
        expect(wc.place.label, 'Koronadal City');

        now = now.add(const Duration(minutes: 14));
        await wc.load();
        expect(source.calls, 1);

        now = now.add(const Duration(minutes: 2));
        source.offline = true;
        await wc.load();
        expect(source.calls, 2);
        expect(wc.failed, isTrue);
        expect(wc.weather, isNotNull);
        expect(formatAgo(wc.updatedAt!, now), '16 min ago');

        source.offline = false;
        await wc.load();
        expect(wc.failed, isFalse);
        expect(wc.updatedAt, now);
        wc.dispose();
      });
    });

    test('uses the device position only when it is given', () {
      return withClock(fakeClock, () async {
        final source = FakeWeatherSource();
        final wc = WeatherController(source, devicePosition: () async => const GeoPoint(14.6, 121));
        await wc.load();
        expect(source.lastPoint, const GeoPoint(14.6, 121));
        expect(wc.place.label, 'Your location');
        final snap = wc.snapshotAt(now);
        expect(snap!.tempC, 27);
        expect(snap.windKmh, 9);
        wc.dispose();
      });
    });
  });
}
