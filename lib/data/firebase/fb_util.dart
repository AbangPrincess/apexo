import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/map_read.dart';
import '../repository.dart';

/// Deep equality for Firestore values; a stored Timestamp equals the same
/// DateTime, and 64 equals 64.0.
bool sameValue(Object? a, Object? b) {
  if (a is DateTime || b is DateTime || a is Timestamp || b is Timestamp) {
    return a != null && b != null && readDate(a).isAtSameMomentAs(readDate(b));
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !sameValue(a[k], b[k])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!sameValue(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// Only the fields that differ, so two writers (sharing and guard, say)
/// never overwrite each other's fields with stale values.
Map<String, Object?> changedFields(Map<String, dynamic>? before, Map<String, dynamic> after) => {
  for (final e in after.entries)
    if (before == null || !before.containsKey(e.key) || !sameValue(before[e.key], e.value))
      e.key: e.value,
};

/// Waits briefly for the server. Offline, the write is already in the local
/// cache and syncs later, so the app carries on instead of hanging.
Future<void> settle(Future<void> write) =>
    write.timeout(const Duration(seconds: 4), onTimeout: () {});

/// Runs a circle operation and turns backend errors into messages that are
/// safe to show.
Future<T> circleOp<T>(Future<T> Function() op) async {
  try {
    return await op();
  } on FirebaseException catch (e) {
    throw CircleException(switch (e.code) {
      'permission-denied' => "You don't have access to that circle anymore.",
      'unavailable' => 'No connection. Check your internet and try again.',
      'not-found' => 'That circle no longer exists.',
      _ => 'Something went wrong. Please try again.',
    });
  }
}
