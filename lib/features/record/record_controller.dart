import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;

import '../../core/activity_summary.dart';
import '../../core/activity_type.dart';
import '../../core/geo.dart';
import '../../core/polyline.dart';
import '../../core/ride_tracker.dart';
import '../../core/screen_awake.dart';
import '../../core/stats.dart';
import '../../data/models/activity.dart';
import '../../data/models/user.dart';
import '../../data/repository.dart';
import '../weather/weather_controller.dart';
import 'location_source.dart';

/// Live recording. Lives above the tabs so a ride keeps recording while the
/// rider looks at other screens.
class RecordController extends ChangeNotifier {
  RecordController(this._repo, {required this.device, required this.simulator, this.weather})
    : useSimulated = _repo.isDemo {
    _authSub = _repo.authStateChanges().listen((u) {
      if (u == null && isActive) discard();
    });
    // A web page stops while hidden (a locked iPhone, another app).
    if (kIsWeb) {
      _life = AppLifecycleListener(onHide: () => _hiddenAt = clock.now(), onShow: _onShow);
    }
  }

  final AppRepository _repo;
  final LocationSource device;
  final LocationSource simulator;

  /// Supplies the weather snapshot saved with each activity.
  final WeatherController? weather;
  late final StreamSubscription<AppUser?> _authSub;
  AppLifecycleListener? _life;
  DateTime? _hiddenAt;

  /// Demo backend defaults to simulated GPS; it can be switched off.
  bool useSimulated;

  RideTracker? _tracker;
  StreamSubscription<Fix>? _fixes;
  Timer? _clock;
  String? _error;
  bool _starting = false;

  LocationSource get source => useSimulated ? simulator : device;
  RideState get state => _tracker?.state ?? RideState.idle;
  bool get isActive =>
      state == RideState.recording || state == RideState.paused || state == RideState.autoPaused;
  bool get starting => _starting;
  ActivityType? get type => _tracker?.type;
  String? get error => _error;

  Duration get movingTime => _tracker?.movingTimeAt(clock.now()) ?? Duration.zero;
  double get distanceM => _tracker?.distanceM ?? 0;
  double get currentKmh => _tracker?.currentKmh ?? 0;
  double get avgKmh => _tracker?.avgKmhAt(clock.now()) ?? 0;
  List<GeoPoint> get path => _tracker?.path ?? const [];

  /// Where the phone is now, moving or not, and how sure the GPS is.
  GeoPoint? get position => _tracker?.position;
  double? get accuracyM => _tracker?.accuracyM;

  /// Recording, but no real movement yet.
  bool get waiting => _tracker?.waiting ?? false;

  void setSimulated(bool value) {
    if (isActive || value == useSimulated) return;
    useSimulated = value;
    notifyListeners();
  }

  Future<bool> start(ActivityType type) async {
    if (isActive || _starting) return false;
    _starting = true;
    _error = null;
    notifyListeners();
    final access = await source.ensureAccess();
    _starting = false;
    if (access != LocationAccess.granted) {
      _error = switch (access) {
        LocationAccess.serviceOff => 'Turn on location services to record.',
        LocationAccess.deniedForever =>
          'Location access is blocked. Allow it in Settings to record.',
        _ => 'Apexo needs location access to record your route.',
      };
      notifyListeners();
      return false;
    }
    // Warms the forecast so the snapshot reflects the start of the ride.
    weather?.refreshForDevice();
    final tracker = _tracker = RideTracker(type)..start(clock.now());
    _fixes = source
        .fixes(type)
        .listen(
          (fix) {
            if (tracker.addFix(fix)) notifyListeners();
          },
          onError: (Object _) {
            _error = 'GPS signal lost. Recording continues when it comes back.';
            notifyListeners();
          },
        );
    // Ticks the on-screen clock between fixes.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
    // Phones record with the screen locked; the web keeps it on instead.
    keepScreenAwake(true);
    notifyListeners();
    return true;
  }

  void pause() {
    _tracker?.pause(clock.now());
    notifyListeners();
  }

  void resume() {
    _tracker?.resume(clock.now());
    notifyListeners();
  }

  /// Stops recording and returns the activity to review, or null if nothing
  /// was recorded.
  Activity? finish() {
    final tracker = _tracker;
    if (tracker == null) return null;
    final now = clock.now();
    _stopStreams();
    tracker.finish(now);
    notifyListeners();
    final start = tracker.startedAt ?? now;
    final moving = tracker.movingTimeAt(now).inSeconds;
    return Activity(
      id: 'a-${now.millisecondsSinceEpoch}',
      type: tracker.type,
      title: autoTitle(tracker.type, start),
      startedAt: start,
      endedAt: now,
      distanceM: tracker.distanceM,
      movingSec: moving,
      avgKmh: tracker.avgKmhAt(now),
      maxKmh: tracker.maxKmh,
      path: encodePolyline(simplifyPath(tracker.path)),
      weather: weather?.snapshotAt(start),
    );
  }

  /// Saves the ride. True once it is uploaded; false when it is kept on
  /// this device (no connection) and uploads by itself later. Throws when
  /// saving fails, keeping the ride so it can be tried again.
  Future<bool> save(
    Activity draft, {
    required String title,
    required ActivityVisibility visibility,
  }) async {
    final uid = _repo.currentUser?.uid;
    if (uid == null) throw StateError('Signed out');
    final cleanTitle = title.trim().isEmpty ? draft.title : title.trim();
    final uploaded = await _repo.saveActivity(
      uid,
      draft.copyWith(title: cleanTitle, visibility: visibility),
    );
    _reset();
    return uploaded;
  }

  void discard() {
    _stopStreams();
    _reset();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Back on screen after the page was hidden: a web page records nothing
  /// then, so say so instead of leaving a silent gap.
  void _onShow() {
    final at = _hiddenAt;
    _hiddenAt = null;
    if (at == null || !isActive || state == RideState.paused) return;
    final gap = clock.now().difference(at);
    if (gap < const Duration(seconds: 20)) return;
    final away = gap.inMinutes < 1 ? '${gap.inSeconds} s' : '${gap.inMinutes} min';
    _error =
        "The screen was locked or Apexo was hidden for $away, and a web page can't record "
        'then. Recording goes on from here; the Android app records with the screen locked.';
    notifyListeners();
  }

  void _stopStreams() {
    keepScreenAwake(false);
    _fixes?.cancel();
    _fixes = null;
    _clock?.cancel();
    _clock = null;
  }

  void _reset() {
    _tracker = null;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopStreams();
    _authSub.cancel();
    _life?.dispose();
    super.dispose();
  }
}
