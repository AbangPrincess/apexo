import 'package:flutter/material.dart';

import '../../core/activity_summary.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../widgets/stat_value.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// This week's distance, moving time and activity count.
class WeeklyHeader extends StatelessWidget {
  const WeeklyHeader({super.key, required this.activities, required this.units, required this.now});

  final List<ActivityFacts> activities;
  final Units units;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final week = weekTotals(activities, now);
    final from = startOfWeek(now);
    final to = DateTime(from.year, from.month, from.day + 6);
    final range = from.month == to.month
        ? '${_months[from.month - 1]} ${from.day} – ${to.day}'
        : '${_months[from.month - 1]} ${from.day} – ${_months[to.month - 1]} ${to.day}';

    return Card(
      color: AppColors.dark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
      child: Padding(
        padding: const EdgeInsets.all(Space.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The dates sit flush right, on the title's baseline; with very
            // large text both shrink to fit instead of spilling over.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text('This week', style: t.titleMedium?.copyWith(color: Colors.white)),
                ),
                const SizedBox(width: Space.s),
                Flexible(
                  child: Text(
                    range,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(color: AppColors.onDarkMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Spread over the card: left, centered and right, so the right
            // edge keeps the same padding as the left.
            Row(
              children: [
                Expanded(
                  child: StatValue(
                    label: 'Distance',
                    value: formatDistance(week.distanceM, units),
                    unit: units.distanceLabel,
                    onDark: true,
                    valueColor: AppColors.tracking,
                  ),
                ),
                Expanded(
                  child: StatValue(
                    label: 'Moving time',
                    value: formatDurationShort(week.movingSec),
                    onDark: true,
                    align: CrossAxisAlignment.center,
                  ),
                ),
                Expanded(
                  child: StatValue(
                    label: 'Activities',
                    value: '${week.count}',
                    onDark: true,
                    align: CrossAxisAlignment.end,
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
