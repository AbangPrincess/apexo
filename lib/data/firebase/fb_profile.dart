import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/activity_type.dart';
import '../../core/units.dart';
import '../models/activity.dart';
import '../models/shared_activity.dart';
import '../models/user.dart';
import '../repository.dart';
import 'fb_util.dart';

/// users/{uid}, its vehicles and activities, and the copies of "Circles"
/// activities in circles/{cid}/feed (a client-side fan-out; no Cloud
/// Functions on the free plan).
mixin FbProfile on AppRepository {
  FirebaseFirestore get db;

  DocumentReference<Map<String, dynamic>> userDoc(String uid) => db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> feedOf(String circleId) =>
      db.collection('circles').doc(circleId).collection('feed');

  /// Feed docs are keyed by owner too, so two members' ids never collide.
  static String feedId(String uid, String activityId) => '${uid}_$activityId';

  Map<String, Object?> sharedDoc(AppUser owner, Activity a) => {
    ...SharedActivity.of(owner, a, DateTime.now()).toMap(),
    'activityId': a.id,
  };

  Future<List<String>> myCircleIds(String uid) async {
    final q = await db.collection('circles').where('memberUids', arrayContains: uid).get();
    return [for (final d in q.docs) d.id];
  }

  @override
  Future<void> updateProfile(
    String uid, {
    String? displayName,
    Units? units,
    ActivityType? defaultActivity,
    String? bio,
    String? hometown,
    String? photoUrl,
    String? coverUrl,
    String? activeVehicleId,
  }) async {
    final fields = <String, Object?>{
      if (displayName != null) 'displayName': displayName.trim(),
      if (units != null) 'units': units.name,
      if (defaultActivity != null) 'defaultActivity': defaultActivity.name,
      'bio': ?bio,
      'hometown': ?hometown,
      'photoUrl': ?photoUrl,
      'coverUrl': ?coverUrl,
      'activeVehicleId': ?activeVehicleId,
    };
    if (fields.isNotEmpty) await settle(userDoc(uid).update(fields));
  }

  @override
  Stream<List<Vehicle>> watchVehicles(String uid) => userDoc(uid)
      .collection('vehicles')
      .snapshots()
      .map(
        // Ids are "v-<microseconds>", so this keeps the order they were added.
        (q) =>
            [for (final d in q.docs) Vehicle.fromMap(d.id, d.data())]
              ..sort((a, b) => a.id.compareTo(b.id)),
      );

  @override
  Future<void> saveVehicle(String uid, Vehicle vehicle) =>
      settle(userDoc(uid).collection('vehicles').doc(vehicle.id).set(vehicle.toMap()));

  @override
  Future<void> deleteVehicle(String uid, String vehicleId) =>
      settle(userDoc(uid).collection('vehicles').doc(vehicleId).delete());

  @override
  Stream<List<Activity>> watchActivities(String uid) => userDoc(uid)
      .collection('activities')
      .orderBy('startedAt', descending: true)
      .snapshots()
      .map((q) => [for (final d in q.docs) Activity.fromMap(d.id, d.data())]);

  @override
  Future<void> saveActivity(String uid, Activity activity) async {
    final owner = currentUser;
    final circles = await myCircleIds(uid);
    final batch = db.batch()
      ..set(userDoc(uid).collection('activities').doc(activity.id), activity.toMap());
    for (final c in circles) {
      final ref = feedOf(c).doc(feedId(uid, activity.id));
      if (activity.visibility == ActivityVisibility.circles && owner != null) {
        batch.set(ref, sharedDoc(owner, activity));
      } else {
        batch.delete(ref);
      }
    }
    await settle(batch.commit());
  }

  @override
  Future<void> deleteActivity(String uid, String activityId) async {
    final circles = await myCircleIds(uid);
    final batch = db.batch()..delete(userDoc(uid).collection('activities').doc(activityId));
    for (final c in circles) {
      batch.delete(feedOf(c).doc(feedId(uid, activityId)));
    }
    await settle(batch.commit());
  }
}
