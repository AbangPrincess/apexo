import 'dart:math';

import 'package:apexo/core/geo.dart';
import 'package:apexo/core/invite_code.dart';
import 'package:apexo/core/share_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('invite codes', () {
    test('6 characters from the alphabet, never look-alikes', () {
      final r = Random(7);
      for (var i = 0; i < 500; i++) {
        final code = generateInviteCode(r);
        expect(code, hasLength(6));
        expect(isInviteCodeShape(code), isTrue);
        expect(code, isNot(matches(RegExp('[01OIL]'))));
      }
    });

    test('joining ignores case, spaces and dashes', () {
      expect(normalizeInviteCode(' trail 7 '), 'TRAIL7');
      expect(normalizeInviteCode('abc-234'), 'ABC234');
      expect(isInviteCodeShape(normalizeInviteCode('trail7')), isTrue);
      expect(isInviteCodeShape('TRAIL'), isFalse);
      expect(isInviteCodeShape('TRAIL7X'), isFalse);
      expect(isInviteCodeShape('TRA!L7'), isFalse);
    });
  });

  group('share gate (write budget)', () {
    const start = GeoPoint(6.5, 124.85);
    final t0 = DateTime(2026, 11, 3, 8);
    DateTime at(int s) => t0.add(Duration(seconds: s));

    test('first fix publishes; then 5 s and 10 m are both needed', () {
      final gate = ShareGate();
      expect(gate.shouldPublish(start, at(0)), isTrue);
      expect(gate.shouldPublish(offsetM(start, northM: 30), at(3)), isFalse, reason: '< 5 s');
      expect(gate.shouldPublish(offsetM(start, northM: 6), at(8)), isFalse, reason: '< 10 m');
      expect(gate.shouldPublish(offsetM(start, northM: 12), at(9)), isTrue);
    });

    test('stationary heartbeat every 60 s', () {
      final gate = ShareGate();
      expect(gate.shouldPublish(start, at(0)), isTrue);
      expect(gate.shouldPublish(start, at(30)), isFalse);
      expect(gate.shouldPublish(start, at(59)), isFalse);
      expect(gate.shouldPublish(start, at(60)), isTrue);
    });

    test('a status change skips the distance check, not the 5 s floor', () {
      final gate = ShareGate();
      gate.shouldPublish(start, at(0));
      expect(gate.shouldPublish(start, at(2), changed: true), isFalse);
      expect(gate.shouldPublish(start, at(5), changed: true), isTrue);
    });

    test('moving at speed stays within one write per 5 s', () {
      final gate = ShareGate();
      var writes = 0;
      // 10 m/s for 10 minutes, one fix per second.
      for (var s = 0; s < 600; s++) {
        if (gate.shouldPublish(offsetM(start, northM: s * 10.0), at(s))) writes++;
      }
      expect(writes, 120);
    });

    test('reset publishes the next fix at once', () {
      final gate = ShareGate()..shouldPublish(start, at(0));
      gate.reset();
      expect(gate.shouldPublish(start, at(1)), isTrue);
    });
  });
}
