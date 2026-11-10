import 'package:flutter/material.dart';

import '../../core/activity_type.dart';
import '../../core/ride_tracker.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../widgets/stat_value.dart';

/// Moving time, distance, speed and average (pace for runs). [oneRow] puts
/// all four in a slim strip so the live map can take nearly the whole
/// screen; otherwise a 2x2 with time and distance large. [dark] is the
/// recording cockpit: a stealth charcoal panel with white figures.
class RecordStats extends StatelessWidget {
  const RecordStats({
    super.key,
    required this.units,
    required this.type,
    required this.movingTime,
    required this.distanceM,
    required this.speedKmh,
    required this.avgKmh,
    this.dark = false,
    this.oneRow = false,
  });

  final Units units;
  final ActivityType type;
  final Duration movingTime;
  final double distanceM;
  final double speedKmh;
  final double avgKmh;
  final bool dark;
  final bool oneRow;

  @override
  Widget build(BuildContext context) {
    final pace = type.usesPace;
    Widget cell(String label, String value, String? unit, {bool big = false, Color? color}) {
      final stat = StatValue(
        label: label,
        value: value,
        unit: unit,
        size: big && !oneRow ? StatSize.large : StatSize.medium,
        align: CrossAxisAlignment.center,
        onDark: dark,
        valueColor: color,
      );
      // In the strip a long figure shrinks a little instead of being cut.
      return Expanded(
        child: oneRow ? FittedBox(fit: BoxFit.scaleDown, child: stat) : stat,
      );
    }

    final time = cell('Moving time', formatDuration(movingTime.inSeconds), null, big: true);
    // Live distance is the headline number: volt on dark.
    final distance = cell(
      'Distance',
      formatDistance(distanceM, units),
      units.distanceLabel,
      big: true,
      color: dark ? AppColors.tracking : null,
    );
    final speeds = pace
        ? [
            cell('Pace', formatPace(speedKmh, units), units.paceLabel),
            cell('Avg pace', formatPace(avgKmh, units), units.paceLabel),
          ]
        : [
            cell('Speed', formatSpeed(speedKmh, units), units.speedLabel),
            cell('Avg speed', formatSpeed(avgKmh, units), units.speedLabel),
          ];
    return Card(
      color: dark ? AppColors.darkRaised : null,
      shape: dark ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)) : null,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: Space.s, vertical: oneRow ? 12 : Space.m),
        child: oneRow
            ? Row(children: [time, distance, ...speeds])
            : Column(
                children: [
                  Row(children: [time, distance]),
                  const SizedBox(height: Space.m),
                  Row(children: speeds),
                ],
              ),
      ),
    );
  }
}

/// "Recording", "Paused", "Stopped · still recording" or "GPS ready" with a colored dot.
/// Solid, so it stays readable over the map.
class RecordStatusPill extends StatelessWidget {
  const RecordStatusPill({
    super.key,
    required this.state,
    required this.simulated,
    this.waiting = false,
  });

  final RideState state;
  final bool simulated;

  /// Recording, but no real movement yet: nothing is counted.
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      _ when waiting => ('GPS ready · start moving', AppColors.onDarkMuted),
      RideState.recording => ('Recording', AppColors.tracking),
      // Still recording: only the moving-time clock waits until you move.
      RideState.autoPaused => ('Stopped · still recording', AppColors.caution),
      _ => ('Paused', AppColors.onDarkMuted),
    };
    final t = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: AnimatedContainer(
        duration: kMotion,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Color.alphaBlend(color.withValues(alpha: 0.18), AppColors.darkRaised),
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
            Flexible(
              child: Text(
                simulated ? '$label · simulated GPS' : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.labelLarge?.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
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
