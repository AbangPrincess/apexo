import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/geo.dart';
import '../../data/models/circle.dart';
import '../../data/models/public_profile.dart';
import '../../data/models/user.dart';
import '../../data/repository.dart';

/// The active circle and its members for the signed-in user. Alerts from
/// all circles live in AlertsController.
class CircleController extends ChangeNotifier {
  CircleController(this._repo) {
    _authSub = _repo.authStateChanges().listen(_onUser);
  }

  final AppRepository _repo;
  late final StreamSubscription<AppUser?> _authSub;
  StreamSubscription<List<Circle>>? _circlesSub;
  StreamSubscription<List<Member>>? _membersSub;

  String? _uid;
  AppUser? _user;
  List<Circle> _circles = const [];
  String? _circleId;
  List<Member> _members = const [];
  bool _loaded = false;
  bool _failed = false;
  GeoPoint? _focus;

  /// "circleId:rev" pairs published this session, so a profile copy is
  /// written once per change, not on every update.
  final _published = <String>{};

  String? get uid => _uid;
  bool get loaded => _loaded;

  /// The circle list could not be loaded (no connection, or no access).
  bool get failed => _failed;
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

  /// A spot the map should move to (e.g. "View on map" on an alert).
  GeoPoint? get pendingFocus => _focus;

  GeoPoint? takeFocus() {
    final f = _focus;
    _focus = null;
    return f;
  }

  void focusOn(String circleId, GeoPoint p) {
    _focus = p;
    if (circleId != _circleId) _select(circleId);
    notifyListeners();
  }

  void _onUser(AppUser? user) {
    final before = _user;
    _user = user;
    if (user != null && user.uid == _uid) {
      // Same person, edited profile: update every circle's copy.
      if (before != null && PublicProfile.of(before).rev != PublicProfile.of(user).rev) {
        for (final c in _circles) {
          _publish(c.id, PublicProfile.of(user));
        }
      }
      return;
    }
    if (user?.uid == _uid) return;
    _uid = user?.uid;
    _circles = const [];
    _focus = null;
    _select(null);
    _watchCircles();
  }

  void _watchCircles() {
    _circlesSub?.cancel();
    _loaded = false;
    _failed = false;
    final uid = _uid;
    if (uid != null) {
      _circlesSub = _repo
          .watchCircles(uid)
          .listen(
            _onCircles,
            onError: (Object _) {
              _loaded = true;
              _failed = true;
              notifyListeners();
            },
          );
    }
    notifyListeners();
  }

  /// Try again after [failed].
  void retry() => _watchCircles();

  void _onCircles(List<Circle> list) {
    _circles = list;
    _loaded = true;
    _failed = false;
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

  /// What [uid] shows the active circle; my own comes from my profile.
  Future<PublicProfile?> profileOf(String uid) async {
    final user = _user;
    if (user != null && uid == user.uid) return PublicProfile.of(user);
    final cid = _circleId;
    return cid == null ? null : _repo.memberProfile(cid, uid);
  }

  AppUser _requireUser() =>
      _user ?? (throw const CircleException('Sign in again to manage circles.'));

  void select(String circleId) {
    if (circleId == _circleId) return;
    _select(circleId);
    notifyListeners();
  }

  void _select(String? circleId) {
    _membersSub?.cancel();
    _circleId = circleId;
    _members = const [];
    if (circleId == null) return;
    _membersSub = _repo.watchMembers(circleId).listen(
      (list) {
        _members = list;
        _syncProfile();
        notifyListeners();
      },
      // A failed listener keeps the last members it had.
      onError: (Object _) {},
    );
  }

  /// Publishes my profile copy to the active circle when its member doc
  /// shows an older (or no) version.
  void _syncProfile() {
    final user = _user;
    final cid = _circleId;
    if (user == null || cid == null) return;
    final me = _members.where((m) => m.uid == user.uid).firstOrNull;
    final profile = PublicProfile.of(user);
    if (me == null || me.profileRev == profile.rev) return;
    _publish(cid, profile);
  }

  void _publish(String circleId, PublicProfile profile) {
    if (!_published.add('$circleId:${profile.rev}')) return;
    // Best effort: it is tried again on the next change or session.
    _repo.publishProfile(circleId, profile).catchError((Object _) {});
  }

  @override
  void dispose() {
    _authSub.cancel();
    _circlesSub?.cancel();
    _membersSub?.cancel();
    super.dispose();
  }
}
