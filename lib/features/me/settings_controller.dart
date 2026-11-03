import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/activity_type.dart';
import '../../core/units.dart';
import '../../data/models/map_read.dart';
import '../../data/models/user.dart';
import '../../data/repository.dart';

/// Units and default activity. They live on the user profile (synced); only
/// these two non-sensitive values are cached on the device so the UI starts
/// with them.
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs, this._repo) {
    _units = readEnum(Units.values, _prefs.getString(_kUnits), Units.km);
    _activity = readEnum(ActivityType.values, _prefs.getString(_kActivity), ActivityType.cycling);
    _sub = _repo.authStateChanges().listen(_onUser);
  }

  static const _kUnits = 'units';
  static const _kActivity = 'defaultActivity';

  final SharedPreferences _prefs;
  final AppRepository _repo;
  late final StreamSubscription<AppUser?> _sub;
  late Units _units;
  late ActivityType _activity;
  String? _uid;

  Units get units => _units;
  ActivityType get defaultActivity => _activity;

  void _onUser(AppUser? user) {
    _uid = user?.uid;
    if (user == null) return;
    if (_repo.isDemo) {
      // The demo backend resets on reload, so this device's choice wins.
      if (user.units != _units || user.defaultActivity != _activity) {
        _repo.updateProfile(user.uid, units: _units, defaultActivity: _activity);
      }
      return;
    }
    if (user.units != _units || user.defaultActivity != _activity) {
      _units = user.units;
      _activity = user.defaultActivity;
      _cache();
      notifyListeners();
    }
  }

  Future<void> setUnits(Units value) async {
    if (value == _units) return;
    _units = value;
    notifyListeners();
    await _cache();
    if (_uid != null) await _repo.updateProfile(_uid!, units: value);
  }

  Future<void> setDefaultActivity(ActivityType value) async {
    if (value == _activity) return;
    _activity = value;
    notifyListeners();
    await _cache();
    if (_uid != null) await _repo.updateProfile(_uid!, defaultActivity: value);
  }

  Future<void> _cache() async {
    await _prefs.setString(_kUnits, _units.name);
    await _prefs.setString(_kActivity, _activity.name);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
