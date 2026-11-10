import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/geo.dart';
import '../../core/theme.dart';
import '../../core/time_format.dart';
import '../../core/units.dart';
import '../../data/models/user.dart';
import '../../data/repository.dart';
import '../../widgets/map_view.dart';
import '../alerts/alert_dialog.dart';
import '../me/settings_controller.dart';
import 'guard_controller.dart';

/// The boundary on a map, with where the vehicle is now.
class GuardMap extends StatelessWidget {
  const GuardMap({super.key, required this.boundary, this.position, this.alert = false});

  final Boundary boundary;
  final GeoPoint? position;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final p = position;
    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadius),
      child: SizedBox(
        height: 240,
        child: RepaintBoundary(
          child: MapView(
            initialCenter: boundary.center,
            initialZoom: boundary.radiusM > 150 ? 15 : 17,
            fitPoints: p == null ? const [] : [boundary.center, p],
            circles: [
              MapCircle(
                center: boundary.center,
                radiusM: boundary.radiusM,
                color: alert ? AppColors.alert : AppColors.data,
              ),
            ],
            markers: [
              if (p != null)
                MapMarker(
                  id: 'vehicle',
                  point: p,
                  size: 28,
                  child: alert ? const AlertPin() : const _Dot(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.mapInk,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
    ),
  );
}

/// Dark status panel while this phone watches the vehicle.
class ArmedPanel extends StatelessWidget {
  const ArmedPanel({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final guard = context.watch<GuardController>();
    final t = Theme.of(context).textTheme;
    final b = guard.boundary;
    final since = vehicle.armedAt;
    final d = guard.distanceM;
    final units = context.select<SettingsController, Units>((s) => s.units);
    final demo = context.read<AppRepository>().isDemo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(Space.m),
          decoration: BoxDecoration(
            color: AppColors.dark,
            borderRadius: BorderRadius.circular(kRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.tracking,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  Text('Guard mode on', style: t.titleMedium?.copyWith(color: Colors.white)),
                ],
              ),
              const SizedBox(height: Space.xs),
              Text(
                [
                  'Watching ${vehicle.name}',
                  if (since != null) 'since ${formatClock(since)}',
                  if (b != null) 'alert beyond ${distanceText(b.radiusM, units)}',
                ].join(' · '),
                style: t.bodyMedium?.copyWith(color: AppColors.onDarkMuted),
              ),
              const SizedBox(height: Space.m),
              Text(
                d == null ? '—' : distanceText(d, units),
                style: t.displaySmall?.copyWith(color: Colors.white, fontFeatures: kTabular),
              ),
              Text(
                'from where you armed it',
                style: t.bodySmall?.copyWith(color: AppColors.onDarkMuted),
              ),
            ],
          ),
        ),
        if (b != null) ...[
          const SizedBox(height: Space.m),
          GuardMap(boundary: b, position: guard.lastPosition),
        ],
        const SizedBox(height: Space.m),
        OutlinedButton(onPressed: guard.disarm, child: const Text('Disarm')),
        if (demo)
          TextButton(onPressed: guard.testAlarm, child: const Text('Test the alarm (demo)')),
      ],
    );
  }
}

/// The vehicle left its boundary.
class StolenPanel extends StatelessWidget {
  const StolenPanel({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final guard = context.watch<GuardController>();
    final t = Theme.of(context).textTheme;
    final b = guard.boundary;
    final d = guard.distanceM;
    final units = context.select<SettingsController, Units>((s) => s.units);
    final at = guard.lastPosition;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(Space.m),
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(color: AppColors.alert.withValues(alpha: 0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.wrong_location_outlined, color: AppColors.alert, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${vehicle.name} left its boundary', style: t.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (d != null) '${distanceText(d, units)} from the spot',
                        if (b != null) 'limit ${distanceText(b.radiusM, units)}',
                        'your circles were alerted',
                      ].join(' · '),
                      style: t.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (b != null) ...[
          const SizedBox(height: Space.m),
          GuardMap(boundary: b, position: at, alert: true),
        ],
        const SizedBox(height: Space.m),
        FilledButton(onPressed: guard.markRecovered, child: const Text('Mark recovered')),
        if (at != null)
          TextButton(onPressed: () => navigateTo(at.lat, at.lng), child: const Text('Navigate')),
      ],
    );
  }
}

/// Armed in the backend, but this phone is not watching.
class ElsewherePanel extends StatelessWidget {
  const ElsewherePanel({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final guard = context.read<GuardController>();
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Guard mode is on for ${vehicle.name}', style: t.titleMedium),
            const SizedBox(height: Space.xs),
            Text(
              'This phone is not watching it. It was armed on another phone, or Apexo '
              'was closed since.',
              style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: Space.m),
            FilledButton(onPressed: guard.resume, child: const Text('Watch from this phone')),
            const SizedBox(height: Space.xs),
            TextButton(onPressed: guard.disarm, child: const Text('Disarm')),
          ],
        ),
      ),
    );
  }
}
