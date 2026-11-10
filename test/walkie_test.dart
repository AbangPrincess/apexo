import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apexo/data/fake/demo_seed.dart';
import 'package:apexo/data/models/voice_clip.dart';

import 'app_harness.dart';
import 'voice_fixtures.dart';

final _talk = find.byKey(const ValueKey('talk-button'));

void main() {
  testWidgets('hold to talk sends a message the circle can replay', (tester) async {
    final voice = FakeVoiceIO();
    final repo = await pumpApp(tester, sizes['iPhone']!, voice: voice);
    await signInDemo(tester);
    await goTo(tester, 'circle');
    expect(_talk, findsWidgets, reason: 'Talk floats on the map');

    final hold = await tester.startGesture(tester.getCenter(_talk.first));
    await tester.pump(const Duration(milliseconds: 100));
    expect(voice.recording, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('0:02'), findsOneWidget, reason: 'the button shows the seconds');
    await hold.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(voice.recording, isFalse);

    final sent = repo.store.voiceOf(DemoIds.circle).value;
    expect(sent, hasLength(1));
    expect(sent.single.durationMs, inInclusiveRange(1900, 2300));
    expect(sent.single.fromUid, DemoIds.you);

    // Replay it from the walkie card under the member list.
    final card = find.byKey(const ValueKey('walkie-card'));
    await tester.scrollUntilVisible(card, 200, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('clip-${sent.single.id}')));
    await tester.pumpAndSettle();
    expect(voice.played, [sent.single.id]);
  });

  testWidgets('tap, talk, tap again also sends; a quick blip does not', (tester) async {
    final voice = FakeVoiceIO();
    final repo = await pumpApp(tester, sizes['iPhone']!, voice: voice);
    await signInDemo(tester);
    await goTo(tester, 'circle');

    await tester.tap(_talk.first);
    await tester.pump(const Duration(seconds: 3));
    expect(voice.recording, isTrue, reason: 'a tap keeps talking');
    await tester.tap(_talk.first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(repo.store.voiceOf(DemoIds.circle).value, hasLength(1));
    await tester.pumpAndSettle();
  });

  testWidgets("others' new messages play by themselves, one after another", (tester) async {
    final voice = FakeVoiceIO();
    final repo = await pumpApp(tester, sizes['iPhone']!, voice: voice);
    await signInDemo(tester);
    VoiceClip clip(String id) => VoiceClip(
      id: id,
      fromUid: DemoIds.john,
      fromName: 'John',
      durationMs: 3000,
      mime: 'audio/mp4',
    );
    final audio = Uint8List.fromList(const [9, 9]);
    await repo.sendVoice(DemoIds.circle, clip('j1'), audio);
    await repo.sendVoice(DemoIds.circle, clip('j2'), audio);
    await tester.pumpAndSettle();
    expect(voice.played, ['j1', 'j2'], reason: 'heard on any tab, oldest first');
  });

  testWidgets('a member profile shows what they share, never their email', (tester) async {
    await pumpApp(tester, sizes['iPhone']!);
    await signInDemo(tester);
    await goTo(tester, 'circle');
    await tapVisible(tester, find.byKey(const ValueKey('profile-${DemoIds.john}')));
    expect(find.textContaining('Weekend trail rider'), findsOneWidget);
    expect(find.text('Koronadal City'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // My own copy is published to the circle and shown the same way.
    final mine = find.byKey(const ValueKey('profile-${DemoIds.you}'));
    await tester.scrollUntilVisible(mine, -100, scrollable: find.byType(Scrollable).last);
    await tapVisible(tester, mine);
    expect(find.text('How your circle sees you'), findsOneWidget);
  });
}
