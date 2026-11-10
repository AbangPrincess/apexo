import 'package:flutter_test/flutter_test.dart';
import 'package:apexo/core/time_format.dart';
import 'package:apexo/core/units.dart';
import 'package:apexo/core/validators.dart';

void main() {
  group('units', () {
    test('km and mi conversion', () {
      expect(kmToMi(1.609344), closeTo(1, 1e-9));
      expect(miToKm(1), closeTo(1.609344, 1e-9));
      expect(kmToMi(miToKm(26.2)), closeTo(26.2, 1e-9));
      expect(mpsToKmh(10), closeTo(36, 1e-9));
      expect(kmhToMps(36), closeTo(10, 1e-9));
    });

    test('distance and speed formatting', () {
      expect(formatDistance(12340, Units.km), '12.34');
      expect(formatDistance(1609.344, Units.mi), '1.00');
      expect(formatDistance(123400, Units.km), '123.4');
      expect(formatSpeed(16.09344, Units.mi), '10.0');
      expect(Units.mi.distanceLabel, 'mi');
      expect(Units.km.speedLabel, 'km/h');
    });

    test('duration formatting', () {
      expect(formatDuration(3909), '1:05:09');
      expect(formatDuration(59), '0:59');
      expect(formatDuration(-5), '0:00');
      expect(formatDurationShort(3900), '1h 05m');
      expect(formatDurationShort(2520), '42m');
      expect(formatDurationShort(35), '35s');
    });
  });

  group('time formatting', () {
    final now = DateTime(2026, 11, 3, 15, 30);

    test('relative dates', () {
      expect(formatRelativeDate(DateTime(2026, 11, 3, 6, 5), now), 'Today at 6:05 AM');
      expect(formatRelativeDate(DateTime(2026, 11, 2, 18, 0), now), 'Yesterday at 6:00 PM');
      expect(formatRelativeDate(DateTime(2026, 10, 31, 12, 0), now), 'Sat at 12:00 PM');
      expect(formatRelativeDate(DateTime(2026, 10, 20), now), 'Oct 20');
      expect(formatRelativeDate(DateTime(2025, 10, 20), now), 'Oct 20, 2025');
    });

    test('ago and greeting', () {
      expect(formatAgo(now.subtract(const Duration(seconds: 3)), now), 'just now');
      expect(formatAgo(now.subtract(const Duration(minutes: 5)), now), '5 min ago');
      expect(formatAgo(now.subtract(const Duration(hours: 3)), now), '3 h ago');
      expect(greeting(DateTime(2026, 1, 1, 7)), 'Good Morning');
      expect(greeting(DateTime(2026, 1, 1, 20)), 'Good Evening');
      expect(formatPace(12, Units.km), '5:00');
      expect(formatPace(9.656064, Units.mi), '10:00'); // 6 mph
      expect(formatPace(1, Units.km), '-:--', reason: 'slower than walking means nothing');
      expect(formatLongDate(now), 'Tuesday, November 3');
    });
  });

  group('validators', () {
    test('email', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('rider@'), isNotNull);
      expect(validateEmail(' rider@example.com '), isNull);
    });

    test('password and name', () {
      expect(validatePassword('short'), isNotNull);
      expect(validatePassword('longenough1'), isNull);
      expect(validateDisplayName('  '), isNotNull);
      expect(validateDisplayName('John'), isNull);
    });
  });
}
