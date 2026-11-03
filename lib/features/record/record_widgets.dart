import 'package:flutter/material.dart';

import '../../core/ride_tracker.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../widgets/stat_value.dart';

/// Time on top, then distance, speed and average speed.
class RecordStats extends StatelessWidget {
  const RecordStats({
    super.key,
    required this.units,
    required this.movingTime,
    required this.distanceM,
    required this.speedKmh,
    required this.avgKmh,
  });

  final Units units;
  final Duration movingTime;
  final double distanceM;
  final double speedKmh;
  final double avgKmh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.l),
        child: Column(
          children: [
            StatValue(
              label: 'Moving time',
              value: formatDuration(movingTime.inSeconds),
              size: StatSize.large,
              align: CrossAxisAlignment.center,
            ),
            const SizedBox(height: Space.l),
            const Divider(),
            const SizedBox(height: Space.m),
            Row(
              children: [
                for (final (label, value, unit) in [
                  ('Distance', formatDistance(distanceM, units), units.distanceLabel),
                  ('Speed', formatSpeed(speedKmh, units), units.speedLabel),
                  ('Avg speed', formatSpeed(avgKmh, units), units.speedLabel),
                ])
                  Expanded(
                    child: StatValue(
                      label: label,
                      value: value,
                      unit: unit,
                      align: CrossAxisAlignment.center,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Recording", "Paused" or "Auto-paused" with a colored dot.
class RecordStatusPill extends StatelessWidget {
  const RecordStatusPill({super.key, required this.state, required this.simulated});

  final RideState state;
  final bool simulated;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      RideState.recording => ('Recording', AppColors.tracking),
      RideState.autoPaused => ('Auto-paused · start moving to resume', AppColors.caution),
      _ => ('Paused', AppColors.parked),
    };
    final t = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Space.s,
        runSpacing: Space.xs,
        children: [
          AnimatedContainer(
            duration: kMotion,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(label, style: t.labelLarge?.copyWith(color: AppColors.text)),
              ],
            ),
          ),
          if (simulated)
            Text('Simulated GPS', style: t.labelMedium?.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

/// Big round control (START, PAUSE, RESUME, FINISH).
class RoundAction extends StatelessWidget {
  const RoundAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppColors.accent,
    this.size = 104,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: onPressed == null ? AppColors.parked : color,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) Icon(icon, color: Colors.white, size: size * 0.28),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * (icon == null ? 0.17 : 0.13),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
