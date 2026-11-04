import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/circle.dart';
import '../../data/repository.dart';

/// My own member doc in each of my circles, kept live. [onChange] runs
/// after every update, including echoes of my own writes.
class MyMemberDocs {
  MyMemberDocs(this._repo, this.onChange);

  final AppRepository _repo;
  final VoidCallback onChange;
  StreamSubscription<List<Circle>>? _circlesSub;
  final _subs = <String, StreamSubscription<List<Member>>>{};
  final _mine = <String, Member>{};
  String? _uid;

  Member? operator [](String circleId) => _mine[circleId];
  Iterable<MapEntry<String, Member>> get entries => _mine.entries;

  /// Follows [uid]'s circles; null stops and forgets everything.
  void watch(String? uid) {
    cancel();
    _uid = uid;
    if (uid != null) _circlesSub = _repo.watchCircles(uid).listen(_onCircles, onError: _keepLast);
  }

  void _onCircles(List<Circle> circles) {
    final ids = {for (final c in circles) c.id};
    for (final id in _subs.keys.toList()) {
      if (ids.contains(id)) continue;
      _subs.remove(id)?.cancel();
      _mine.remove(id);
    }
    for (final id in ids) {
      _subs[id] ??= _repo
          .watchMembers(id)
          .listen((list) => _onMembers(id, list), onError: _keepLast);
    }
    onChange();
  }

  void _onMembers(String circleId, List<Member> list) {
    final me = list.where((m) => m.uid == _uid).firstOrNull;
    if (me == null) {
      _mine.remove(circleId);
    } else {
      _mine[circleId] = me;
    }
    onChange();
  }

  void cancel() {
    _circlesSub?.cancel();
    _circlesSub = null;
    for (final s in _subs.values) {
      s.cancel();
    }
    _subs.clear();
    _mine.clear();
  }

  /// A failed listener (offline, or access removed) keeps the last data it had.
  static void _keepLast(Object _) {}
}
