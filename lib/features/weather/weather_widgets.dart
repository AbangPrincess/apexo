import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/ride_verdict.dart';
import '../../core/theme.dart';
import '../../core/time_format.dart';
import '../../core/weather.dart';
import '../../widgets/weather_art.dart';

Color verdictColor(Verdict v) => switch (v) {
  Verdict.great => AppColors.tracking,
  Verdict.ok => AppColors.parked,
  Verdict.caution => AppColors.caution,
  Verdict.avoid => AppColors.alert,
};

/// Solid flag-style pill: volt Great, carbon OK, orange Caution, red Avoid.
class VerdictPill extends StatelessWidget {
  const VerdictPill(this.verdict, {super.key});

  final Verdict verdict;

  @override
  Widget build(BuildContext context) {
    final color = verdictColor(verdict);
    return Semantics(
      label: 'Ride call: ${verdict.label}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
        child: Text(
          verdict.label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.on(color)),
        ),
      ),
    );
  }
}

/// The current-conditions icon: line art only, no backdrop.
class WeatherGlyph extends StatelessWidget {
  const WeatherGlyph({super.key, required this.code, this.isDay = true, this.size = 44});

  final int code;
  final bool isDay;
  final double size;

  @override
  Widget build(BuildContext context) => WeatherArt(code: code, isDay: isDay, size: size);
}

/// Arrow pointing where the wind blows to (the API gives where it comes from).
class WindArrow extends StatelessWidget {
  const WindArrow({super.key, required this.fromDeg, this.size = 14});

  final double fromDeg;
  final double size;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: (fromDeg + 180) * math.pi / 180,
    child: Icon(Icons.navigation_rounded, size: size, color: AppColors.textMuted),
  );
}

/// Next hours: time, icon, temperature and rain chance.
class HourlyStrip extends StatelessWidget {
  const HourlyStrip({super.key, required this.weather, required this.hours});

  final Weather weather;
  final List<HourForecast> hours;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = t.labelSmall?.copyWith(color: AppColors.textMuted, fontFeatures: kTabular);
    return Row(
      children: [
        for (final (i, h) in hours.indexed)
          Expanded(
            child: Semantics(
              label:
                  '${i == 0 ? 'Now' : formatHour(weather.localTime(h.time))}, '
                  '${h.tempC.round()} degrees, ${h.rainPct} percent chance of rain',
              excludeSemantics: true,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  children: [
                    Text(i == 0 ? 'Now' : formatHour(weather.localTime(h.time)), style: muted),
                    const SizedBox(height: 6),
                    WeatherArt(code: h.code, isDay: h.isDay, size: 26),
                    const SizedBox(height: 6),
                    Text(
                      '${h.tempC.round()}°',
                      style: t.labelLarge?.copyWith(fontFeatures: kTabular),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.water_drop_outlined, size: 10, color: AppColors.text),
                        const SizedBox(width: 2),
                        Text(
                          '${h.rainPct}%',
                          style: muted?.copyWith(
                            color: h.rainPct > rainCautionPct ? AppColors.text : null,
                            fontWeight: h.rainPct > rainCautionPct ? FontWeight.w700 : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
