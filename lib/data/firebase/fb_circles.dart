import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/invite_code.dart';
import '../models/activity.dart';
import '../models/circle.dart';
import '../models/map_read.dart';
import '../models/shared_activity.dart';
import '../models/user.dart';
import '../repository.dart';
import 'fb_profile.dart';
import 'fb_util.dart';

/// circles/{cid} with members, feed, and inviteCodes/{code} (the only way
/// a non-member can find a circle, because circle docs are members-only).
/// Every write here is one the rules in firestore.rules allow.
mixin FbCircles on AppRepository, FbProfile {
  final _memberCache = <String, Map<String, Map<String, dynamic>>>{};
  final _codes = <String, String>{};
  final _random = Random.secure();

  CollectionReference<Map<String, dynamic>> get _circles => db.collection('circles');
  DocumentReference<Map<String, dynamic>> _code(String code) =>
      db.collection('inviteCodes').doc(code);
  CollectionReference<Map<String, dynamic>> _members(String cid) =>
      _circles.doc(cid).collection('members');

  @override
  Stream<List<Circle>> watchCircles(String uid) => _circles
      .where('memberUids', arrayContains: uid)
      .snapshots()
      .map(
        (q) =>
            [for (final d in q.docs) Circle.fromMap(d.id, d.data())]
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      );

  @override
  Stream<List<Member>> watchMembers(String circleId) => _members(circleId).snapshots().map((q) {
    _memberCache[circleId] = {for (final d in q.docs) d.id: d.data()};
    return [for (final d in q.docs) Member.fromMap(d.id, d.data())]
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
  });

  @override
  Stream<List<SharedActivity>> watchCircleFeed(String circleId) => feedOf(circleId)
      .orderBy('startedAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (q) => [
          for (final d in q.docs)
            SharedActivity.fromMap(readString(d.data()['activityId'], d.id), d.data()),
        ],
      );

  @override
  Future<Circle> createCircle(AppUser owner, String name, {required bool sharing}) =>
      circleOp(() async {
        final clean = name.trim();
        if (clean.isEmpty) throw const CircleException('Give your circle a name.');
        await _checkLimit(owner.uid);
        var code = generateInviteCode(_random);
        for (var i = 0; i < 5 && (await _code(code).get()).exists; i++) {
          code = generateInviteCode(_random);
        }
        final ref = _circles.doc();
        final circle = Circle(
          id: ref.id,
          name: clean,
          inviteCode: code,
          ownerUid: owner.uid,
          memberUids: [owner.uid],
          createdAt: DateTime.now(),
        );
        final member = await _newMember(owner, sharing);
        final batch = db.batch()
          ..set(ref, circle.toMap())
          ..set(_members(ref.id).doc(owner.uid), member.toMap())
          ..set(_code(code), {
            'circleId': ref.id,
            'name': clean,
            'ownerName': owner.displayName,
            'memberCount': 1,
          });
        await settle(batch.commit());
        await _backfill(ref.id, owner);
        return circle;
      });

  @override
  Future<CirclePreview?> findCircle(String inviteCode) => circleOp(() async {
    final code = normalizeInviteCode(inviteCode);
    if (!isInviteCodeShape(code)) return null;
    final m = (await _code(code).get()).data();
    if (m == null) return null;
    final id = readString(m['circleId']);
    _codes[id] = code;
    return CirclePreview(
      id: id,
      name: readString(m['name'], 'Circle'),
      memberCount: readInt(m['memberCount'], 1),
      ownerName: readString(m['ownerName'], 'the owner'),
    );
  });

  @override
  Future<void> joinCircle(String circleId, AppUser user, {required bool sharing}) =>
      circleOp(() async {
        final mine = await myCircleIds(user.uid);
        if (mine.contains(circleId)) throw const CircleException("You're already in that circle.");
        await _checkLimit(user.uid, mine.length);
        final member = await _newMember(user, sharing);
        // Adds only my own uid; the rules reject anything else.
        final batch = db.batch()
          ..update(_circles.doc(circleId), {
            'memberUids': FieldValue.arrayUnion([user.uid]),
          })
          ..set(_members(circleId).doc(user.uid), member.toMap());
        final code = _codes[circleId];
        if (code != null) batch.update(_code(code), {'memberCount': FieldValue.increment(1)});
        await settle(batch.commit());
        await _backfill(circleId, user);
      });

  @override
  Future<void> leaveCircle(String circleId, String uid) => circleOp(() async {
    final ref = _circles.doc(circleId);
    final c = Circle.fromMap(circleId, (await ref.get()).data() ?? const {});
    final rest = [
      for (final u in c.memberUids)
        if (u != uid) u,
    ];
    final mine = await feedOf(circleId).where('ownerUid', isEqualTo: uid).get();
    final batch = db.batch()..delete(_members(circleId).doc(uid));
    for (final d in mine.docs) {
      batch.delete(d.reference);
    }
    final code = c.inviteCode.isEmpty ? null : _code(c.inviteCode);
    if (rest.isEmpty) {
      // The last one out deletes the circle (they are its owner by then).
      for (final d in (await ref.collection('alerts').get()).docs) {
        batch.delete(d.reference);
      }
      if (code != null) batch.delete(code);
      batch.delete(ref);
    } else {
      final heir = c.ownerUid == uid ? rest.first : null;
      batch.update(ref, {
        'memberUids': FieldValue.arrayRemove([uid]),
        'ownerUid': ?heir,
      });
      if (code != null) {
        final heirName = readString(_memberCache[circleId]?[heir]?['displayName']);
        batch.update(code, {
          'memberCount': FieldValue.increment(-1),
          if (heirName.isNotEmpty) 'ownerName': heirName,
        });
      }
    }
    await settle(batch.commit());
    _memberCache.remove(circleId);
  });

  @override
  Future<void> removeMember(String circleId, String ownerUid, String memberUid) =>
      circleOp(() async {
        if (memberUid == ownerUid) throw const CircleException('Use Leave circle to leave.');
        final ref = _circles.doc(circleId);
        final c = Circle.fromMap(circleId, (await ref.get()).data() ?? const {});
        if (c.ownerUid != ownerUid) {
          throw const CircleException('Only the circle owner can remove members.');
        }
        final theirs = await feedOf(circleId).where('ownerUid', isEqualTo: memberUid).get();
        final batch = db.batch()
          ..update(ref, {
            'memberUids': FieldValue.arrayRemove([memberUid]),
          })
          ..delete(_members(circleId).doc(memberUid));
        for (final d in theirs.docs) {
          batch.delete(d.reference);
        }
        if (c.inviteCode.isNotEmpty) {
          batch.update(_code(c.inviteCode), {'memberCount': FieldValue.increment(-1)});
        }
        await settle(batch.commit());
      });

  /// Sends only the fields that changed since the last snapshot.
  @override
  Future<void> updateMember(String circleId, Member member) async {
    final before = _memberCache[circleId]?[member.uid];
    final changed = changedFields(before, member.toMap());
    if (changed.isEmpty) return;
    _memberCache[circleId]?[member.uid] = {...?before, ...changed};
    try {
      await settle(_members(circleId).doc(member.uid).update(changed));
    } on FirebaseException catch (e) {
      // Removed meanwhile: a late write must not fail the caller.
      if (e.code != 'not-found' && e.code != 'permission-denied') rethrow;
    }
  }

  Future<void> _checkLimit(String uid, [int? count]) async {
    final n = count ?? (await myCircleIds(uid)).length;
    if (n >= maxCirclesPerUser) {
      throw const CircleException(
        'You can be in up to $maxCirclesPerUser circles. Leave one to make room.',
      );
    }
  }

  /// A new member's recent "Circles" activities appear in the circle too.
  Future<void> _backfill(String circleId, AppUser user) async {
    final q = await userDoc(
      user.uid,
    ).collection('activities').orderBy('startedAt', descending: true).limit(50).get();
    final shared = [
      for (final d in q.docs) Activity.fromMap(d.id, d.data()),
    ].where((a) => a.visibility == ActivityVisibility.circles).take(20).toList();
    if (shared.isEmpty) return;
    final batch = db.batch();
    for (final a in shared) {
      batch.set(feedOf(circleId).doc(FbProfile.feedId(user.uid, a.id)), sharedDoc(user, a));
    }
    await settle(batch.commit());
  }

  Future<Member> _newMember(AppUser user, bool sharing) async {
    final q = await userDoc(user.uid).collection('vehicles').get();
    final all = [for (final d in q.docs) Vehicle.fromMap(d.id, d.data())];
    final v = all.where((v) => v.id == user.activeVehicleId).firstOrNull ?? all.firstOrNull;
    // No position until the first fix; 0,0 keeps the pin off the map.
    return Member(
      uid: user.uid,
      displayName: user.displayName,
      lat: 0,
      lng: 0,
      ts: DateTime.now(),
      status: sharing ? MemberStatus.parked : MemberStatus.paused,
      sharing: sharing,
      vehicle: v == null ? null : MemberVehicle(type: v.type, name: v.name, status: v.status),
    );
  }
}
