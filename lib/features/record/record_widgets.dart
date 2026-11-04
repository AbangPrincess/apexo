import 'package:flutter/material.dart';

import '../../core/ride_tracker.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../widgets/stat_value.dart';

/// Time on top, then distance, speed and average speed. [dark] is the
/// recording cockpit: a stealth charcoal panel with white figures.
class RecordStats extends StatelessWidget {
  const RecordStats({
    super.key,
    required this.units,
    required this.movingTime,
    required this.distanceM,
    required this.speedKmh,
    required this.avgKmh,
    this.dark = false,
  });

  final Units units;
  final Duration movingTime;
  final double distanceM;
  final double speedKmh;
  final double avgKmh;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: dark ? AppColors.darkRaised : null,
      shape: dark ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)) : null,
      child: Padding(
        padding: const EdgeInsets.all(Space.l),
        child: Column(
          children: [
            StatValue(
              label: 'Moving time',
              value: formatDuration(movingTime.inSeconds),
              size: StatSize.large,
              align: CrossAxisAlignment.center,
              onDark: dark,
            ),
            const SizedBox(height: Space.l),
            Divider(color: dark ? AppColors.darkLine : null),
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
                      onDark: dark,
                      // Live distance is the headline number: volt on dark.
                      valueColor: dark && label == 'Distance' ? AppColors.tracking : null,
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

/// "Recording", "Paused" or "Auto-paused" with a colored dot, on the dark
/// cockpit background.
class RecordStatusPill extends StatelessWidget {
  const RecordStatusPill({super.key, required this.state, required this.simulated});

  final RideState state;
  final bool simulated;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      RideState.recording => ('Recording', AppColors.tracking),
      RideState.autoPaused => ('Auto-paused · start moving to resume', AppColors.caution),
      _ => ('Paused', AppColors.onDarkMuted),
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
              color: color.withValues(alpha: 0.16),
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
                Text(label, style: t.labelLarge?.copyWith(color: Colors.white)),
              ],
            ),
          ),
          if (simulated)
            Text('Simulated GPS', style: t.labelMedium?.copyWith(color: AppColors.onDarkMuted)),
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
    this.foreground,
    this.border,
    this.size = 104,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;

  /// Defaults to ink or white, whichever reads better on [color].
  final Color? foreground;
  final Color? border;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fill = onPressed == null ? AppColors.parked : color;
    final fg = foreground ?? AppColors.on(fill);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: fill,
        shape: CircleBorder(
          side: border == null ? BorderSide.none : BorderSide(color: border!, width: 2),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            // Large system text shrinks to fit the circle instead of spilling out.
            child: Padding(
              padding: EdgeInsets.all(size * 0.14),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) Icon(icon, color: fg, size: size * 0.28),
                    Text(
                      label,
                      style: TextStyle(
                        color: fg,
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
        ),
      ),
    );
  }
}
