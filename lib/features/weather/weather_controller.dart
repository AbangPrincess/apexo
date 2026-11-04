import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../core/geo.dart';
import '../../core/weather.dart';
import '../../data/models/activity.dart';
import '../../data/weather_source.dart';

/// Where the forecast is for.
class WeatherPlace {
  const WeatherPlace(this.point, this.label, {this.isDefault = false});

  /// Used in demo mode and whenever location access is not granted.
  static const koronadal = WeatherPlace(GeoPoint(6.50, 124.85), 'Koronadal City', isDefault: true);

  final GeoPoint point;
  final String label;
  final bool isDefault;
}

/// Latest forecast, cached in memory for [maxAge]. Nothing is written to
/// disk or browser storage. When a refresh fails the last result stays.
class WeatherController extends ChangeNotifier {
  WeatherController(this._source, {this.devicePosition});

  static const maxAge = Duration(minutes: 15);

  final WeatherSource _source;

  /// Device position if location access is already granted, else null.
  /// Null (demo mode) always uses Koronadal City.
  final Future<GeoPoint?> Function()? devicePosition;

  Weather? _weather;
  WeatherPlace _place = WeatherPlace.koronadal;
  DateTime? _updatedAt;
  bool _failed = false;
  bool _loading = false;
  bool _disposed = false;
  Future<void>? _inFlight;

  Weather? get weather => _weather;
  WeatherPlace get place => _place;
  DateTime? get updatedAt => _updatedAt;
  bool get loading => _loading;

  /// The last refresh failed (offline or service down).
  bool get failed => _failed;
  bool get isFresh {
    final at = _updatedAt;
    return at != null && clock.now().difference(at) < maxAge;
  }

  /// Fetches unless the cache is fresh. Calls during a fetch share it.
  Future<void> load({bool force = false}) {
    if (!force && isFresh) return Future.value();
    return _inFlight ??= _fetch().whenComplete(() => _inFlight = null);
  }

  Future<void> _fetch() async {
    _loading = true;
    // Not synchronously: load() may run while a widget is building.
    scheduleMicrotask(_notify);
    try {
      final pos = await devicePosition?.call();
      final place = pos == null ? WeatherPlace.koronadal : WeatherPlace(pos, 'Your location');
      final w = await _source.fetch(place.point);
      _weather = w;
      _place = place;
      _updatedAt = clock.now();
      _failed = false;
    } catch (_) {
      _failed = true;
    }
    _loading = false;
    _notify();
  }

  /// Like [load], but a forecast for the default place is fetched again when
  /// the device position may now be known (location access was just given).
  Future<void> refreshForDevice() => load(force: _place.isDefault && devicePosition != null);

  /// Snapshot stored with an activity that started at [t].
  WeatherSnapshot? snapshotAt(DateTime t) {
    final c = _weather?.conditionsAt(t);
    if (c == null) return null;
    return WeatherSnapshot(tempC: c.tempC, windKmh: c.windKmh, code: c.code);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
