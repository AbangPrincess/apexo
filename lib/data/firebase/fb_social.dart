import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/public_profile.dart';
import '../models/voice_clip.dart';
import '../repository.dart';
import 'fb_util.dart';

CollectionReference<Map<String, dynamic>> _sub(FirebaseFirestore db, String cid, String name) =>
    db.collection('circles').doc(cid).collection(name);

/// Profile copies in circles/{cid}/profiles. Each member writes only their
/// own; the member doc's profileRev says which version is published.
mixin FbMemberProfiles on AppRepository {
  FirebaseFirestore get db;

  @override
  Future<PublicProfile?> memberProfile(String circleId, String uid) async {
    final d = await _sub(db, circleId, 'profiles').doc(uid).get();
    final data = d.data();
    return data == null ? null : PublicProfile.fromMap(uid, data);
  }

  @override
  Future<void> publishProfile(String circleId, PublicProfile profile) => settle(
    (db.batch()
          ..set(_sub(db, circleId, 'profiles').doc(profile.uid), profile.toMap())
          ..update(_sub(db, circleId, 'members').doc(profile.uid), {'profileRev': profile.rev}))
        .commit(),
  );
}

/// Walkie-talkie messages: small metadata docs in circles/{cid}/voice that
/// everyone watches, and the audio bytes in circles/{cid}/voiceAudio, read
/// only when a message plays. Firestore keeps them because Cloud Storage
/// needs the paid plan; a 30 s message is about 60 KB.
mixin FbWalkie on AppRepository {
  FirebaseFirestore get db;

  @override
  Stream<List<VoiceClip>> watchVoice(String circleId) => _sub(db, circleId, 'voice')
      .orderBy('sentAt', descending: true)
      .limit(30)
      .snapshots()
      .map(
        (q) => [
          for (final d in q.docs)
            // sentAt is null until the server has stamped it.
            VoiceClip.fromMap(d.id, d.data()),
        ],
      );

  @override
  Future<void> sendVoice(String circleId, VoiceClip clip, Uint8List audio) => settle(
    (db.batch()
          ..set(_sub(db, circleId, 'voice').doc(clip.id), {
            ...clip.toMap(),
            'sentAt': FieldValue.serverTimestamp(),
          })
          ..set(_sub(db, circleId, 'voiceAudio').doc(clip.id), {
            'fromUid': clip.fromUid,
            'audio': Blob(audio),
          }))
        .commit(),
  );

  @override
  Future<Uint8List?> voiceAudio(String circleId, String clipId) async {
    final d = await _sub(db, circleId, 'voiceAudio').doc(clipId).get();
    final audio = d.data()?['audio'];
    return audio is Blob ? audio.bytes : null;
  }

  @override
  Future<void> deleteVoice(String circleId, String clipId) => settle(
    (db.batch()
          ..delete(_sub(db, circleId, 'voice').doc(clipId))
          ..delete(_sub(db, circleId, 'voiceAudio').doc(clipId)))
        .commit(),
  );
}
