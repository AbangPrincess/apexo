import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pedaltrack/core/achievements.dart';
import 'package:pedaltrack/core/activity_summary.dart';
import 'package:pedaltrack/core/activity_type.dart';
import 'package:pedaltrack/core/image_check.dart';
import 'package:pedaltrack/core/login_throttle.dart';
import 'package:pedaltrack/core/validators.dart';
import 'package:pedaltrack/core/weather_code.dart';

class _A implements ActivityFacts {
  _A(this.type, this.startedAt, this.distanceM);
  @override
  final ActivityType type;
  @override
  final DateTime startedAt;
  @override
  final double distanceM;
  @override
  int get movingSec => 600;
}

void main() {
  final now = DateTime(2026, 11, 4, 15); // Wednesday
  final list = [
    _A(ActivityType.cycling, DateTime(2026, 11, 2, 6), 12000), // Mon
    _A(ActivityType.driving, DateTime(2026, 11, 4, 9), 8000), // Wed
    _A(ActivityType.cycling, DateTime(2026, 11, 1, 5, 30), 30000), // last Sun
    _A(ActivityType.motorcycling, DateTime(2026, 10, 20, 18), 5000),
  ];

  test('week totals, daily distances and per-type totals', () {
    expect(startOfWeek(now), DateTime(2026, 11, 2));
    final week = weekTotals(list, now);
    expect(week.count, 2);
    expect(week.distanceM, 20000);
    expect(dailyDistanceThisWeek(list, now), [12000, 0, 8000, 0, 0, 0, 0]);
    final byType = totalsByType(list);
    expect(byType.keys, ActivityType.values);
    expect(byType[ActivityType.cycling]!.distanceM, 42000);
    expect(byType[ActivityType.motorcycling]!.count, 1);
  });

  test('auto titles follow the time of day', () {
    expect(autoTitle(ActivityType.cycling, DateTime(2026, 1, 1, 6)), 'Morning Ride');
    expect(autoTitle(ActivityType.driving, DateTime(2026, 1, 1, 12)), 'Lunch Drive');
    expect(autoTitle(ActivityType.motorcycling, DateTime(2026, 1, 1, 19)), 'Evening Moto ride');
    expect(autoTitle(ActivityType.cycling, DateTime(2026, 1, 1, 23)), 'Night Ride');
  });

  test('achievements track distance milestones and more', () {
    final a = {for (final x in computeAchievements(list)) x.id: x};
    expect(a['total-10k']!.earned, isTrue);
    expect(a['total-50k']!.earned, isTrue); // 55 km total
    expect(a['total-100k']!.progress, closeTo(0.55, 0.001));
    expect(a['long-20k']!.earned, isTrue);
    expect(a['long-50k']!.earned, isFalse);
    expect(a['count-1']!.earned, isTrue);
    expect(a['early-1']!.earned, isTrue);
    expect(computeAchievements(const []).where((x) => x.earned), isEmpty);
    expect(computeAchievements(list).first.isDistance, isTrue);
  });

  test('week streaks', () {
    expect(longestWeekStreak([]), 0);
    expect(
      longestWeekStreak([
        DateTime(2026, 10, 6),
        DateTime(2026, 10, 14),
        DateTime(2026, 10, 15),
        DateTime(2026, 10, 21),
        DateTime(2026, 11, 10),
      ]),
      3,
    );
  });

  test('login throttle locks after 5 failures and doubles the lock', () {
    var clock = DateTime(2026, 1, 1);
    final t = LoginThrottle(clock: () => clock);
    for (var i = 0; i < 4; i++) {
      expect(t.recordFailure('a@b.co'), isNull);
    }
    expect(t.attemptsLeft('a@b.co'), 1);
    expect(t.recordFailure('a@b.co'), const Duration(seconds: 30));
    expect(t.lockRemaining('a@b.co'), const Duration(seconds: 30));
    expect(t.lockRemaining('other@b.co'), isNull);
    clock = clock.add(const Duration(seconds: 31));
    expect(t.lockRemaining('a@b.co'), isNull);
    for (var i = 0; i < 4; i++) {
      t.recordFailure('a@b.co');
    }
    expect(t.recordFailure('a@b.co'), const Duration(minutes: 1));
    t.recordSuccess('a@b.co');
    expect(t.lockRemaining('a@b.co'), isNull);
    expect(formatWait(const Duration(seconds: 90)), '1 min 30 s');
    expect(formatWait(const Duration(milliseconds: 29100)), '30 s');
  });

  test('image checks sniff real formats and enforce size', () {
    final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
    final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    final svg = Uint8List.fromList('<svg onload="x">'.codeUnits);
    expect(sniffImage(jpeg), ImageKind.jpeg);
    expect(sniffImage(png), ImageKind.png);
    expect(imageProblem(svg, maxBytes: 1000), isNotNull);
    expect(imageProblem(jpeg, maxBytes: 4), isNotNull);
    expect(imageProblem(jpeg, maxBytes: 1000), isNull);
    final uri = toDataUri(jpeg);
    expect(uri, startsWith('data:image/jpeg;base64,'));
    expect(bytesFromDataUri(uri), jpeg);
    expect(bytesFromDataUri('https://example.com/a.jpg'), isNull);
  });

  _gpsTests();

  test('password rules and profile limits', () {
    expect(validatePassword('longenough'), isNotNull);
    expect(validatePassword('longenough1'), isNull);
    expect(passwordChecks('abc1').map((c) => c.$2), [false, true, true]);
    expect(validateBio('x' * 161), isNotNull);
    expect(validateHometown('Koronadal City'), isNull);
    expect(weatherLabel(61), 'Rain');
    expect(weatherLabel(0), 'Clear');
  });
}

/// Minimal JPEG: SOI, APP1 Exif with one GPS latitude tag, SOS, EOI.
Uint8List _jpegWithGps() {
  final tiff = <int>[
    0x49, 0x49, 0x2A, 0x00, 8, 0, 0, 0, // little endian, IFD0 at 8
    1, 0, 0x25, 0x88, 4, 0, 1, 0, 0, 0, 26, 0, 0, 0, 0, 0, 0, 0, // GPS IFD at 26
    1, 0, 2, 0, 5, 0, 3, 0, 0, 0, 44, 0, 0, 0, 0, 0, 0, 0, // GPSLatitude -> 44
    6, 0, 0, 0, 1, 0, 0, 0, 30, 0, 0, 0, 1, 0, 0, 0, 15, 0, 0, 0, 1, 0, 0, 0,
  ];
  final app1 = [...'Exif'.codeUnits, 0, 0, ...tiff];
  final len = app1.length + 2;
  return Uint8List.fromList([
    0xFF,
    0xD8,
    0xFF,
    0xE1,
    len >> 8,
    len & 0xFF,
    ...app1,
    0xFF,
    0xDA,
    0,
    2,
    0xFF,
    0xD9,
  ]);
}

void _gpsTests() {
  test('location tags are removed from JPEG photos', () {
    final input = _jpegWithGps();
    final out = removeJpegLocation(input);
    const tiff = 12; // SOI(2) + marker(2) + length(2) + "Exif\0\0"(6)
    expect(input[tiff + 26], 1); // one GPS entry before
    expect(out[tiff + 26], 0); // none after
    expect(out.sublist(tiff + 44, tiff + 68).every((b) => b == 0), isTrue);
    expect(out[tiff + 10], 0x25); // GPS pointer tag itself still there
    expect(out.length, input.length);
    final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    expect(identical(removeJpegLocation(png), png), isTrue);
  });
}
