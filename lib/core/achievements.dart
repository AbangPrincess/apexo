import 'dart:math' as math;

import 'activity_summary.dart';

enum AchievementKind { totalDistance, longestActivity, activityCount, earlyBird, weekStreak }

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.kind,
    required this.target,
    required this.current,
  });

  final String id;
  final String title;
  final AchievementKind kind;

  /// Meters for distance kinds, otherwise a count.
  final double target;
  final double current;

  bool get earned => current >= target;
  double get progress => target <= 0 ? 1 : (current / target).clamp(0.0, 1.0);
  bool get isDistance =>
      kind == AchievementKind.totalDistance || kind == AchievementKind.longestActivity;
}

const _defs = <(String, String, AchievementKind, double)>[
  ('total-10k', 'First 10', AchievementKind.totalDistance, 10000),
  ('total-50k', 'Fifty Up', AchievementKind.totalDistance, 50000),
  ('total-100k', 'Century Club', AchievementKind.totalDistance, 100000),
  ('total-500k', 'Road Warrior', AchievementKind.totalDistance, 500000),
  ('total-1000k', 'Thousand Club', AchievementKind.totalDistance, 1000000),
  ('long-20k', 'Going Long', AchievementKind.longestActivity, 20000),
  ('long-50k', 'Half Hundred', AchievementKind.longestActivity, 50000),
  ('long-100k', 'Century Ride', AchievementKind.longestActivity, 100000),
  ('count-1', 'First Tracks', AchievementKind.activityCount, 1),
  ('count-10', 'Regular', AchievementKind.activityCount, 10),
  ('count-50', 'Committed', AchievementKind.activityCount, 50),
  ('early-1', 'Early Bird', AchievementKind.earlyBird, 1),
  ('streak-4', 'Four-Week Streak', AchievementKind.weekStreak, 4),
];

/// Every achievement with its progress, distance milestones first.
List<Achievement> computeAchievements(Iterable<ActivityFacts> activities) {
  final list = activities.toList();
  final total = list.fold<double>(0, (s, a) => s + a.distanceM);
  final longest = list.fold<double>(0, (m, a) => math.max(m, a.distanceM));
  final early = list.where((a) => a.startedAt.hour < 6).length;
  final streak = longestWeekStreak(list.map((a) => a.startedAt));

  return [
    for (final (id, title, kind, target) in _defs)
      Achievement(
        id: id,
        title: title,
        kind: kind,
        target: target,
        current: switch (kind) {
          AchievementKind.totalDistance => total,
          AchievementKind.longestActivity => longest,
          AchievementKind.activityCount => list.length.toDouble(),
          AchievementKind.earlyBird => early.toDouble(),
          AchievementKind.weekStreak => streak.toDouble(),
        },
      ),
  ];
}

/// Longest run of consecutive calendar weeks with at least one activity.
int longestWeekStreak(Iterable<DateTime> starts) {
  final weeks = starts.map(startOfWeek).toSet().toList()..sort();
  var best = 0;
  var run = 0;
  DateTime? prev;
  for (final w in weeks) {
    // Days between week starts; 7 means the weeks touch (DST-safe via rounding).
    final gap = prev == null ? 0 : (w.difference(prev).inHours / 24).round();
    run = gap == 7 ? run + 1 : 1;
    best = math.max(best, run);
    prev = w;
  }
  return best;
}
