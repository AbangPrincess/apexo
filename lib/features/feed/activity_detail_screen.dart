import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/time_format.dart';
import '../../core/units.dart';
import '../../core/weather_code.dart';
import '../../data/models/activity.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/map_view.dart';
import '../../widgets/responsive.dart';
import '../../widgets/stat_value.dart';
import '../../widgets/visuals.dart';
import '../../widgets/weather_art.dart';
import '../me/settings_controller.dart';
import 'activities_controller.dart';

/// Route on a map, the full stat grid, weather at the start, and delete.
/// Activities shared by others ([ownerName] set) are read-only.
class ActivityDetailScreen extends StatelessWidget {
  const ActivityDetailScreen({super.key, required this.activity, this.ownerName});

  final Activity activity;
  final String? ownerName;

  Future<void> _delete(BuildContext context) async {
    final ok = await confirmAction(
      context,
      title: 'Delete this activity?',
      message: 'It will be removed from your profile and feeds. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    await context.read<ActivitiesController>().delete(activity.id);
    messenger.showSnackBar(const SnackBar(content: Text('Activity deleted')));
  }

  @override
  Widget build(BuildContext context) {
    final units = context.select<SettingsController, Units>((s) => s.units);
    final points = activity.points;
    final map = points.length < 2
        ? ColoredBox(
            color: AppColors.surfaceAlt,
            child: const Center(child: Text('No route recorded')),
          )
        : MapView(
            initialCenter: points.first,
            fitPoints: points,
            polylines: [MapPolyline(points: points, color: AppColors.data)],
            markers: [
              MapMarker(
                id: 'start',
                point: points.first,
                size: 22,
                child: const _Dot(AppColors.tracking, ring: AppColors.mapInk),
              ),
              MapMarker(
                id: 'end',
                point: points.last,
                size: 22,
                child: const _Dot(AppColors.mapInk),
              ),
            ],
          );
    final details = _Details(activity: activity, units: units, ownerName: ownerName);

    return Scaffold(
      appBar: AppBar(
        title: Text(activity.title),
        actions: [
          if (ownerName == null)
            IconButton(
              tooltip: 'Delete activity',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _delete(context),
            ),
          const SizedBox(width: Space.s),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= Breakpoints.expanded) {
            return Row(
              children: [
                Expanded(child: RepaintBoundary(child: map)),
                const VerticalDivider(width: 1),
                SizedBox(width: 420, child: details),
              ],
            );
          }
          return Column(
            children: [
              Expanded(flex: 5, child: RepaintBoundary(child: map)),
              const Divider(),
              Expanded(flex: 6, child: details),
            ],
          );
        },
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.activity, required this.units, this.ownerName});

  final Activity activity;
  final Units units;
  final String? ownerName;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final t = Theme.of(context).textTheme;
    final muted = t.bodyMedium?.copyWith(color: AppColors.textMuted);
    final elapsed = a.endedAt.difference(a.startedAt).inSeconds;
    final stats = <(String, String, String?)>[
      ('Distance', formatDistance(a.distanceM, units), units.distanceLabel),
      ('Moving time', formatDuration(a.movingSec), null),
      ('Elapsed time', formatDuration(elapsed), null),
      if (a.type.usesPace) ...[
        ('Avg pace', formatPace(a.avgKmh, units), units.paceLabel),
        ('Best pace', formatPace(a.maxKmh, units), units.paceLabel),
      ] else ...[
        ('Avg speed', formatSpeed(a.avgKmh, units), units.speedLabel),
        ('Max speed', formatSpeed(a.maxKmh, units), units.speedLabel),
      ],
      if (a.elevGainM != null) ('Elevation gain', '${a.elevGainM!.round()}', 'm'),
    ];
    final w = a.weather;

    return ListView(
      padding: const EdgeInsets.all(Space.m),
      children: [
        Row(
          children: [
            IconTile(icon: a.type.icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ownerName == null ? a.type.label : '${a.type.label} by $ownerName',
                    style: t.titleMedium,
                  ),
                  Text(
                    '${formatLongDate(a.startedAt)} at ${formatClock(a.startedAt)}',
                    style: muted,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.l),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 360 ? 3 : 2;
            final width = (c.maxWidth - (cols - 1) * 12) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: Space.m,
              children: [
                for (final (label, value, unit) in stats)
                  SizedBox(
                    width: width,
                    child: StatValue(label: label, value: value, unit: unit),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: Space.l),
        if (w != null)
          Card(
            child: ListTile(
              // The snapshot has no day flag; daylight hours are close enough.
              leading: WeatherArt(
                code: w.code,
                isDay: a.startedAt.hour >= 6 && a.startedAt.hour < 18,
                size: 34,
              ),
              title: Text('${w.tempC.round()}°C · ${weatherLabel(w.code)}'),
              subtitle: Text('Wind ${w.windKmh.round()} km/h at the start'),
            ),
          ),
        const SizedBox(height: Space.s),
        Row(
          children: [
            Icon(
              a.visibility == ActivityVisibility.private
                  ? Icons.lock_outline_rounded
                  : Icons.people_outline_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                a.visibility == ActivityVisibility.private
                    ? 'Only you can see this'
                    : 'Shared with your circles',
                style: muted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color, {this.ring = Colors.white});

  final Color color;
  final Color ring;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: ring, width: 3),
    ),
  );
}
