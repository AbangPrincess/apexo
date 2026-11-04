import 'package:flutter/material.dart';

import '../../core/geo.dart';
import '../../core/theme.dart';
import '../../data/models/user.dart';
import '../../widgets/profile_image.dart';
import '../../widgets/route_thumbnail.dart';

/// Cover photo with the profile photo overlapping it, then name and stats.
/// Phones stack everything; wide screens put the name beside the photo.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.user,
    required this.statsLine,
    required this.wide,
    required this.coverRoute,
    required this.onChangeAvatar,
    required this.onChangeCover,
    required this.actions,
  });

  final AppUser user;
  final String statsLine;
  final bool wide;

  /// Drawn on the default cover when there is no cover photo.
  final List<GeoPoint> coverRoute;
  final VoidCallback onChangeAvatar;
  final VoidCallback onChangeCover;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = wide ? 80.0 : 62.0;
    final coverH = wide ? 290.0 : 190.0;
    final left = wide ? Space.xl : Space.m;
    final name = Text(
      user.displayName,
      style: (wide ? t.headlineMedium : t.headlineSmall)?.copyWith(fontWeight: FontWeight.w800),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    final stats = Text(statsLine, style: t.titleSmall?.copyWith(color: AppColors.textMuted));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: coverH + (wide ? 104 : r * 1.1),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: coverH,
                child: _Cover(url: user.coverUrl, route: coverRoute, rounded: wide),
              ),
              Positioned(
                right: Space.m,
                top: coverH - 52,
                child: _PhotoButton(
                  icon: Icons.photo_camera_outlined,
                  label: wide ? 'Edit cover photo' : null,
                  onTap: onChangeCover,
                ),
              ),
              Positioned(
                left: left,
                top: coverH - r * 1.15,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    UserAvatar(photoUrl: user.photoUrl, initial: user.initial, radius: r, ring: 4),
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: _PhotoButton(icon: Icons.photo_camera_outlined, onTap: onChangeAvatar),
                    ),
                  ],
                ),
              ),
              if (wide)
                Positioned(
                  left: left + r * 2 + 8 + Space.l,
                  right: Space.xl,
                  top: coverH + Space.m,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            name,
                            const SizedBox(height: Space.xs),
                            stats,
                          ],
                        ),
                      ),
                      actions,
                    ],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: left),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!wide) ...[name, const SizedBox(height: Space.xs), stats],
              if (user.bio.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(user.bio, style: t.bodyLarge?.copyWith(height: 1.4)),
              ],
              if (!wide) ...[const SizedBox(height: Space.m), actions],
            ],
          ),
        ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url, required this.route, required this.rounded});

  final String url;
  final List<GeoPoint> route;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final image = profileImage(url);
    final radius = rounded
        ? const BorderRadius.vertical(bottom: Radius.circular(kRadius))
        : BorderRadius.zero;
    return Semantics(
      label: 'Cover photo',
      image: true,
      child: ClipRRect(
        borderRadius: radius,
        child: image != null
            ? Image(image: image, fit: BoxFit.cover, gaplessPlayback: true)
            : ColoredBox(
                color: AppColors.darkRaised,
                // No cover yet: the rider's longest route on stealth charcoal.
                child: CustomPaint(
                  painter: RoutePainter(route, AppColors.data.withValues(alpha: 0.9), padding: 28),
                ),
              ),
      ),
    );
  }
}

class _PhotoButton extends StatelessWidget {
  const _PhotoButton({required this.icon, required this.onTap, this.label});

  final IconData icon;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final style = IconButton.styleFrom(
      backgroundColor: AppColors.surfaceAlt,
      foregroundColor: AppColors.text,
      side: BorderSide(color: AppColors.hairline),
    );
    if (label != null) {
      return FilledButton.tonalIcon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label!),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.text,
          minimumSize: const Size(0, 40),
        ),
      );
    }
    return IconButton(
      tooltip: 'Change photo',
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      style: style,
    );
  }
}
