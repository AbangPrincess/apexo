import 'dart:typed_data';

import 'package:clock/clock.dart';

import '../models/public_profile.dart';
import '../models/voice_clip.dart';
import '../repository.dart';
import 'demo_seed.dart';
import 'fake_store.dart';

/// Profiles the demo riders show to the circle.
void seedDemoProfiles(FakeStore store, String circleId) {
  for (final p in const [
    PublicProfile(
      uid: DemoIds.jero,
      displayName: 'Jero',
      hometown: 'Koronadal City',
      bio: 'Weekend trail rider. Usually the one who waits at the top.',
    ),
    PublicProfile(
      uid: DemoIds.shane,
      displayName: 'Shane',
      hometown: 'Tupi',
      bio: 'Scooter commuter, Sunday runner and coffee-stop planner.',
    ),
  ]) {
    store.memberProfiles['$circleId/${p.uid}'] = p;
  }
}

/// Profile copies of the demo backend, like circles/{cid}/profiles.
mixin FakeMemberProfiles on AppRepository {
  FakeStore get store;

  @override
  Future<PublicProfile?> memberProfile(String circleId, String uid) async =>
      store.memberProfiles['$circleId/$uid'];

  @override
  Future<void> publishProfile(String circleId, PublicProfile profile) async {
    store.memberProfiles['$circleId/${profile.uid}'] = profile;
    final members = store.membersOf(circleId);
    members.value = [
      for (final m in members.value) m.uid == profile.uid ? m.copyWith(profileRev: profile.rev) : m,
    ];
  }
}

/// Walkie-talkie messages of the demo backend, kept in memory.
mixin FakeWalkie on AppRepository {
  FakeStore get store;

  @override
  Stream<List<VoiceClip>> watchVoice(String circleId) => store.voiceOf(circleId).stream;

  @override
  Future<void> sendVoice(String circleId, VoiceClip clip, Uint8List audio) async {
    store.voiceAudio['$circleId/${clip.id}'] = audio;
    final voice = store.voiceOf(circleId);
    voice.value = [
      clip.copyWith(sentAt: clip.sentAt ?? clock.now()),
      ...voice.value.where((c) => c.id != clip.id),
    ].take(30).toList();
  }

  @override
  Future<Uint8List?> voiceAudio(String circleId, String clipId) async =>
      store.voiceAudio['$circleId/$clipId'];

  @override
  Future<void> deleteVoice(String circleId, String clipId) async {
    store.voiceAudio.remove('$circleId/$clipId');
    final voice = store.voiceOf(circleId);
    voice.value = [
      for (final c in voice.value)
        if (c.id != clipId) c,
    ];
  }
}
