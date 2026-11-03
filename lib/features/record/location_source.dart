import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../../core/activity_type.dart';
import '../../core/geo.dart';
import '../../core/stats.dart';

enum LocationAccess { granted, denied, deniedForever, serviceOff }

/// Where recording gets its fixes from: the device GPS or a simulation.
abstract interface class LocationSource {
  bool get simulated;

  /// True when access is already granted (no system dialog needed).
  Future<bool> hasAccess();
  Future<LocationAccess> ensureAccess();
  Stream<Fix> fixes(ActivityType type);
  Future<void> openSettings();
}

class DeviceLocationSource implements LocationSource {
  @override
  bool get simulated => false;

  @override
  Future<bool> hasAccess() async {
    final p = await geo.Geolocator.checkPermission();
    return p == geo.LocationPermission.always || p == geo.LocationPermission.whileInUse;
  }

  @override
  Future<LocationAccess> ensureAccess() async {
    if (!await geo.Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceOff;
    var p = await geo.Geolocator.checkPermission();
    if (p == geo.LocationPermission.denied) p = await geo.Geolocator.requestPermission();
    return switch (p) {
      geo.LocationPermission.always || geo.LocationPermission.whileInUse => LocationAccess.granted,
      geo.LocationPermission.deniedForever => LocationAccess.deniedForever,
      _ => LocationAccess.denied,
    };
  }

  /// Rough position for the weather, only when access is already granted
  /// (never shows the system dialog). Null when unavailable.
  Future<GeoPoint?> positionIfAllowed() async {
    try {
      if (!await hasAccess()) return null;
      final p = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return GeoPoint(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<Fix> fixes(ActivityType type) =>
      geo.Geolocator.getPositionStream(locationSettings: _settings(type)).map(
        (p) => Fix(
          p.latitude,
          p.longitude,
          p.timestamp,
          accuracyM: p.accuracy,
          speedMps: p.speed >= 0 ? p.speed : null,
        ),
      );

  @override
  Future<void> openSettings() => geo.Geolocator.openAppSettings();

  /// High accuracy, 5 m distance filter; Android shows the ongoing
  /// "Recording ride" notification so recording survives a locked screen.
  geo.LocationSettings _settings(ActivityType type) {
    const accuracy = geo.LocationAccuracy.high;
    if (kIsWeb) return geo.WebSettings(accuracy: accuracy, distanceFilter: 5);
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => geo.AndroidSettings(
        accuracy: accuracy,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: const geo.ForegroundNotificationConfig(
          notificationTitle: 'Recording ride',
          notificationText: 'Apexo is recording your route.',
          notificationChannelName: 'Recording',
          enableWakeLock: true,
          setOngoing: true,
        ),
      ),
      TargetPlatform.iOS || TargetPlatform.macOS => geo.AppleSettings(
        accuracy: accuracy,
        distanceFilter: 5,
        activityType: type == ActivityType.cycling
            ? geo.ActivityType.fitness
            : geo.ActivityType.automotiveNavigation,
        showBackgroundLocationIndicator: true,
      ),
      _ => const geo.LocationSettings(accuracy: accuracy, distanceFilter: 5),
    };
  }
}

/// Demo GPS: a gentle loop around Koronadal with a short stop every
/// 90 s, so auto-pause can be seen without leaving the desk.
class SimulatedLocationSource implements LocationSource {
  SimulatedLocationSource({
    this.start = const GeoPoint(6.5035, 124.8445),
    this.interval = const Duration(seconds: 1),
  });

  final GeoPoint start;
  final Duration interval;

  @override
  bool get simulated => true;

  @override
  Future<bool> hasAccess() async => true;

  @override
  Future<LocationAccess> ensureAccess() async => LocationAccess.granted;

  @override
  Future<void> openSettings() async {}

  @override
  Stream<Fix> fixes(ActivityType type) {
    final cruise = switch (type) {
      ActivityType.cycling => 6.0,
      ActivityType.motorcycling => 11.0,
      ActivityType.driving => 13.0,
    };
    Timer? timer;
    var step = 0;
    var heading = 30.0;
    var pos = start;
    late final StreamController<Fix> out;
    out = StreamController<Fix>(
      onListen: () => timer = Timer.periodic(interval, (_) {
        step++;
        final stopped = step % 90 >= 60 && step % 90 < 75;
        final v = stopped ? 0.0 : cruise * (0.85 + 0.15 * math.sin(step / 5));
        heading += 1.2 + 2 * math.sin(step / 13);
        final rad = heading * math.pi / 180;
        final secs = interval.inMilliseconds / 1000;
        pos = offsetM(pos, northM: v * secs * math.cos(rad), eastM: v * secs * math.sin(rad));
        out.add(Fix(pos.lat, pos.lng, clock.now(), accuracyM: 5, speedMps: v));
      }),
      onCancel: () => timer?.cancel(),
    );
    return out.stream;
  }
}
