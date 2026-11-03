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
      color: AppColors.accentSoft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
      child: Padding(
        padding: const EdgeInsets.all(Space.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('This week', style: t.titleMedium),
                const Spacer(),
                Text(range, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatValue(
                    label: 'Distance',
                    value: formatDistance(week.distanceM, units),
                    unit: units.distanceLabel,
                  ),
                ),
                Expanded(
                  child: StatValue(
                    label: 'Moving time',
                    value: formatDurationShort(week.movingSec),
                  ),
                ),
                Expanded(
                  child: StatValue(label: 'Activities', value: '${week.count}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
