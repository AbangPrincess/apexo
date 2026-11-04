import 'dart:async';

import 'package:clock/clock.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/guard_logic.dart';

/// One accelerometer reading without gravity, in m/s².
typedef MotionSample = ({double x, double y, double z, DateTime t});

/// Linear acceleration for nudge detection; tests pass a fake.
abstract interface class MotionSource {
  Stream<MotionSample> samples();
}

class DeviceMotionSource implements MotionSource {
  /// 5 readings a second is enough to catch a lift or push and saves power.
  @override
  Stream<MotionSample> samples() => userAccelerometerEventStream(
    samplingPeriod: SensorInterval.normalInterval,
  ).map((e) => (x: e.x, y: e.y, z: e.z, t: clock.now()));
}

/// Listens for nudges while guarding and calls back on each detection.
class NudgeWatch {
  NudgeWatch(this._source);

  final MotionSource _source;
  StreamSubscription<MotionSample>? _sub;

  void start(NudgeSensitivity sensitivity, void Function() onNudge) {
    stop();
    final detector = NudgeDetector(sensitivity);
    _sub = _source.samples().listen((s) {
      if (detector.add(s.x, s.y, s.z, s.t)) onNudge();
    }, onError: (Object _) {});
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
