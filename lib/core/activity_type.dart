/// Activity types stored as 'cycling' | 'motorcycling' | 'driving'.
enum ActivityType {
  cycling('Cycling', 'Ride', speedCapMps: 20, autoPauseKmh: 1),
  motorcycling('Motorcycling', 'Moto ride', speedCapMps: 60, autoPauseKmh: 3),
  driving('Driving', 'Drive', speedCapMps: 70, autoPauseKmh: 3);

  const ActivityType(
    this.label,
    this.noun, {
    required this.speedCapMps,
    required this.autoPauseKmh,
  });

  final String label;

  /// Used in auto titles, e.g. "Morning Ride".
  final String noun;

  /// Fixes implying a faster speed than this are GPS jumps.
  final double speedCapMps;

  /// Below this speed for a while the recording auto-pauses.
  final double autoPauseKmh;
}
