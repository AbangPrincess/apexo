import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/time_format.dart';
import '../../core/units.dart';
import '../../data/models/activity.dart';
import '../../widgets/profile_image.dart';
import '../../widgets/route_thumbnail.dart';
import '../../widgets/stat_value.dart';
import '../../widgets/visuals.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    required this.units,
    required this.now,
    this.ownerName,
    this.onTap,
  });

  final Activity activity;
  final Units units;
  final DateTime now;

  /// Set for activities other circle members shared.
  final String? ownerName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final a = activity;
    final owner = ownerName;
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
                      if (owner == null)
                        IconTile(icon: a.type.icon)
                      else
                        UserAvatar(photoUrl: '', initial: _initial(owner), radius: 22),
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
                                    [
                                      ?owner,
                                      a.type.label,
                                      formatRelativeDate(a.startedAt, now),
                                    ].join(' · '),
                                    style: muted,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (owner == null) ...[
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
                  // Left, centered and right, like the This week card.
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
                          align: CrossAxisAlignment.center,
                        ),
                      ),
                      Expanded(
                        child: StatValue(
                          label: a.type.usesPace ? 'Avg pace' : 'Avg speed',
                          value: a.type.usesPace
                              ? formatPace(a.avgKmh, units)
                              : formatSpeed(a.avgKmh, units),
                          unit: a.type.usesPace ? units.paceLabel : units.speedLabel,
                          size: statSize,
                          align: CrossAxisAlignment.end,
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

String _initial(String name) {
  final n = name.trim();
  return n.isEmpty ? '?' : n[0].toUpperCase();
}
