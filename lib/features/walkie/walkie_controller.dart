import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/voice_clip.dart';
import '../../data/repository.dart';
import '../circle/circle_controller.dart';
import 'voice_io.dart';
import 'voice_playback.dart';

enum TalkState { idle, starting, recording, sending }

/// The active circle's walkie-talkie. Hold (or tap) to talk; the message
/// sends when you let go (or tap again). Messages from others that arrive
/// while the app is open play by themselves, one after another, unless
/// auto-play is off. Any message can be replayed for 24 hours.
class WalkieController extends ChangeNotifier {
  WalkieController(this._repo, this._circles, {VoiceIO? voice}) : _io = voice {
    _playback = VoicePlayback(
      () => _voice,
      (c) => _circleId == null ? Future.value() : _repo.voiceAudio(_circleId!, c.id),
      _notify,
    );
    _circles.addListener(_bind);
    _bind();
  }

  final AppRepository _repo;
  final CircleController _circles;
  VoiceIO? _io;
  VoiceIO get _voice => _io ??= DeviceVoiceIO();
  late final VoicePlayback _playback;

  String? _circleId;
  String? _uid;
  StreamSubscription<List<VoiceClip>>? _sub;
  DateTime _since = clock.now();
  List<VoiceClip> _clips = const [];
  final _seen = <String>{};
  final _deleting = <String>{};

  bool _autoPlay = true;
  TalkState _talk = TalkState.idle;
  bool _sendWhenReady = false;
  DateTime? _talkStart;
  Timer? _ticker;
  Timer? _limit;
  String? _error;
  bool _disposed = false;

  /// Set once the microphone may be used, so its explanation shows once.
  bool micReady = false;

  bool get available => _circleId != null && _uid != null;
  List<VoiceClip> get clips => _clips;
  TalkState get talk => _talk;
  bool get talking => _talk == TalkState.starting || _talk == TalkState.recording;
  Duration get talkTime => _talkStart == null ? Duration.zero : clock.now().difference(_talkStart!);
  String? get playingId => _playback.playingId;
  bool get autoPlay => _autoPlay;
  String? get error => _error ?? _playback.error;
  bool isMine(VoiceClip c) => c.fromUid == _uid;

  Future<bool> hasMicAccess() => _voice.hasMicAccess().catchError((Object _) => false);
  Future<bool> requestMicAccess() async =>
      micReady = await _voice.requestMicAccess().catchError((Object _) => false);

  void setAutoPlay(bool on) {
    _autoPlay = on;
    _notify();
  }

  void clearError() {
    _error = null;
    _playback.error = null;
    _notify();
  }

  Future<void> play(VoiceClip c) => _playback.replay(c);
  Future<void> stopPlaying() => _playback.stop();

  void _bind() {
    final cid = _circles.circle?.id;
    final uid = _circles.uid;
    if (cid == _circleId && uid == _uid) return;
    _sub?.cancel();
    _circleId = cid;
    _uid = uid;
    _clips = const [];
    _playback.reset();
    _since = clock.now();
    if (cid != null && uid != null) {
      _sub = _repo.watchVoice(cid).listen(_onClips, onError: (Object _) {});
    }
    _notify();
  }

  void _onClips(List<VoiceClip> list) {
    final now = clock.now();
    bool fresh(VoiceClip c) => c.sentAt == null || now.difference(c.sentAt!) < voiceKeepFor;
    _clips = [
      for (final c in list)
        if (fresh(c)) c,
    ];
    // Others' messages sent since we started listening, oldest first.
    final from = _since.subtract(const Duration(seconds: 5));
    for (final c in _clips.reversed) {
      if (!_seen.add(c.id) || isMine(c)) continue;
      if (_autoPlay && c.sentAt != null && !c.sentAt!.isBefore(from)) _playback.enqueue(c);
    }
    // My expired messages are deleted by me (only the sender may).
    for (final c in list) {
      if (isMine(c) && !fresh(c) && _deleting.add(c.id)) {
        _repo.deleteVoice(_circleId!, c.id).catchError((Object _) {});
      }
    }
    _notify();
  }

  Future<void> startTalking() async {
    if (_talk != TalkState.idle || !available) return;
    _error = null;
    _sendWhenReady = false;
    _talk = TalkState.starting;
    _playback.held = true;
    _notify();
    // Pause what plays; queued messages wait until we are done.
    await _playback.stop(clearQueue: false);
    try {
      if (!micReady && !await requestMicAccess()) {
        return _finish(error: 'Allow the microphone to talk to your circle.');
      }
      await _voice.start();
    } catch (_) {
      return _finish(error: "Couldn't start the microphone.");
    }
    if (_talk != TalkState.starting) {
      // Cancelled while the microphone was starting.
      await _voice.cancel().catchError((Object _) {});
      return;
    }
    _talk = TalkState.recording;
    _talkStart = clock.now();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _notify());
    _limit = Timer(maxVoiceLength, stopAndSend);
    _notify();
    if (_sendWhenReady) await stopAndSend();
  }

  Future<void> stopAndSend() async {
    if (_talk == TalkState.starting) {
      _sendWhenReady = true;
      return;
    }
    if (_talk != TalkState.recording) return;
    final length = talkTime;
    _stopTimers();
    _talk = TalkState.sending;
    _notify();
    String? problem;
    try {
      final rec = await _voice.stop();
      if (rec == null || length < const Duration(milliseconds: 500)) {
        problem = 'Too short. Hold the button while you talk.';
      } else {
        final clip = VoiceClip(
          id: '${_uid}_${clock.now().microsecondsSinceEpoch}',
          fromUid: _uid!,
          fromName: _circles.me?.displayName ?? 'Member',
          durationMs: math.max(1, math.min(length.inMilliseconds, maxVoiceLength.inMilliseconds)),
          mime: rec.mime,
        );
        _seen.add(clip.id);
        _playback.keep(clip.id, rec.bytes);
        await _repo.sendVoice(_circleId!, clip, rec.bytes);
      }
    } catch (_) {
      problem = "Couldn't send. Check your connection and try again.";
    }
    _finish(error: problem);
  }

  Future<void> cancelTalking() async {
    if (!talking) return;
    final wasRecording = _talk == TalkState.recording;
    _finish();
    if (wasRecording) await _voice.cancel().catchError((Object _) {});
  }

  void _finish({String? error}) {
    _stopTimers();
    _talk = TalkState.idle;
    _error = error;
    _playback.held = false;
    _notify();
    _playback.drain();
  }

  void _stopTimers() {
    _ticker?.cancel();
    _limit?.cancel();
    _ticker = null;
    _limit = null;
    _talkStart = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _circles.removeListener(_bind);
    _sub?.cancel();
    _stopTimers();
    _io?.dispose();
    super.dispose();
  }
}
