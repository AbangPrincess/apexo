import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../core/geo.dart';
import '../../core/share_gate.dart';
import '../../core/stats.dart';
import '../../core/units.dart';
import '../../data/models/circle.dart';
import '../../data/models/user.dart';
import '../../data/repository.dart';
import '../record/location_source.dart';
import '../record/record_controller.dart';
import 'my_member_docs.dart';

/// Publishes my member doc to every circle I share with, within the write
/// budget. While a recording runs its fixes are reused (one GPS stream);
/// otherwise a low-rate sharing stream runs. Nothing is kept on the device.
class SharingController extends ChangeNotifier {
  SharingController(this._repo, this._record, {this.readBattery, ShareGate? gate})
    : _gate = gate ?? ShareGate() {
    _authSub = _repo.authStateChanges().listen(_onUser);
    _record.addListener(_onRecord);
  }

  final AppRepository _repo;
  final RecordController _record;
  final ShareGate _gate;

  /// Battery percent, or null when the platform cannot tell.
  final Future<int?> Function()? readBattery;

  /// Below this speed a member shows as parked.
  static const movingKmh = 4.0;

  late final StreamSubscription<AppUser?> _authSub;
  late final _mine = MyMemberDocs(_repo, _sync);
  Set<String> _sharingIds = {};
  StreamSubscription<Fix>? _fixSub;
  Timer? _beat;
  String? _uid;
  GeoPoint? _point;
  GeoPoint? _published;
  DateTime? _fixAt;
  double _kmh = 0;
  MemberStatus? _lastStatus;
  bool _fromRecording = false;
  bool _blocked = false;

  /// True while my location is shared with at least one circle.
  bool get active => _sharingIds.isNotEmpty;
  int get sharingCount => _sharingIds.length;
  bool isSharing(String circleId) => _sharingIds.contains(circleId);

  /// Sharing is on, but the device will not give a position.
  bool get blocked => active && _blocked;

  /// Null when location can be used, else a message saying why not.
  Future<String?> ensureAccess() async => switch (await _record.source.ensureAccess()) {
    LocationAccess.granted => null,
    LocationAccess.serviceOff => 'Turn on location services to share your location.',
    LocationAccess.deniedForever => 'Location access is blocked. Allow it in Settings to share.',
    LocationAccess.denied => 'Apexo needs location access to share where you are.',
  };

  /// Turns sharing with one circle on or off; null when done, else a
  /// message to show. Pausing also blanks the stored position.
  Future<String?> setSharing(String circleId, bool on) async {
    final me = _mine[circleId];
    if (me == null) return null;
    if (on) {
      final denied = await ensureAccess();
      if (denied != null) return denied;
      _blocked = false;
    }
    final alert = me.status == MemberStatus.alert;
    final now = clock.now();
    await _repo.updateMember(
      circleId,
      on
          ? me.copyWith(sharing: true, status: alert ? null : MemberStatus.parked, ts: now)
          : me.copyWith(
              sharing: false,
              status: alert ? null : MemberStatus.paused,
              lat: 0,
              lng: 0,
              speedKmh: 0,
              ts: now,
            ),
    );
    return null;
  }

  /// Where I am, for the locate-me button. Asks for access if needed.
  Future<GeoPoint?> locate() async {
    final known = _point;
    if (known != null) return known;
    if (await ensureAccess() != null) return null;
    return _record.source.currentPosition();
  }

  void _onUser(AppUser? user) {
    if (user?.uid == _uid) return;
    _uid = user?.uid;
    _mine.cancel();
    _point = _published = _fixAt = null;
    _blocked = false;
    _sync();
    _mine.watch(_uid);
  }

  /// Starts or stops location work to match the circles I share with.
  void _sync() {
    final ids = {
      for (final e in _mine.entries)
        if (e.value.sharing) e.key,
    };
    final added = ids.difference(_sharingIds).isNotEmpty;
    final changed = added || ids.length != _sharingIds.length;
    _sharingIds = ids;
    if (ids.isEmpty) {
      _stopFixes();
      _beat?.cancel();
      _beat = null;
      _gate.reset();
      _lastStatus = null;
    } else {
      // The gate turns these ticks into a 60 s heartbeat while still.
      _beat ??= Timer.periodic(const Duration(seconds: 15), (_) => _publish());
      _listen();
      if (added) {
        // A newly shared circle gets my position at once.
        _gate.reset();
        _publish();
      }
    }
    if (changed) notifyListeners();
  }

  void _listen() {
    _fromRecording = _record.isActive;
    if (_fromRecording) {
      _stopFixes();
      return;
    }
    if (_fixSub != null || _blocked) return;
    _fixSub = _record.source.sharingFixes().listen(
      _onFix,
      onError: (Object _) {
        _blocked = true;
        _stopFixes();
        notifyListeners();
      },
      cancelOnError: true,
    );
  }

  void _stopFixes() {
    _fixSub?.cancel();
    _fixSub = null;
  }

  void _onRecord() {
    if (_sharingIds.isEmpty) return;
    if (_record.isActive != _fromRecording) _listen();
    // The live position, also while standing still (the route only grows
    // with real movement).
    final here = _record.position;
    if (!_record.isActive || here == null) return;
    if (here == _point && _record.currentKmh == _kmh) return;
    _point = here;
    _kmh = _record.currentKmh;
    _publish();
  }

  void _onFix(Fix f) {
    final p = GeoPoint(f.lat, f.lng);
    final prev = _point;
    final prevAt = _fixAt;
    final secs = prevAt == null ? 0 : f.time.difference(prevAt).inMilliseconds / 1000;
    // Web often reports no speed; estimate it from the last fix.
    _kmh = f.speedMps != null
        ? mpsToKmh(f.speedMps!)
        : (prev == null || secs <= 0 ? 0.0 : mpsToKmh(distanceM(prev, p) / secs));
    _point = p;
    _fixAt = f.time;
    if (_blocked) {
      _blocked = false;
      notifyListeners();
    }
    _publish();
  }

  Future<void> _publish() async {
    final p = _point;
    if (p == null || _sharingIds.isEmpty) return;
    final now = clock.now();
    final status = _kmh >= movingKmh ? MemberStatus.tracking : MemberStatus.parked;
    if (!_gate.shouldPublish(p, now, changed: status != _lastStatus)) return;
    _lastStatus = status;
    final prev = _published;
    _published = p;
    final heading = prev == null || distanceM(prev, p) < 1 ? null : bearingDeg(prev, p);
    final battery = await readBattery?.call();
    for (final id in _sharingIds.toList()) {
      final me = _mine[id];
      if (me == null || !me.sharing) continue;
      await _repo.updateMember(
        id,
        me.copyWith(
          lat: p.lat,
          lng: p.lng,
          speedKmh: _kmh,
          heading: heading,
          battery: battery,
          // The vehicle guard (P5) owns the alert state.
          status: me.status == MemberStatus.alert ? null : status,
          ts: now,
        ),
      );
    }
  }

  @override
  void dispose() {
    _authSub.cancel();
    _mine.cancel();
    _stopFixes();
    _beat?.cancel();
    _record.removeListener(_onRecord);
    super.dispose();
  }
}
