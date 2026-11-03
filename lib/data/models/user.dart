import '../../core/activity_type.dart';
import '../../core/geo.dart';
import '../../core/units.dart';
import 'map_read.dart';

/// users/{uid}. [emailVerified] comes from auth and is not stored.
class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.createdAt,
    this.defaultActivity = ActivityType.cycling,
    this.units = Units.km,
    this.bio = '',
    this.hometown = '',
    this.photoUrl = '',
    this.coverUrl = '',
    this.emailVerified = true,
  });

  final String uid;
  final String displayName;
  final String email;
  final ActivityType defaultActivity;
  final Units units;
  final DateTime createdAt;
  final String bio;
  final String hometown;

  /// https URL or a small data: URI. Empty when not set.
  final String photoUrl;
  final String coverUrl;
  final bool emailVerified;

  String get initial {
    final n = displayName.trim();
    return n.isEmpty ? '?' : n[0].toUpperCase();
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> m, {bool emailVerified = true}) =>
      AppUser(
        uid: uid,
        displayName: readString(m['displayName'], 'Rider'),
        email: readString(m['email']),
        defaultActivity: readEnum(ActivityType.values, m['defaultActivity'], ActivityType.cycling),
        units: readEnum(Units.values, m['units'], Units.km),
        createdAt: readDate(m['createdAt']),
        bio: readString(m['bio']),
        hometown: readString(m['hometown']),
        photoUrl: readString(m['photoUrl']),
        coverUrl: readString(m['coverUrl']),
        emailVerified: emailVerified,
      );

  Map<String, dynamic> toMap() => {
    'displayName': displayName,
    'email': email,
    'defaultActivity': defaultActivity.name,
    'units': units.name,
    'createdAt': createdAt,
    'bio': bio,
    'hometown': hometown,
    'photoUrl': photoUrl,
    'coverUrl': coverUrl,
  };

  /// Pass an empty string to clear a text or photo field.
  AppUser copyWith({
    String? displayName,
    ActivityType? defaultActivity,
    Units? units,
    String? bio,
    String? hometown,
    String? photoUrl,
    String? coverUrl,
    bool? emailVerified,
  }) => AppUser(
    uid: uid,
    displayName: displayName ?? this.displayName,
    email: email,
    defaultActivity: defaultActivity ?? this.defaultActivity,
    units: units ?? this.units,
    createdAt: createdAt,
    bio: bio ?? this.bio,
    hometown: hometown ?? this.hometown,
    photoUrl: photoUrl ?? this.photoUrl,
    coverUrl: coverUrl ?? this.coverUrl,
    emailVerified: emailVerified ?? this.emailVerified,
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
