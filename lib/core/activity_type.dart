/// Activity types stored as 'cycling' | 'running' | 'motorcycling' | 'driving'.
/// Running covers jogging too; the pace tells them apart.
enum ActivityType {
  cycling('Cycling', 'Ride', speedCapMps: 20, minMovingKmh: 3, minStepM: 5),
  running('Running', 'Run', speedCapMps: 9, minMovingKmh: 2.5, minStepM: 4),
  motorcycling('Motorcycling', 'Moto ride', speedCapMps: 60, minMovingKmh: 5, minStepM: 8),
  driving('Driving', 'Drive', speedCapMps: 70, minMovingKmh: 5, minStepM: 8);

  const ActivityType(
    this.label,
    this.noun, {
    required this.speedCapMps,
    required this.minMovingKmh,
    required this.minStepM,
  });

  final String label;

  /// Used in auto titles, e.g. "Morning Ride".
  final String noun;

  /// Fixes implying a faster speed than this are GPS jumps.
  final double speedCapMps;

  /// Slower than this counts as standing still (and auto-pauses).
  final double minMovingKmh;

  /// The smallest movement counted, in meters; GPS jitter is ignored below
  /// this or the fix's accuracy, whichever is larger.
  final double minStepM;

  /// Runs are shown as pace (min/km) rather than speed.
  bool get usesPace => this == ActivityType.running;
}
