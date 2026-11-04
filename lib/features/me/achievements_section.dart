import 'package:flutter/material.dart';

import '../../core/achievements.dart';
import '../../core/theme.dart';
import '../../core/units.dart';

/// Badge grid: distance milestones first, then the rest.
class AchievementsSection extends StatelessWidget {
  const AchievementsSection({super.key, required this.achievements, required this.units});

  final List<Achievement> achievements;
  final Units units;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final earned = achievements.where((a) => a.earned).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The count sits flush right, on the title's baseline; with very
        // large text both shrink to fit instead of spilling over.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(child: Text('Achievements', style: t.titleLarge)),
            const SizedBox(width: Space.s),
            Flexible(
              child: Text(
                '$earned of ${achievements.length} earned',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final cols = (c.maxWidth / 112).floor().clamp(3, 6);
            final w = (c.maxWidth - (cols - 1) * 12) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final a in achievements)
                  SizedBox(
                    width: w,
                    child: _Badge(achievement: a, units: units),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.achievement, required this.units});

  final Achievement achievement;
  final Units units;

  IconData get _icon => switch (achievement.kind) {
    AchievementKind.totalDistance => Icons.emoji_events_rounded,
    AchievementKind.longestActivity => Icons.trending_up_rounded,
    AchievementKind.activityCount => Icons.flag_rounded,
    AchievementKind.earlyBird => Icons.wb_twilight_rounded,
    AchievementKind.weekStreak => Icons.local_fire_department_rounded,
  };

  String _dist(double meters) {
    final km = meters / 1000;
    final v = units == Units.km ? km : kmToMi(km);
    final s = v >= 100 || v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
    return '$s ${units.distanceLabel}';
  }

  String get _goal {
    final a = achievement;
    final n = a.target.round();
    return switch (a.kind) {
      AchievementKind.totalDistance => 'Cover ${_dist(a.target)} in total',
      AchievementKind.longestActivity => 'Go ${_dist(a.target)} in one activity',
      AchievementKind.activityCount => 'Record $n ${n == 1 ? 'activity' : 'activities'}',
      AchievementKind.earlyBird => 'Start an activity before 6 AM',
      AchievementKind.weekStreak => 'Be active $n weeks in a row',
    };
  }

  String get _progress {
    final a = achievement;
    if (a.earned) return 'Earned';
    return a.isDistance
        ? '${_dist(a.current)} / ${_dist(a.target)}'
        : '${a.current.round()} / ${a.target.round()}';
  }

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final t = Theme.of(context).textTheme;
    final title = t.labelLarge?.copyWith(color: a.earned ? Colors.white : null, height: 1.25);
    final twoLines = MediaQuery.textScalerOf(context).scale(title?.fontSize ?? 15) * 1.25 * 2;
    return Tooltip(
      message: _goal,
      triggerMode: TooltipTriggerMode.tap,
      child: Semantics(
        label: '${a.title}. $_goal. $_progress',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: a.earned ? AppColors.dark : AppColors.surface,
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(color: a.earned ? AppColors.dark : AppColors.hairline),
          ),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: a.earned ? AppColors.tracking : AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icon,
                  color: a.earned ? AppColors.on(AppColors.tracking) : AppColors.parked,
                  size: 26,
                ),
              ),
              const SizedBox(height: Space.s),
              // Two title lines are always reserved, so every tile (earned
              // or not, short title or long) is the same height.
              SizedBox(
                height: twoLines,
                child: Center(
                  child: Text(
                    a.title,
                    style: title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _progress,
                style: t.bodySmall?.copyWith(
                  color: a.earned ? AppColors.tracking : AppColors.textMuted,
                  fontWeight: a.earned ? FontWeight.w600 : null,
                  fontFeatures: kTabular,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // Earned tiles keep the bar too (full, in volt): same shape.
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: a.earned ? 1 : a.progress,
                  minHeight: 4,
                  color: a.earned ? AppColors.tracking : AppColors.data,
                  backgroundColor: a.earned ? AppColors.darkLine : AppColors.surfaceAlt,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
