import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../core/geo.dart';
import '../../data/models/circle.dart';
import '../../data/models/circle_alert.dart';
import '../../data/models/user.dart';
import '../../data/repository.dart';

enum AlertScope {
  all('All'),
  mine('Mine'),
  circle('This circle');

  const AlertScope(this.label);
  final String label;
}

enum AlertPeriod {
  any('Any time'),
  today('Today'),
  week('7 days'),
  month('30 days');

  const AlertPeriod(this.label);
  final String label;

  DateTime? since(DateTime now) => switch (this) {
    AlertPeriod.any => null,
    AlertPeriod.today => DateTime(now.year, now.month, now.day),
    AlertPeriod.week => now.subtract(const Duration(days: 7)),
    AlertPeriod.month => now.subtract(const Duration(days: 30)),
  };
}

/// Alerts from all my circles, newest first. One event is stored once per
/// circle under the same id; here it shows once, with acks merged.
class AlertsController extends ChangeNotifier {
  AlertsController(this._repo) {
    _authSub = _repo.authStateChanges().listen(_onUser);
  }

  final AppRepository _repo;
  late final StreamSubscription<AppUser?> _authSub;
  StreamSubscription<List<Circle>>? _circlesSub;
  final _subs = <String, StreamSubscription<List<CircleAlert>>>{};
  final _byCircle = <String, List<CircleAlert>>{};
  final _where = <String, List<String>>{};
  final _known = <String>{};
  final _incoming = StreamController<CircleAlert>.broadcast();
  String? _uid;
  bool _loaded = false;
  List<CircleAlert> _all = const [];
  DateTime _seenUntil = clock.now();

  String? get uid => _uid;
  bool get loaded => _loaded;
  List<CircleAlert> get all => _all;

  /// Alerts raised by others after this session (or circle) started.
  Stream<CircleAlert> get incoming => _incoming.stream;

  int get unseenCount => _all.where((a) => a.ownerUid != _uid && a.ts.isAfter(_seenUntil)).length;

  void markSeen() {
    if (unseenCount == 0) return;
    _seenUntil = clock.now();
    notifyListeners();
  }

  List<String> circlesOf(String alertId) => _where[alertId] ?? const [];
  CircleAlert? byId(String id) => _all.where((a) => a.id == id).firstOrNull;

  List<CircleAlert> openFor(String ownerUid, String vehicleId) => [
    for (final a in _all)
      if (a.open && a.ownerUid == ownerUid && a.vehicleId == vehicleId) a,
  ];

  List<CircleAlert> filtered({
    AlertScope scope = AlertScope.all,
    String? circleId,
    AlertType? type,
    AlertPeriod period = AlertPeriod.any,
  }) {
    final since = period.since(clock.now());
    return [
      for (final a in _all)
        if ((scope != AlertScope.mine || a.ownerUid == _uid) &&
            (scope != AlertScope.circle || circlesOf(a.id).contains(circleId)) &&
            (type == null || a.type == type) &&
            (since == null || !a.ts.isBefore(since)))
          a,
    ];
  }

  /// "It's me" / seen: adds only my uid, in every circle holding the alert.
  Future<void> ack(CircleAlert a) async {
    final uid = _uid;
    if (uid == null) return;
    for (final c in circlesOf(a.id)) {
      await _repo.ackAlert(c, a.id, uid);
    }
  }

  /// The owner closes a theft alert.
  Future<void> recover(CircleAlert a) =>
      _updateEverywhere(a.id, (x) => x.copyWith(recoveredAt: clock.now()));

  /// The owner moves an open alert along with the vehicle.
  Future<void> follow(String alertId, GeoPoint p, double distanceM) =>
      _updateEverywhere(alertId, (x) => x.copyWith(lat: p.lat, lng: p.lng, distanceM: distanceM));

  Future<void> _updateEverywhere(String id, CircleAlert Function(CircleAlert) change) async {
    for (final c in circlesOf(id)) {
      // Start from that circle's own copy, so its acks are kept.
      final latest = _byCircle[c]?.where((x) => x.id == id).firstOrNull;
      if (latest != null) await _repo.updateAlert(c, change(latest));
    }
  }

  void _onUser(AppUser? user) {
    if (user?.uid == _uid) return;
    _uid = user?.uid;
    _circlesSub?.cancel();
    _circlesSub = null;
    _cancelFeeds();
    _loaded = false;
    _seenUntil = clock.now();
    _rebuild();
    final uid = _uid;
    if (uid != null) _circlesSub = _repo.watchCircles(uid).listen(_onCircles, onError: _keepLast);
  }

  void _onCircles(List<Circle> circles) {
    final ids = {for (final c in circles) c.id};
    for (final id in _subs.keys.toList()) {
      if (ids.contains(id)) continue;
      _subs.remove(id)?.cancel();
      _byCircle.remove(id);
    }
    for (final id in ids) {
      _subs[id] ??= _repo.watchAlerts(id).listen((list) => _onAlerts(id, list), onError: _keepLast);
    }
    _loaded = true;
    _rebuild();
  }

  void _onAlerts(String circleId, List<CircleAlert> list) {
    // A circle's first list is history, not news.
    final firstLoad = !_byCircle.containsKey(circleId);
    _byCircle[circleId] = list;
    _rebuild();
    for (final a in list) {
      if (_known.add(a.id) && !firstLoad && a.ownerUid != _uid) _incoming.add(a);
    }
  }

  void _rebuild() {
    final merged = <String, CircleAlert>{};
    _where.clear();
    for (final e in _byCircle.entries) {
      for (final a in e.value) {
        (_where[a.id] ??= []).add(e.key);
        final prev = merged[a.id];
        merged[a.id] = prev == null
            ? a
            : a.copyWith(
                recoveredAt: a.recoveredAt ?? prev.recoveredAt,
                ackBy: {...prev.ackBy, ...a.ackBy}.toList(),
              );
      }
    }
    _all = merged.values.toList()..sort((a, b) => b.ts.compareTo(a.ts));
    notifyListeners();
  }

  void _cancelFeeds() {
    for (final s in _subs.values) {
      s.cancel();
    }
    _subs.clear();
    _byCircle.clear();
    _known.clear();
  }

  @override
  void dispose() {
    _authSub.cancel();
    _circlesSub?.cancel();
    _cancelFeeds();
    _incoming.close();
    super.dispose();
  }

  /// A failed listener (offline, or access removed) keeps the last data it had.
  static void _keepLast(Object _) {}
}
