import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/time_format.dart';
import '../../core/units.dart';
import '../../data/models/activity.dart';
import '../../widgets/route_thumbnail.dart';
import '../../widgets/stat_value.dart';
import '../../widgets/visuals.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    required this.units,
    required this.now,
    this.onTap,
  });

  final Activity activity;
  final Units units;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final a = activity;
    final private = a.visibility == ActivityVisibility.private;
    final muted = t.bodySmall?.copyWith(color: AppColors.textMuted);

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.m),
          child: LayoutBuilder(
            builder: (context, c) {
              final statSize = c.maxWidth < 300 ? StatSize.small : StatSize.medium;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                              a.title,
                              style: t.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '${a.type.label} · ${formatRelativeDate(a.startedAt, now)}',
                                    style: muted,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  private
                                      ? Icons.lock_outline_rounded
                                      : Icons.people_outline_rounded,
                                  size: 14,
                                  color: AppColors.textMuted,
                                  semanticLabel: private ? 'Private' : 'Shared with circles',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RouteThumbnail(points: a.points, height: 140),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: StatValue(
                          label: 'Distance',
                          value: formatDistance(a.distanceM, units),
                          unit: units.distanceLabel,
                          size: statSize,
                        ),
                      ),
                      Expanded(
                        child: StatValue(
                          label: 'Moving time',
                          value: formatDurationShort(a.movingSec),
                          size: statSize,
                        ),
                      ),
                      Expanded(
                        child: StatValue(
                          label: 'Avg speed',
                          value: formatSpeed(a.avgKmh, units),
                          unit: units.speedLabel,
                          size: statSize,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
