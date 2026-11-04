import 'map_read.dart';
import 'user.dart';

/// circles/{cid}/profiles/{uid}: the part of a profile the circle may see
/// (never the email). Each member writes their own copy into every circle
/// they are in.
class PublicProfile {
  const PublicProfile({
    required this.uid,
    required this.displayName,
    this.bio = '',
    this.hometown = '',
    this.photoUrl = '',
    this.coverUrl = '',
  });

  factory PublicProfile.of(AppUser u) => PublicProfile(
    uid: u.uid,
    displayName: u.displayName,
    bio: u.bio,
    hometown: u.hometown,
    photoUrl: u.photoUrl,
    coverUrl: u.coverUrl,
  );

  final String uid;
  final String displayName;
  final String bio;
  final String hometown;
  final String photoUrl;
  final String coverUrl;

  String get initial {
    final n = displayName.trim();
    return n.isEmpty ? '?' : n[0].toUpperCase();
  }

  /// A short fingerprint of the visible fields. A member doc carries the
  /// one last published, so the app republishes only after a change.
  String get rev {
    // FNV-1a, 32 bit: cheap, stable across platforms.
    var h = 0x811c9dc5;
    for (final s in [displayName, bio, hometown, photoUrl, coverUrl]) {
      for (final c in s.codeUnits) {
        h = ((h ^ c) * 0x01000193) & 0xffffffff;
      }
      h = ((h ^ 0x1f) * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  factory PublicProfile.fromMap(String uid, Map<String, dynamic> m) => PublicProfile(
    uid: uid,
    displayName: readString(m['displayName'], 'Member'),
    bio: readString(m['bio']),
    hometown: readString(m['hometown']),
    photoUrl: readString(m['photoUrl']),
    coverUrl: readString(m['coverUrl']),
  );

  Map<String, dynamic> toMap() => {
    'displayName': displayName,
    'bio': bio,
    'hometown': hometown,
    'photoUrl': photoUrl,
    'coverUrl': coverUrl,
  };
}
