import 'package:apexo/core/geo.dart';
import 'package:apexo/core/guard_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const center = GeoPoint(6.5, 124.85);
  const boundary = Boundary(lat: 6.5, lng: 124.85, radiusM: 50);
  GeoPoint north(double m) => offsetM(center, northM: m);

  group('geofence watch', () {
    test('one fix outside is jitter; two in a row is an exit', () {
      final w = GeofenceWatch(boundary);
      expect(w.addFix(north(80), 5), isNull);
      expect(w.addFix(north(10), 5), isNull);
      expect(w.addFix(north(80), 5), isNull);
      expect(w.addFix(north(90), 5), GeofenceEvent.exit);
      expect(w.tripped, isTrue);
    });

    test('accuracy widens the boundary, so a fuzzy fix is not an exit', () {
      final w = GeofenceWatch(boundary);
      expect(w.addFix(north(70), 30), isNull);
      expect(w.addFix(north(75), 30), isNull);
      expect(w.tripped, isFalse);
    });

    test('alerts once per exit and re-arms after two fixes back inside', () {
      final w = GeofenceWatch(boundary);
      w.addFix(north(80), 5);
      expect(w.addFix(north(80), 5), GeofenceEvent.exit);
      for (var i = 0; i < 5; i++) {
        expect(w.addFix(north(200.0 + i), 5), isNull, reason: 'still the same exit');
      }
      expect(w.addFix(north(10), 5), isNull, reason: 'one fix inside is not enough');
      expect(w.addFix(north(70), 5), isNull);
      w.addFix(north(10), 5);
      expect(w.addFix(north(5), 5), GeofenceEvent.reentry);
      w.addFix(north(80), 5);
      expect(w.addFix(north(80), 5), GeofenceEvent.exit);
    });
  });

  test('battery alert fires once at 15 % and re-arms after charging to 20 %', () {
    final b = BatteryWatch();
    expect(b.addLevel(40), isFalse);
    expect(b.addLevel(15), isTrue);
    expect(b.addLevel(14), isFalse);
    expect(b.addLevel(18), isFalse);
    expect(b.addLevel(15), isFalse, reason: 'not charged past 20 % yet');
    expect(b.addLevel(21), isFalse);
    expect(b.addLevel(12), isTrue);
  });

  group('nudge detector', () {
    final t0 = DateTime(2026, 11, 4, 22);
    DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

    test('a single bump is ignored; three jolts within 2 s count', () {
      final d = NudgeDetector(NudgeSensitivity.medium);
      expect(d.add(2, 0, 0, at(0)), isFalse);
      expect(d.add(0, 0, 0.4, at(200)), isFalse, reason: 'below threshold');
      expect(d.add(0, 2, 0, at(3000)), isFalse, reason: 'first jolt left the window');
      expect(d.add(0, 0, 2, at(3500)), isFalse);
      expect(d.add(1.5, 1, 0, at(4000)), isTrue);
    });

    test('quiet for 5 minutes after an alert', () {
      final d = NudgeDetector(NudgeSensitivity.high);
      for (var i = 0; i < 3; i++) {
        d.add(1, 0, 0, at(i * 100));
      }
      for (var i = 0; i < 3; i++) {
        expect(d.add(1, 0, 0, at(60000 + i * 100)), isFalse);
      }
      final later = 6 * 60000;
      d.add(1, 0, 0, at(later));
      d.add(1, 0, 0, at(later + 100));
      expect(d.add(1, 0, 0, at(later + 200)), isTrue);
    });

    test('low sensitivity needs harder jolts', () {
      final d = NudgeDetector(NudgeSensitivity.low);
      for (var i = 0; i < 5; i++) {
        expect(d.add(2, 0, 0, at(i * 100)), isFalse);
      }
    });
  });
}
