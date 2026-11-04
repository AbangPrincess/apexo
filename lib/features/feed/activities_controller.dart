import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/activity.dart';
import '../../data/models/user.dart';
import '../../data/repository.dart';

/// The signed-in user's activities, newest first. Shared by Home and Me.
class ActivitiesController extends ChangeNotifier {
  ActivitiesController(this._repo) {
    _authSub = _repo.authStateChanges().listen(_onUser);
  }

  final AppRepository _repo;
  late final StreamSubscription<AppUser?> _authSub;
  StreamSubscription<List<Activity>>? _sub;
  String? _uid;
  List<Activity> _items = const [];
  bool _loaded = false;
  bool _failed = false;

  List<Activity> get items => _items;
  bool get loaded => _loaded;

  /// The last load failed (no connection, or no access); [items] are the
  /// last good copy.
  bool get failed => _failed;

  void _onUser(AppUser? user) {
    // Profile edits re-emit the user; only a different account resubscribes.
    if (user?.uid == _uid) return;
    _uid = user?.uid;
    _sub?.cancel();
    _items = const [];
    _loaded = false;
    _failed = false;
    final uid = _uid;
    if (uid != null) _sub = _watch(uid);
    notifyListeners();
  }

  StreamSubscription<List<Activity>> _watch(String uid, [Completer<void>? first]) => _repo
      .watchActivities(uid)
      .listen(
        (list) {
          _items = list;
          _loaded = true;
          _failed = false;
          notifyListeners();
          if (first != null && !first.isCompleted) first.complete();
        },
        onError: (Object _) {
          _loaded = true;
          _failed = true;
          notifyListeners();
          if (first != null && !first.isCompleted) first.complete();
        },
      );

  /// Re-subscribes and waits for fresh data (pull to refresh, Try again).
  Future<void> refresh() async {
    final uid = _uid;
    if (uid == null) return;
    await _sub?.cancel();
    final first = Completer<void>();
    _sub = _watch(uid, first);
    await first.future.timeout(const Duration(seconds: 10), onTimeout: () {});
  }

  Future<void> delete(String activityId) async {
    final uid = _uid;
    if (uid != null) await _repo.deleteActivity(uid, activityId);
  }

  @override
  void dispose() {
    _authSub.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
