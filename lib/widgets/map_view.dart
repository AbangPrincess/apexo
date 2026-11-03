import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/geo.dart';

/// The only place that knows about the map package, so the provider can be
/// swapped (e.g. Google Maps in P7) without touching screens.
class MapView extends StatelessWidget {
  const MapView({
    super.key,
    required this.initialCenter,
    this.initialZoom = 14,
    this.fitPoints = const [],
    this.markers = const [],
    this.circles = const [],
    this.controller,
  });

  final GeoPoint initialCenter;
  final double initialZoom;

  /// When 2+ points are given the camera starts fitted to them.
  final List<GeoPoint> fitPoints;
  final List<MapMarker> markers;
  final List<MapCircle> circles;
  final MapViewController? controller;

  static LatLng _ll(GeoPoint p) => LatLng(p.lat, p.lng);

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller?._map,
      options: MapOptions(
        initialCenter: _ll(initialCenter),
        initialZoom: initialZoom,
        initialCameraFit: fitPoints.length < 2
            ? null
            : CameraFit.coordinates(
                coordinates: fitPoints.map(_ll).toList(),
                padding: const EdgeInsets.all(64),
                maxZoom: 16,
              ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.pedaltrack.pedaltrack',
          maxNativeZoom: 19,
        ),
        if (circles.isNotEmpty)
          CircleLayer(circles: [
            for (final c in circles)
              CircleMarker(
                point: _ll(c.center),
                radius: c.radiusM,
                useRadiusInMeter: true,
                color: c.color.withValues(alpha: 0.12),
                borderColor: c.color,
                borderStrokeWidth: 2,
              ),
          ]),
        MarkerLayer(markers: [
          for (final m in markers)
            Marker(
              key: ValueKey(m.id),
              point: _ll(m.point),
              width: m.size,
              height: m.size,
              child: m.child,
            ),
        ]),
        const _Attribution(),
      ],
    );
  }
}

/// Compact tile credit (required by the OpenStreetMap licence) that never
/// overflows on narrow phones.
class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                '© OpenStreetMap contributors',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Color(0xFF6B6B76)),
              ),
            ),
          ),
        ),
      );
}

class MapMarker {
  const MapMarker({required this.id, required this.point, required this.child, this.size = 48});

  final String id;
  final GeoPoint point;
  final Widget child;
  final double size;
}

class MapCircle {
  const MapCircle({required this.center, required this.radiusM, required this.color});

  final GeoPoint center;
  final double radiusM;
  final Color color;
}

/// Camera commands for [MapView].
class MapViewController {
  final MapController _map = MapController();

  void focus(GeoPoint p, {double zoom = 16}) => _map.move(LatLng(p.lat, p.lng), zoom);

  void dispose() => _map.dispose();
}
