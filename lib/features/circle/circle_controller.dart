import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/circle.dart';
import '../../data/models/circle_alert.dart';
import '../../data/models/user.dart';
import '../../data/repository.dart';

/// The active circle, its members and alerts for the signed-in user.
class CircleController extends ChangeNotifier {
  CircleController(this._repo) {
    _authSub = _repo.authStateChanges().listen(_onUser);
  }

  final AppRepository _repo;
  late final StreamSubscription<AppUser?> _authSub;
  StreamSubscription<List<Circle>>? _circlesSub;
  StreamSubscription<List<Member>>? _membersSub;
  StreamSubscription<List<CircleAlert>>? _alertsSub;
  final _incoming = StreamController<CircleAlert>.broadcast();

  String? _uid;
  AppUser? _user;
  List<Circle> _circles = const [];
  String? _circleId;
  List<Member> _members = const [];
  List<CircleAlert> _alerts = const [];
  Set<String> _knownAlertIds = {};
  bool _alertsPrimed = false;
  bool _loaded = false;
  DateTime _seenUntil = DateTime.now();

  String? get uid => _uid;
  bool get loaded => _loaded;
  bool get atLimit => _circles.length >= maxCirclesPerUser;
  bool get isOwner => circle != null && circle!.ownerUid == _uid;

  /// My member doc in the active circle.
  Member? get me => _members.where((m) => m.uid == _uid).firstOrNull;
  List<Circle> get circles => _circles;
  Circle? get circle {
    for (final c in _circles) {
      if (c.id == _circleId) return c;
    }
    return null;
  }

  List<Member> get members => _members;
  List<CircleAlert> get alerts => _alerts;

  /// Alerts raised by others after this session started.
  Stream<CircleAlert> get incomingAlerts => _incoming.stream;

  int get unseenCount => _alerts.where((a) => a.ts.isAfter(_seenUntil)).length;

  void markAlertsSeen() {
    if (unseenCount == 0) return;
    _seenUntil = DateTime.now();
    notifyListeners();
  }

  void _onUser(AppUser? user) {
    _user = user;
    if (user?.uid == _uid) return;
    _uid = user?.uid;
    _circlesSub?.cancel();
    _circles = const [];
    _loaded = false;
    _select(null);
    _seenUntil = DateTime.now();
    final uid = _uid;
    if (uid != null) _circlesSub = _repo.watchCircles(uid).listen(_onCircles);
    notifyListeners();
  }

  void _onCircles(List<Circle> list) {
    _circles = list;
    _loaded = true;
    final keep = list.any((c) => c.id == _circleId);
    if (!keep) _select(list.isEmpty ? null : list.first.id);
    notifyListeners();
  }

  // Actions. Each throws CircleException with a message safe to show.

  Future<Circle> create(String name, {required bool sharing}) async {
    final c = await _repo.createCircle(_requireUser(), name, sharing: sharing);
    select(c.id);
    return c;
  }

  Future<CirclePreview?> find(String code) => _repo.findCircle(code);

  Future<void> join(String circleId, {required bool sharing}) async {
    await _repo.joinCircle(circleId, _requireUser(), sharing: sharing);
    select(circleId);
  }

  Future<void> leave(String circleId) => _repo.leaveCircle(circleId, _requireUser().uid);

  Future<void> remove(String circleId, String memberUid) =>
      _repo.removeMember(circleId, _requireUser().uid, memberUid);

  AppUser _requireUser() =>
      _user ?? (throw const CircleException('Sign in again to manage circles.'));

  void select(String circleId) {
    if (circleId == _circleId) return;
    _select(circleId);
    notifyListeners();
  }

  void _select(String? circleId) {
    _membersSub?.cancel();
    _alertsSub?.cancel();
    _circleId = circleId;
    _members = const [];
    _alerts = const [];
    _knownAlertIds = {};
    _alertsPrimed = false;
    if (circleId == null) return;
    _membersSub = _repo.watchMembers(circleId).listen((list) {
      _members = list;
      notifyListeners();
    });
    _alertsSub = _repo.watchAlerts(circleId).listen(_onAlerts);
  }

  void _onAlerts(List<CircleAlert> list) {
    if (_alertsPrimed) {
      for (final a in list) {
        if (!_knownAlertIds.contains(a.id) && a.ownerUid != _uid) _incoming.add(a);
      }
    }
    _knownAlertIds = {for (final a in list) a.id};
    _alertsPrimed = true;
    _alerts = list;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub.cancel();
    _circlesSub?.cancel();
    _membersSub?.cancel();
    _alertsSub?.cancel();
    _incoming.close();
    super.dispose();
  }
}
