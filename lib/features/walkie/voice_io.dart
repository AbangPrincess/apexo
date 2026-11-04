import 'dart:async';
import 'dart:io' show Directory, File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

/// A finished recording: the encoded audio and its type.
class VoiceRecording {
  const VoiceRecording(this.bytes, this.mime);

  final Uint8List bytes;
  final String mime;
}

/// Microphone and speaker for the walkie-talkie. Tests pass a fake.
abstract class VoiceIO {
  /// Asks for the microphone when needed; true when it may be used.
  Future<bool> requestMicAccess();

  /// Granted already, without asking.
  Future<bool> hasMicAccess();

  Future<void> start();

  /// Null when nothing was recorded.
  Future<VoiceRecording?> stop();
  Future<void> cancel();

  /// Completes when the message has played to the end or was stopped.
  Future<void> play(String id, Uint8List bytes, String mime);
  Future<void> stopPlayback();
  void dispose();
}

/// The device's microphone (record) and speaker (just_audio). Voice is
/// recorded as mono AAC at 24 kbit/s (about 3 KB a second), or Opus where
/// a browser can't record AAC. Plays through the phone speaker or a
/// connected headset, like a helmet intercom. Plugins load on first use.
class DeviceVoiceIO implements VoiceIO {
  AudioRecorder? _recorder;
  AudioPlayer? _player;
  String _mime = 'audio/mp4';

  AudioRecorder get _rec => _recorder ??= AudioRecorder();
  AudioPlayer get _out => _player ??= AudioPlayer();

  static String _temp(String name, String ext) => '${Directory.systemTemp.path}/apexo-$name.$ext';

  static String _ext(String mime) => mime == 'audio/mp4' ? 'm4a' : 'ogg';

  @override
  Future<bool> requestMicAccess() => _rec.hasPermission();

  @override
  Future<bool> hasMicAccess() => _rec.hasPermission(request: false);

  @override
  Future<void> start() async {
    final aac = await _rec.isEncoderSupported(AudioEncoder.aacLc);
    _mime = aac ? 'audio/mp4' : (kIsWeb ? 'audio/webm' : 'audio/ogg');
    await _rec.start(
      RecordConfig(
        encoder: aac ? AudioEncoder.aacLc : AudioEncoder.opus,
        bitRate: 24000,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ),
      // The web records into memory; phones into a temporary file.
      path: kIsWeb ? '' : _temp('talk-${DateTime.now().microsecondsSinceEpoch}', _ext(_mime)),
    );
  }

  @override
  Future<VoiceRecording?> stop() async {
    final out = await _rec.stop();
    if (out == null) return null;
    if (kIsWeb) {
      // A blob: URL for the recording in this page's memory.
      return VoiceRecording((await http.get(Uri.parse(out))).bodyBytes, _mime);
    }
    final file = File(out);
    final bytes = await file.readAsBytes();
    unawaited(file.delete().then((_) {}, onError: (Object _) {}));
    return VoiceRecording(bytes, _mime);
  }

  @override
  Future<void> cancel() => _rec.cancel();

  @override
  Future<void> play(String id, Uint8List bytes, String mime) async {
    await _out.stop();
    if (kIsWeb) {
      await _out.setAudioSource(AudioSource.uri(Uri.dataFromBytes(bytes, mimeType: mime)));
    } else {
      final file = File(_temp('play-$id', _ext(mime)));
      if (!file.existsSync()) await file.writeAsBytes(bytes, flush: true);
      await _out.setFilePath(file.path);
    }
    await _out.play();
  }

  @override
  Future<void> stopPlayback() async => _player?.stop();

  @override
  void dispose() {
    _recorder?.dispose();
    _player?.dispose();
  }
}
