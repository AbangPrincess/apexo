import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/circle.dart';
import '../../data/models/shared_activity.dart';
import '../../data/models/user.dart';
import '../../data/repository.dart';

/// Activities other members shared with any of my circles, newest first.
/// An activity shared with two of my circles shows once.
class CircleFeedController extends ChangeNotifier {
  CircleFeedController(this._repo) {
    _authSub = _repo.authStateChanges().listen(_onUser);
  }

  final AppRepository _repo;
  late final StreamSubscription<AppUser?> _authSub;
  StreamSubscription<List<Circle>>? _circlesSub;
  final _subs = <String, StreamSubscription<List<SharedActivity>>>{};
  final _byCircle = <String, List<SharedActivity>>{};
  String? _uid;
  List<SharedActivity> _items = const [];

  List<SharedActivity> get items => _items;

  void _onUser(AppUser? user) {
    if (user?.uid == _uid) return;
    _uid = user?.uid;
    _circlesSub?.cancel();
    _circlesSub = null;
    _cancelFeeds();
    _rebuild();
    final uid = _uid;
    if (uid != null) _circlesSub = _repo.watchCircles(uid).listen(_onCircles);
  }

  void _onCircles(List<Circle> circles) {
    final ids = {for (final c in circles) c.id};
    for (final id in _subs.keys.toList()) {
      if (ids.contains(id)) continue;
      _subs.remove(id)?.cancel();
      _byCircle.remove(id);
    }
    for (final id in ids) {
      _subs[id] ??= _repo.watchCircleFeed(id).listen((list) {
        _byCircle[id] = list;
        _rebuild();
      });
    }
    _rebuild();
  }

  void _rebuild() {
    final seen = <String>{};
    final out = <SharedActivity>[
      for (final list in _byCircle.values)
        for (final s in list)
          if (s.ownerUid != _uid && seen.add('${s.ownerUid}/${s.id}')) s,
    ]..sort((a, b) => b.activity.startedAt.compareTo(a.activity.startedAt));
    _items = out;
    notifyListeners();
  }

  void _cancelFeeds() {
    for (final s in _subs.values) {
      s.cancel();
    }
    _subs.clear();
    _byCircle.clear();
  }

  @override
  void dispose() {
    _authSub.cancel();
    _circlesSub?.cancel();
    _cancelFeeds();
    super.dispose();
  }
}
