import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/activity_summary.dart';
import '../../core/activity_type.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../widgets/visuals.dart';

/// Distance per day this week, as a painted bar chart.
class WeeklyChartCard extends StatelessWidget {
  const WeeklyChartCard({
    super.key,
    required this.activities,
    required this.units,
    required this.now,
  });

  final List<ActivityFacts> activities;
  final Units units;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final days = dailyDistanceThisWeek(activities, now);
    final total = days.fold<double>(0, (a, b) => a + b);
    final today = now.weekday - 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('This week', style: t.titleMedium)),
                Text(
                  '${formatDistance(total, units)} ${units.distanceLabel}',
                  style: t.titleMedium?.copyWith(fontFeatures: kTabular),
                ),
              ],
            ),
            const SizedBox(height: Space.m),
            Semantics(
              label:
                  'Distance per day this week. Total ${formatDistance(total, units)} ${units.distanceLabel}.',
              excludeSemantics: true,
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: CustomPaint(painter: _BarsPainter(days, today, t.labelSmall!)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.days, this.today, this.labelStyle);

  final List<double> days;
  final int today;
  final TextStyle labelStyle;
  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void paint(Canvas canvas, Size size) {
    const labelH = 20.0;
    final chartH = size.height - labelH;
    final maxV = days.fold<double>(0, math.max);
    final slot = size.width / 7;
    final barW = math.min(28.0, slot * 0.55);
    for (var i = 0; i < 7; i++) {
      final h = maxV <= 0 ? 0.0 : (days[i] / maxV) * (chartH - 4);
      final x = slot * i + (slot - barW) / 2;
      final color = days[i] > 0
          ? (i == today ? AppColors.accent : AppColors.accent.withValues(alpha: 0.55))
          : AppColors.hairline;
      final barH = math.max(h, 4.0); // a stub shows empty days
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, chartH - barH, barW, barH),
          const Radius.circular(6),
        ),
        Paint()..color = color,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: _labels[i],
          style: labelStyle.copyWith(
            color: i == today ? AppColors.text : AppColors.textMuted,
            fontWeight: i == today ? FontWeight.w700 : null,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(slot * i + (slot - tp.width) / 2, chartH + 6));
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.today != today || !_same(old.days, days);

  static bool _same(List<double> a, List<double> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return a.length == b.length;
  }
}

/// All-time count, time and distance per activity type.
class TypeTotalsCard extends StatelessWidget {
  const TypeTotalsCard({super.key, required this.activities, required this.units});

  final List<ActivityFacts> activities;
  final Units units;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final totals = totalsByType(activities);
    return Card(
      child: Column(
        children: [
          for (final type in ActivityType.values) ...[
            if (type != ActivityType.values.first)
              const Divider(indent: Space.m, endIndent: Space.m),
            ListTile(
              leading: IconTile(icon: type.icon, size: 40),
              title: Text(type.label),
              subtitle: Text(
                '${totals[type]!.count} ${totals[type]!.count == 1 ? 'activity' : 'activities'} · '
                '${formatDurationShort(totals[type]!.movingSec)}',
              ),
              trailing: Text(
                '${formatDistance(totals[type]!.distanceM, units)} ${units.distanceLabel}',
                style: t.titleMedium?.copyWith(fontFeatures: kTabular),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
