import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/circle_alert.dart';
import '../repository.dart';
import 'fb_util.dart';

/// circles/{cid}/alerts. Members create their own alerts, the owner moves
/// or closes theirs, and anyone in the circle adds only their own ack.
mixin FbAlerts on AppRepository {
  FirebaseFirestore get db;

  final _alertCache = <String, Map<String, Map<String, dynamic>>>{};

  CollectionReference<Map<String, dynamic>> _alerts(String cid) =>
      db.collection('circles').doc(cid).collection('alerts');

  @override
  Stream<List<CircleAlert>> watchAlerts(String circleId) =>
      _alerts(circleId).orderBy('ts', descending: true).limit(100).snapshots().map((q) {
        _alertCache[circleId] = {for (final d in q.docs) d.id: d.data()};
        return [for (final d in q.docs) CircleAlert.fromMap(d.id, d.data())];
      });

  @override
  Future<void> addAlert(String circleId, CircleAlert alert) =>
      settle(_alerts(circleId).doc(alert.id).set(alert.toMap()));

  /// Position, distance or recovery only; acks are never overwritten.
  @override
  Future<void> updateAlert(String circleId, CircleAlert alert) async {
    final changed = changedFields(_alertCache[circleId]?[alert.id], alert.toMap())..remove('ackBy');
    if (changed.isEmpty) return;
    await settle(_alerts(circleId).doc(alert.id).update(changed));
  }

  @override
  Future<void> ackAlert(String circleId, String alertId, String uid) => settle(
    _alerts(circleId).doc(alertId).update({
      'ackBy': FieldValue.arrayUnion([uid]),
    }),
  );
}
