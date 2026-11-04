import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/circle.dart';
import '../../data/models/user.dart';
import '../../data/repository.dart';
import '../circle/my_member_docs.dart';

/// My vehicles, the active one, and the vehicle shown on my member pin in
/// every circle (kept in step with the active vehicle and its status).
class VehiclesController extends ChangeNotifier {
  VehiclesController(this._repo) {
    myDocs = MyMemberDocs(_repo, _syncPins);
    _authSub = _repo.authStateChanges().listen(_onUser);
  }

  final AppRepository _repo;
  late final MyMemberDocs myDocs;
  late final StreamSubscription<AppUser?> _authSub;
  StreamSubscription<List<Vehicle>>? _sub;
  AppUser? _user;
  List<Vehicle> _vehicles = const [];
  bool _loaded = false;

  AppUser? get user => _user;
  bool get loaded => _loaded;
  List<Vehicle> get vehicles => _vehicles;

  /// The chosen vehicle, else the first one.
  Vehicle? get active {
    if (_vehicles.isEmpty) return null;
    final id = _user?.activeVehicleId ?? '';
    return _vehicles.where((v) => v.id == id).firstOrNull ?? _vehicles.first;
  }

  /// Ids of the circles I am in (from my member docs).
  List<String> get circleIds => [for (final e in myDocs.entries) e.key];

  void _onUser(AppUser? user) {
    final changed = user?.uid != _user?.uid;
    _user = user;
    if (changed) {
      _sub?.cancel();
      _vehicles = const [];
      _loaded = false;
      myDocs.watch(user?.uid);
      if (user != null) {
        _sub = _repo.watchVehicles(user.uid).listen((list) {
          _vehicles = list;
          _loaded = true;
          _syncPins();
          notifyListeners();
        });
      }
    }
    _syncPins();
    notifyListeners();
  }

  /// Adds (empty [Vehicle.id]) or updates a vehicle; returns the saved one.
  Future<Vehicle> save(Vehicle v) async {
    final uid = _requireUid();
    final saved = v.id.isNotEmpty
        ? v
        : Vehicle(id: 'v-${clock.now().microsecondsSinceEpoch}', type: v.type, name: v.name);
    await _repo.saveVehicle(uid, saved);
    if (_vehicles.isEmpty) await setActive(saved.id);
    return saved;
  }

  /// A guarded vehicle cannot be deleted; disarm it first.
  Future<void> delete(String vehicleId) async {
    final v = _vehicles.where((v) => v.id == vehicleId).firstOrNull;
    if (v == null || v.status != VehicleStatus.ok) return;
    await _repo.deleteVehicle(_requireUid(), vehicleId);
  }

  Future<void> setActive(String vehicleId) =>
      _repo.updateProfile(_requireUid(), activeVehicleId: vehicleId);

  String _requireUid() => _user?.uid ?? (throw StateError('Signed out'));

  /// Writes my pin's vehicle only where it differs, so echoes of my own
  /// writes settle at once.
  void _syncPins() {
    // Before the list arrives, "no vehicle" would wrongly clear my pins.
    if (!_loaded) return;
    final v = active;
    final pin = v == null ? null : MemberVehicle(type: v.type, name: v.name, status: v.status);
    for (final e in myDocs.entries.toList()) {
      final now = e.value.vehicle;
      final same = pin == null
          ? now == null
          : now != null && now.type == pin.type && now.name == pin.name && now.status == pin.status;
      if (same) continue;
      _repo.updateMember(e.key, _withVehicle(e.value, pin));
    }
  }

  /// copyWith cannot clear the vehicle, so rebuild when it goes away.
  static Member _withVehicle(Member m, MemberVehicle? pin) => pin != null
      ? m.copyWith(vehicle: pin)
      : Member(
          uid: m.uid,
          displayName: m.displayName,
          lat: m.lat,
          lng: m.lng,
          ts: m.ts,
          speedKmh: m.speedKmh,
          heading: m.heading,
          battery: m.battery,
          status: m.status,
          sharing: m.sharing,
        );

  @override
  void dispose() {
    _authSub.cancel();
    _sub?.cancel();
    myDocs.cancel();
    super.dispose();
  }
}
