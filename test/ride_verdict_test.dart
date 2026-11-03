import 'package:flutter_test/flutter_test.dart';
import 'package:apexo/core/activity_type.dart';
import 'package:apexo/core/ride_verdict.dart';
import 'package:apexo/core/weather.dart';

import 'weather_fixtures.dart';

// 08:00 in Koronadal.
final t0 = DateTime.utc(2026, 11, 3, 0);
final now = t0.add(const Duration(minutes: 10));

RideCall call(Weather w, [ActivityType type = ActivityType.cycling]) =>
    rideVerdict(type, w, now: now);

Weather withCurrent({double tempC = 24, double windKmh = 5, int code = 1, bool isDay = true}) =>
    weatherFrom(
      t0,
      current: currentWith(tempC: tempC, windKmh: windKmh, code: code, isDay: isDay),
    );

Weather withRain(int pct, {int atHour = 0}) =>
    weatherFrom(t0, overrides: {atHour: (t) => hourAt(t, rainPct: pct)});

void main() {
  group('rideVerdict', () {
    test('calm, dry and mild is Great', () {
      final c = call(withCurrent());
      expect(c.verdict, Verdict.great);
      expect(c.reason, 'Dry and calm - enjoy the ride');
    });

    test('wind: >30 km/h caution, >45 avoid, at the limit only breezy', () {
      expect(call(withCurrent(windKmh: 30)).verdict, Verdict.ok);
      final strong = call(withCurrent(windKmh: 31));
      expect(strong.verdict, Verdict.caution);
      expect(strong.reason, 'Strong wind - expect a tough push');
      expect(call(withCurrent(windKmh: 45)).verdict, Verdict.caution);
      expect(call(withCurrent(windKmh: 46)).verdict, Verdict.avoid);
    });

    test('rain chance: >50 % caution with timing, >75 % avoid', () {
      expect(call(withRain(50)).verdict, Verdict.ok);
      expect(call(withRain(50)).reason, 'Some chance of rain (50%)');
      final later = call(withRain(60, atHour: 2));
      expect(later.verdict, Verdict.caution);
      expect(later.reason, 'Rain likely in 2 h');
      expect(call(withRain(60)).reason, 'Rain likely within the hour');
      expect(call(withRain(75)).verdict, Verdict.caution);
      final heavy = call(withRain(76, atHour: 1));
      expect(heavy.verdict, Verdict.avoid);
      expect(heavy.reason, 'Heavy rain likely in 1 h');
    });

    test('rain beyond the next 3 hours does not count', () {
      expect(call(withRain(90, atHour: 3)).verdict, Verdict.great);
    });

    test('temperature: below 5 or above 36 C is caution', () {
      expect(call(withCurrent(tempC: 4)).verdict, Verdict.caution);
      expect(call(withCurrent(tempC: 5)).verdict, Verdict.ok);
      expect(call(withCurrent(tempC: 36)).verdict, Verdict.ok);
      expect(call(withCurrent(tempC: 36)).reason, 'Hot - bring water');
      final hot = call(withCurrent(tempC: 37));
      expect(hot.verdict, Verdict.caution);
      expect(hot.reason, contains('Very hot'));
    });

    test('rain falling now is caution for riders', () {
      final c = call(withCurrent(code: 63));
      expect(c.verdict, Verdict.caution);
      expect(c.reason, 'Raining now - roads are slippery');
    });

    test('thunderstorms ahead mean avoid', () {
      final w = weatherFrom(t0, overrides: {1: (t) => hourAt(t, code: 95)});
      expect(call(w).verdict, Verdict.avoid);
      expect(call(w).reason, 'Thunderstorms in 1 h - stay off the road');
    });

    test('the worst factor decides', () {
      final w = weatherFrom(
        t0,
        current: currentWith(windKmh: 35),
        overrides: {1: (t) => hourAt(t, rainPct: 80)},
      );
      expect(call(w).verdict, Verdict.avoid);
      expect(call(w).reason, startsWith('Heavy rain'));
    });

    test('after dark riders get a lights reminder', () {
      final c = call(withCurrent(isDay: false));
      expect(c.verdict, Verdict.ok);
      expect(c.reason, contains('lights'));
      expect(call(withCurrent(isDay: false), ActivityType.driving).verdict, Verdict.great);
    });

    test('motorbikes get their own wind advice', () {
      final c = call(withCurrent(windKmh: 35), ActivityType.motorcycling);
      expect(c.verdict, Verdict.caution);
      expect(c.reason, 'Gusty wind - keep a firm grip');
    });

    test('driving is at most caution and ignores heat', () {
      const car = ActivityType.driving;
      expect(call(withCurrent(windKmh: 50), car).verdict, Verdict.caution);
      expect(call(withCurrent(windKmh: 35), car).verdict, Verdict.great);
      expect(call(withRain(90), car).verdict, Verdict.caution);
      expect(call(withRain(60), car).verdict, Verdict.ok);
      expect(call(withCurrent(tempC: 40), car).verdict, Verdict.great);
    });
  });

  group('bestHourToRide', () {
    test('picks the calmest dry daylight hour', () {
      final w = weatherFrom(
        t0,
        overrides: {
          0: (t) => hourAt(t, rainPct: 60),
          1: (t) => hourAt(t, windKmh: 25),
          2: (t) => hourAt(t, windKmh: 12),
          3: (t) => hourAt(t, windKmh: 8),
          4: (t) => hourAt(t, windKmh: 8, tempC: 33),
          5: (t) => hourAt(t, windKmh: 8),
        },
        count: 6,
      );
      final best = bestHourToRide(ActivityType.cycling, w, now: now)!;
      expect(best.hour.time, t0.add(const Duration(hours: 3)));
      expect(best.call.verdict, Verdict.great);
      expect(best.isNow, isFalse);
      expect(bestTimeHint(ActivityType.cycling, w, best), 'Best time to ride: 11 AM');
    });

    test('the current hour can be best, and ties go to the earliest', () {
      final w = weatherFrom(t0, count: 12);
      final best = bestHourToRide(ActivityType.driving, w, now: now)!;
      expect(best.isNow, isTrue);
      expect(bestTimeHint(ActivityType.driving, w, best), 'Best time to drive: now');
    });

    test('night hours lose to daylight for riders', () {
      final w = weatherFrom(
        t0,
        overrides: {
          0: (t) => hourAt(t, isDay: false),
          1: (t) => hourAt(t, rainPct: 20, isDay: true),
        },
        count: 2,
      );
      expect(bestHourToRide(ActivityType.cycling, w, now: now)!.hour.time, w.hourly[1].time);
    });

    test('looks only 12 hours ahead and skips past hours', () {
      final w = weatherFrom(
        t0,
        overrides: {
          for (var i = 0; i < 24; i++) i: (t) => hourAt(t, rainPct: 90),
          12: (t) => hourAt(t),
        },
      );
      final best = bestHourToRide(ActivityType.cycling, w, now: now)!;
      expect(best.call.verdict, Verdict.avoid);
      expect(bestTimeHint(ActivityType.cycling, w, best), 'No good time to ride in the next 12 h');
      final later = now.add(const Duration(hours: 1));
      final next = bestHourToRide(ActivityType.cycling, w, now: later)!;
      expect(next.hour.time, t0.add(const Duration(hours: 12)));
    });

    test('no forecast hours means no hint', () {
      expect(bestHourToRide(ActivityType.cycling, weatherFrom(t0, count: 0), now: now), isNull);
    });
  });
}
