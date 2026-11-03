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

  List<Activity> get items => _items;
  bool get loaded => _loaded;

  void _onUser(AppUser? user) {
    // Profile edits re-emit the user; only a different account resubscribes.
    if (user?.uid == _uid) return;
    _uid = user?.uid;
    _sub?.cancel();
    _items = const [];
    _loaded = false;
    final uid = _uid;
    if (uid != null) {
      _sub = _repo.watchActivities(uid).listen((list) {
        _items = list;
        _loaded = true;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
