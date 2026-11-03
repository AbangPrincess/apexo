import 'activity_type.dart';

/// The few fields summaries need, so this file stays independent of models.
abstract interface class ActivityFacts {
  ActivityType get type;
  DateTime get startedAt;
  double get distanceM;
  int get movingSec;
}

class Totals {
  const Totals({this.count = 0, this.distanceM = 0, this.movingSec = 0});

  final int count;
  final double distanceM;
  final int movingSec;

  static const zero = Totals();

  Totals add(ActivityFacts a) => Totals(
    count: count + 1,
    distanceM: distanceM + a.distanceM,
    movingSec: movingSec + a.movingSec,
  );
}

/// Monday 00:00 of the week containing [t].
DateTime startOfWeek(DateTime t) => DateTime(t.year, t.month, t.day - (t.weekday - 1));

Totals totalsOf(Iterable<ActivityFacts> list) => list.fold(Totals.zero, (sum, a) => sum.add(a));

Totals weekTotals(Iterable<ActivityFacts> list, DateTime now) {
  final from = startOfWeek(now);
  final to = DateTime(from.year, from.month, from.day + 7);
  return totalsOf(list.where((a) => !a.startedAt.isBefore(from) && a.startedAt.isBefore(to)));
}

/// Meters per day, Monday first, for the week containing [now].
List<double> dailyDistanceThisWeek(Iterable<ActivityFacts> list, DateTime now) {
  final from = startOfWeek(now);
  final days = List<double>.filled(7, 0);
  for (final a in list) {
    final day = DateTime(a.startedAt.year, a.startedAt.month, a.startedAt.day);
    final i = day.difference(from).inHours ~/ 24;
    if (i >= 0 && i < 7) days[i] += a.distanceM;
  }
  return days;
}

/// Totals for every activity type, in enum order (zeros included).
Map<ActivityType, Totals> totalsByType(Iterable<ActivityFacts> list) {
  final out = {for (final t in ActivityType.values) t: Totals.zero};
  for (final a in list) {
    out[a.type] = out[a.type]!.add(a);
  }
  return out;
}

/// "Morning Ride", "Evening Drive"...
String autoTitle(ActivityType type, DateTime start) {
  final h = start.hour;
  final part = h < 5
      ? 'Night'
      : h < 11
      ? 'Morning'
      : h < 14
      ? 'Lunch'
      : h < 18
      ? 'Afternoon'
      : h < 21
      ? 'Evening'
      : 'Night';
  return '$part ${type.noun}';
}
