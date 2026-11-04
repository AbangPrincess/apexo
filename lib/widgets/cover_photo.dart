import 'package:flutter/material.dart';

import '../core/geo.dart';
import '../core/theme.dart';
import 'profile_image.dart';
import 'route_thumbnail.dart';

/// Covers are 3:1, like X (Twitter). Saved covers are cropped to it.
const coverAspect = 3.0;

/// Height of a full-width cover.
double coverHeightFor(double width) => (width / coverAspect).clamp(96.0, 420.0);

/// The cover photo, or (without one) a route drawn on stealth charcoal.
class CoverPhoto extends StatelessWidget {
  const CoverPhoto({super.key, required this.url, this.route = const [], this.rounded = false});

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
                child: route.length < 2
                    ? const SizedBox.expand()
                    : CustomPaint(
                        painter: RoutePainter(
                          route,
                          AppColors.data.withValues(alpha: 0.9),
                          padding: 20,
                        ),
                      ),
              ),
      ),
    );
  }
}
