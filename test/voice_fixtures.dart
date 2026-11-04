import 'dart:typed_data';

import 'package:apexo/features/walkie/voice_io.dart';

/// Microphone and speaker that never touch a plugin: records three bytes
/// and "plays" instantly, remembering what it played.
class FakeVoiceIO implements VoiceIO {
  bool granted = true;
  bool recording = false;
  final played = <String>[];

  @override
  Future<bool> requestMicAccess() async => granted;

  @override
  Future<bool> hasMicAccess() async => granted;

  @override
  Future<void> start() async => recording = true;

  @override
  Future<VoiceRecording?> stop() async {
    recording = false;
    return VoiceRecording(Uint8List.fromList(const [1, 2, 3]), 'audio/mp4');
  }

  @override
  Future<void> cancel() async => recording = false;

  @override
  Future<void> play(String id, Uint8List bytes, String mime) async => played.add(id);

  @override
  Future<void> stopPlayback() async {}

  @override
  void dispose() {}
}
