import 'package:flutter/material.dart';

import '../core/image_check.dart';
import '../core/theme.dart';

final _cache = <String, ImageProvider>{};

/// Image for a stored photo (https URL or small data: URI). Cached so the same
/// photo is decoded once and does not flicker on rebuilds.
ImageProvider? profileImage(String url) {
  if (url.isEmpty) return null;
  final hit = _cache[url];
  if (hit != null) return hit;
  final bytes = bytesFromDataUri(url);
  if (bytes == null && !url.startsWith('https://')) return null;
  if (_cache.length >= 24) _cache.remove(_cache.keys.first);
  return _cache[url] = bytes != null ? MemoryImage(bytes) : NetworkImage(url);
}

/// Round profile photo, or the initial on an accent circle.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.photoUrl,
    required this.initial,
    this.radius = 20,
    this.ring = 0,
  });

  final String photoUrl;
  final String initial;
  final double radius;

  /// White ring width, used when the avatar overlaps a cover photo.
  final double ring;

  @override
  Widget build(BuildContext context) {
    final image = profileImage(photoUrl);
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.ink,
      foregroundImage: image,
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.onInk,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    if (ring <= 0) return avatar;
    return Container(
      padding: EdgeInsets.all(ring),
      decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
      child: avatar,
    );
  }
}
