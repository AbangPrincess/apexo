import 'map_read.dart';

/// The longest walkie-talkie message; recording stops and sends by itself.
const maxVoiceLength = Duration(seconds: 30);

/// Voice messages older than this are hidden, and their sender's app
/// deletes them.
const voiceKeepFor = Duration(hours: 24);

/// circles/{cid}/voice/{id}: one walkie-talkie message. The audio itself
/// lives in circles/{cid}/voiceAudio/{id}, fetched only when played, so
/// the list stays cheap to watch.
class VoiceClip {
  const VoiceClip({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.durationMs,
    required this.mime,
    this.sentAt,
  });

  final String id;
  final String fromUid;
  final String fromName;
  final int durationMs;

  /// audio/mp4 (AAC) where the device can record it, else audio/webm.
  final String mime;

  /// Server time; null while the message is still uploading.
  final DateTime? sentAt;

  Duration get duration => Duration(milliseconds: durationMs);

  String get initial {
    final n = fromName.trim();
    return n.isEmpty ? '?' : n[0].toUpperCase();
  }

  factory VoiceClip.fromMap(String id, Map<String, dynamic> m) => VoiceClip(
    id: id,
    fromUid: readString(m['fromUid']),
    fromName: readString(m['fromName'], 'Member'),
    durationMs: readInt(m['durationMs'], 0),
    mime: readString(m['mime'], 'audio/mp4'),
    sentAt: m['sentAt'] == null ? null : readDate(m['sentAt']),
  );

  /// Without sentAt: the backend stamps it with its own clock.
  Map<String, dynamic> toMap() => {
    'fromUid': fromUid,
    'fromName': fromName,
    'durationMs': durationMs,
    'mime': mime,
  };

  VoiceClip copyWith({DateTime? sentAt}) => VoiceClip(
    id: id,
    fromUid: fromUid,
    fromName: fromName,
    durationMs: durationMs,
    mime: mime,
    sentAt: sentAt ?? this.sentAt,
  );
}
