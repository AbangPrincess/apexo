import 'dart:typed_data';

import '../../data/models/voice_clip.dart';
import 'voice_io.dart';

/// Plays walkie-talkie messages one at a time: a queue for new ones, replay
/// on demand, and the audio of the last few kept in memory.
class VoicePlayback {
  VoicePlayback(this._io, this._fetch, this._changed);

  final VoiceIO Function() _io;
  final Future<Uint8List?> Function(VoiceClip clip) _fetch;
  final void Function() _changed;

  final _queue = <VoiceClip>[];
  final _audio = <String, Uint8List>{};
  int _token = 0;

  /// Set while talking: new messages wait in the queue.
  bool held = false;
  String? playingId;
  String? error;

  void enqueue(VoiceClip c) {
    _queue.add(c);
    drain();
  }

  void keep(String id, Uint8List bytes) {
    _audio[id] = bytes;
    if (_audio.length > 12) _audio.remove(_audio.keys.first);
  }

  /// Plays [c] now, replacing whatever plays and whatever was queued.
  Future<void> replay(VoiceClip c) async {
    _queue.clear();
    await _halt();
    await _play(c);
    drain();
  }

  /// Stops the current message. [clearQueue] false keeps the rest waiting.
  Future<void> stop({bool clearQueue = true}) async {
    if (clearQueue) _queue.clear();
    await _halt();
  }

  void reset() {
    _queue.clear();
    _halt();
  }

  Future<void> _halt() async {
    _token++;
    playingId = null;
    _changed();
    await _io().stopPlayback();
  }

  Future<void> drain() async {
    while (playingId == null && !held && _queue.isNotEmpty) {
      await _play(_queue.removeAt(0));
    }
  }

  Future<void> _play(VoiceClip c) async {
    final token = ++_token;
    playingId = c.id;
    error = null;
    _changed();
    try {
      final bytes = _audio[c.id] ?? await _fetch(c);
      if (bytes == null) {
        error = 'That message is no longer available.';
      } else {
        keep(c.id, bytes);
        await _io().play(c.id, bytes, c.mime);
      }
    } catch (_) {
      // Browsers may block sound until the page has been tapped once.
      error = "Couldn't play that message. Tap it to play.";
    }
    if (token == _token) playingId = null;
    _changed();
  }
}
