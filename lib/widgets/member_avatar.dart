import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Round initial avatar with a status ring and an optional vehicle badge.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.initial,
    required this.ringColor,
    this.size = 44,
    this.badge,
    this.highlight = false,
    this.outline = false,
  });

  final String initial;
  final Color ringColor;
  final double size;
  final IconData? badge;

  /// Solid ink fill, used for the signed-in user.
  final bool highlight;

  /// Thin dark edge so light rings (volt) stay visible on map tiles.
  final bool outline;

  @override
  Widget build(BuildContext context) {
    final badgeSize = size * 0.44;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: kMotion,
            width: size,
            height: size,
            padding: EdgeInsets.all(size * 0.06),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: ringColor, width: size * 0.07),
              boxShadow: outline
                  ? const [BoxShadow(color: AppColors.mapInk, spreadRadius: 1.5)]
                  : null,
            ),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: highlight ? AppColors.ink : AppColors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w700,
                  color: highlight ? AppColors.onInk : AppColors.ink,
                ),
              ),
            ),
          ),
          if (badge != null)
            Positioned(
              right: -size * 0.06,
              bottom: -size * 0.06,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Icon(badge, size: badgeSize * 0.62, color: AppColors.text),
              ),
            ),
        ],
      ),
    );
  }
}
