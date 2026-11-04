import 'package:flutter/material.dart';

import '../../core/geo.dart';
import '../../core/theme.dart';
import '../../widgets/map_view.dart';

/// The live map card: the route so far, where you are with the GPS accuracy
/// ring, the status on top, a re-center button once you pan away and the
/// ride controls at the bottom.
class LiveMap extends StatelessWidget {
  const LiveMap({
    super.key,
    required this.controller,
    required this.position,
    required this.accuracyM,
    required this.path,
    required this.following,
    required this.onUserMove,
    required this.onRecenter,
    required this.status,
    this.controls,
    this.talk,
  });

  final MapViewController controller;
  final GeoPoint? position;
  final double? accuracyM;
  final List<GeoPoint> path;
  final bool following;
  final VoidCallback onUserMove;
  final VoidCallback onRecenter;
  final Widget status;

  /// Pause, resume and finish, floating at the bottom of the map.
  final Widget? controls;

  /// The walkie-talkie button, bottom left, so riders never switch tabs.
  final Widget? talk;

  @override
  Widget build(BuildContext context) {
    final here = position;
    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadius),
      child: Stack(
        children: [
          Positioned.fill(
            child: here == null
                ? const _FindingGps()
                : RepaintBoundary(
                    child: MapView(
                      controller: controller,
                      initialCenter: here,
                      initialZoom: 17,
                      onUserMove: onUserMove,
                      polylines: [
                        if (path.length >= 2)
                          MapPolyline(points: path, color: AppColors.data, width: 6),
                      ],
                      circles: [
                        if (accuracyM != null && accuracyM! > 0)
                          MapCircle(center: here, radiusM: accuracyM!, color: AppColors.tracking),
                      ],
                      markers: [MapMarker(id: 'me', point: here, size: 26, child: const _MeDot())],
                    ),
                  ),
          ),
          Positioned(
            top: Space.s,
            left: Space.s,
            right: 64,
            child: Align(alignment: Alignment.topLeft, child: status),
          ),
          if (controls != null) Positioned(left: 0, right: 0, bottom: Space.m, child: controls!),
          if (talk != null) Positioned(left: Space.m, bottom: Space.m + 6, child: talk!),
          if (here != null && !following)
            Positioned(
              top: Space.s,
              right: Space.s,
              child: FloatingActionButton.small(
                heroTag: null,
                tooltip: 'Follow my position',
                backgroundColor: AppColors.darkRaised,
                foregroundColor: Colors.white,
                onPressed: onRecenter,
                child: const Icon(Icons.navigation_rounded),
              ),
            ),
        ],
      ),
    );
  }
}

/// Where you are: volt (live) with an asphalt edge and a white halo, so it
/// reads on light map tiles.
class _MeDot extends StatelessWidget {
  const _MeDot();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Your position',
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.tracking,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.mapInk, width: 3),
        boxShadow: const [BoxShadow(color: Colors.white, spreadRadius: 3)],
      ),
    ),
  );
}

class _FindingGps extends StatelessWidget {
  const _FindingGps();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.darkRaised,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.satellite_alt_rounded, color: AppColors.onDarkMuted, size: 36),
          const SizedBox(height: Space.s),
          Text(
            'Finding your position…',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onDarkMuted),
          ),
        ],
      ),
    ),
  );
}
