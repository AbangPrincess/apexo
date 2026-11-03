import 'package:clock/clock.dart';

import 'activity_type.dart';
import 'time_format.dart';
import 'weather.dart';
import 'weather_code.dart';

/// Ride call, from best to worst.
enum Verdict {
  great('Great'),
  ok('OK'),
  caution('Caution'),
  avoid('Avoid');

  const Verdict(this.label);
  final String label;
}

class RideCall {
  const RideCall(this.verdict, this.reason);

  final Verdict verdict;

  /// Plain language, e.g. "Strong wind - expect a tough push".
  final String reason;

  @override
  String toString() => '${verdict.label}: $reason';
}

// SPEC P3 thresholds.
const windCautionKmh = 30.0;
const windAvoidKmh = 45.0;
const rainCautionPct = 50;
const rainAvoidPct = 75;
const coldC = 5.0;
const hotC = 36.0;

// Below these everything is "Great".
const _breezyKmh = 15.0;
const _rainChancePct = 20;
const _coolC = 12.0;
const _warmC = 32.0;

/// Hours of forecast the "right now" call looks ahead for rain and storms.
const lookAheadHours = 3;

/// The call for heading out now: current temperature and wind, plus rain and
/// storms over the next [lookAheadHours] hours.
RideCall rideVerdict(ActivityType type, Weather weather, {DateTime? now}) {
  final c = weather.current;
  final hours = weather.upcoming(now ?? clock.now(), lookAheadHours);
  final rainAt = hours.indexWhere((h) => h.rainPct > rainCautionPct);
  final stormAt = isStormCode(c.code) ? 0 : hours.indexWhere((h) => isStormCode(h.code));
  return _judge(
    type,
    tempC: c.tempC,
    windKmh: c.windKmh,
    rainPct: hours.fold(0, (m, h) => h.rainPct > m ? h.rainPct : m),
    rainInH: rainAt < 0 ? 0 : rainAt,
    rainingNow: c.precipMm >= 0.5 || isRainCode(c.code),
    stormInH: stormAt < 0 ? null : stormAt,
    isDay: c.isDay,
  );
}

/// The call for one forecast hour.
RideCall hourVerdict(ActivityType type, HourForecast h) => _judge(
  type,
  tempC: h.tempC,
  windKmh: h.windKmh,
  rainPct: h.rainPct,
  rainInH: 0,
  rainingNow: isRainCode(h.code),
  stormInH: isStormCode(h.code) ? 0 : null,
  isDay: h.isDay,
);

RideCall _judge(
  ActivityType type, {
  required double tempC,
  required double windKmh,
  required int rainPct,
  required int rainInH,
  required bool rainingNow,
  required int? stormInH,
  required bool isDay,
}) {
  final car = type == ActivityType.driving;
  final calls = <RideCall?>[
    if (stormInH != null)
      RideCall(
        car ? Verdict.caution : Verdict.avoid,
        car
            ? 'Thunderstorms ${_when(stormInH)} - drive with care'
            : 'Thunderstorms ${_when(stormInH)} - stay off the road',
      ),
    _rain(car, rainPct, rainInH, rainingNow),
    _wind(type, windKmh),
    _temperature(type, tempC),
    if (!isDay && !car) const RideCall(Verdict.ok, 'After dark - use front and rear lights'),
  ];
  RideCall? worst;
  for (final call in calls.nonNulls) {
    if (worst == null || call.verdict.index > worst.verdict.index) worst = call;
  }
  return worst ??
      RideCall(Verdict.great, car ? 'Clear, calm conditions' : 'Dry and calm - enjoy the ride');
}

String _when(int inH) => inH == 0 ? 'within the hour' : 'in $inH h';

RideCall? _rain(bool car, int pct, int inH, bool now) {
  if (pct > rainAvoidPct) {
    return car
        ? RideCall(Verdict.caution, 'Heavy rain likely ${_when(inH)} - allow extra time')
        : RideCall(Verdict.avoid, 'Heavy rain likely ${_when(inH)}');
  }
  if (now) {
    return car
        ? const RideCall(Verdict.ok, 'Wet roads - leave more distance')
        : const RideCall(Verdict.caution, 'Raining now - roads are slippery');
  }
  if (pct > rainCautionPct) {
    return RideCall(car ? Verdict.ok : Verdict.caution, 'Rain likely ${_when(inH)}');
  }
  if (pct > _rainChancePct) return RideCall(Verdict.ok, 'Some chance of rain ($pct%)');
  return null;
}

RideCall? _wind(ActivityType type, double kmh) => switch (type) {
  ActivityType.driving when kmh > windAvoidKmh => const RideCall(
    Verdict.caution,
    'Very strong wind - watch for debris',
  ),
  ActivityType.driving => null,
  _ when kmh > windAvoidKmh => const RideCall(Verdict.avoid, 'Very strong wind - risky to ride'),
  ActivityType.cycling when kmh > windCautionKmh => const RideCall(
    Verdict.caution,
    'Strong wind - expect a tough push',
  ),
  _ when kmh > windCautionKmh => const RideCall(Verdict.caution, 'Gusty wind - keep a firm grip'),
  _ when kmh > _breezyKmh => const RideCall(Verdict.ok, 'Breezy - some headwind'),
  _ => null,
};

RideCall? _temperature(ActivityType type, double c) {
  if (type == ActivityType.driving) {
    return c < 1 ? const RideCall(Verdict.caution, 'Near freezing - roads may be icy') : null;
  }
  if (c < coldC) return const RideCall(Verdict.caution, 'Very cold - dress warm, watch for ice');
  if (c > hotC) return const RideCall(Verdict.caution, 'Very hot - carry extra water, take breaks');
  if (c < _coolC) return const RideCall(Verdict.ok, 'Cool - bring a layer');
  if (c > _warmC) return const RideCall(Verdict.ok, 'Hot - bring water');
  return null;
}

class BestHour {
  const BestHour(this.hour, this.call, {required this.isNow});

  final HourForecast hour;
  final RideCall call;
  final bool isNow;
}

/// Best hour in the next [within] hours: the best verdict first, then the
/// lowest discomfort score, then the earliest.
BestHour? bestHourToRide(ActivityType type, Weather weather, {DateTime? now, int within = 12}) {
  final hours = weather.upcoming(now ?? clock.now(), within);
  if (hours.isEmpty) return null;
  final car = type == ActivityType.driving;
  int score(HourForecast h) {
    final heat = h.tempC < 15 ? 15 - h.tempC : (h.tempC > 28 ? h.tempC - 28 : 0.0);
    final wind = h.windKmh > 10 ? h.windKmh - 10 : 0.0;
    return h.rainPct + (wind * 2 + heat * 3).round() + (h.isDay || car ? 0 : 40);
  }

  var best = 0;
  var bestCall = hourVerdict(type, hours.first);
  var bestScore = score(hours.first);
  for (var i = 1; i < hours.length; i++) {
    final call = hourVerdict(type, hours[i]);
    final s = score(hours[i]);
    final better =
        call.verdict.index < bestCall.verdict.index ||
        (call.verdict == bestCall.verdict && s < bestScore);
    if (better) (best, bestCall, bestScore) = (i, call, s);
  }
  return BestHour(hours[best], bestCall, isNow: best == 0);
}

/// "Best time to ride: 6 AM", "Best time to ride: now" or no window at all.
String bestTimeHint(ActivityType type, Weather weather, BestHour best, {int within = 12}) {
  final verb = type == ActivityType.driving ? 'drive' : 'ride';
  if (best.call.verdict == Verdict.avoid) return 'No good time to $verb in the next $within h';
  if (best.isNow) return 'Best time to $verb: now';
  return 'Best time to $verb: ${formatHour(weather.localTime(best.hour.time))}';
}
