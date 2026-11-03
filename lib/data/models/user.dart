import '../../core/activity_type.dart';
import '../../core/geo.dart';
import '../../core/units.dart';
import 'map_read.dart';

/// users/{uid}
class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.createdAt,
    this.defaultActivity = ActivityType.cycling,
    this.units = Units.km,
  });

  final String uid;
  final String displayName;
  final String email;
  final ActivityType defaultActivity;
  final Units units;
  final DateTime createdAt;

  String get initial {
    final n = displayName.trim();
    return n.isEmpty ? '?' : n[0].toUpperCase();
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> m) => AppUser(
        uid: uid,
        displayName: readString(m['displayName'], 'Rider'),
        email: readString(m['email']),
        defaultActivity:
            readEnum(ActivityType.values, m['defaultActivity'], ActivityType.cycling),
        units: readEnum(Units.values, m['units'], Units.km),
        createdAt: readDate(m['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'email': email,
        'defaultActivity': defaultActivity.name,
        'units': units.name,
        'createdAt': createdAt,
      };

  AppUser copyWith({String? displayName, ActivityType? defaultActivity, Units? units}) =>
      AppUser(
        uid: uid,
        displayName: displayName ?? this.displayName,
        email: email,
        defaultActivity: defaultActivity ?? this.defaultActivity,
        units: units ?? this.units,
        createdAt: createdAt,
      );
}

enum VehicleType {
  bike('Bike'),
  motorbike('Motorbike'),
  car('Car');

  const VehicleType(this.label);
  final String label;
}

enum VehicleStatus { ok, guarding, stolen }

/// users/{uid}/vehicles/{vid}
class Vehicle {
  const Vehicle({
    required this.id,
    required this.type,
    required this.name,
    this.status = VehicleStatus.ok,
    this.boundary,
    this.armedAt,
  });

  final String id;
  final VehicleType type;
  final String name;
  final VehicleStatus status;
  final Boundary? boundary;
  final DateTime? armedAt;

  factory Vehicle.fromMap(String id, Map<String, dynamic> m) {
    final b = readMap(m['boundary']);
    return Vehicle(
      id: id,
      type: readEnum(VehicleType.values, m['type'], VehicleType.bike),
      name: readString(m['name'], 'My vehicle'),
      status: readEnum(VehicleStatus.values, m['status'], VehicleStatus.ok),
      boundary: b == null ? null : Boundary.fromMap(b),
      armedAt: readDateOrNull(m['armedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'name': name,
        'status': status.name,
        'boundary': boundary?.toMap(),
        'armedAt': armedAt,
      };
}
