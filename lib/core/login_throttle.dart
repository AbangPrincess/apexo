import 'dart:math' as math;

/// Locks an account after repeated failed sign-ins, with a lock that doubles
/// each time (30 s, 1 min, 2 min ... up to [maxLock]).
class LoginThrottle {
  LoginThrottle({
    this.maxAttempts = 5,
    this.baseLock = const Duration(seconds: 30),
    this.maxLock = const Duration(minutes: 15),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final int maxAttempts;
  final Duration baseLock;
  final Duration maxLock;
  final DateTime Function() _now;
  final _entries = <String, _Entry>{};

  /// Time left on the lock for [key], or null when not locked.
  Duration? lockRemaining(String key) {
    final until = _entries[key]?.lockedUntil;
    if (until == null) return null;
    final left = until.difference(_now());
    return left > Duration.zero ? left : null;
  }

  int attemptsLeft(String key) => maxAttempts - (_entries[key]?.failures ?? 0);

  /// Records a failed attempt. Returns the lock length if this one locked it.
  Duration? recordFailure(String key) {
    final e = _entries.putIfAbsent(key, _Entry.new);
    e.failures++;
    if (e.failures < maxAttempts) return null;
    final factor = math.pow(2, e.locks).toInt();
    final lock = baseLock * factor > maxLock ? maxLock : baseLock * factor;
    e
      ..lockedUntil = _now().add(lock)
      ..locks += 1
      ..failures = 0;
    return lock;
  }

  void recordSuccess(String key) => _entries.remove(key);
}

class _Entry {
  int failures = 0;
  int locks = 0;
  DateTime? lockedUntil;
}

/// "30 s", "2 min", "1 min 30 s".
String formatWait(Duration d) {
  final s = (d.inMilliseconds / 1000).ceil();
  if (s < 60) return '$s s';
  final m = s ~/ 60;
  final rest = s % 60;
  return rest == 0 ? '$m min' : '$m min $rest s';
}
