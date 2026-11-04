import 'map_read.dart';

enum AlertType {
  geofence('Left boundary'),
  motion('Movement'),
  lowbattery('Low battery'),
  sos('SOS');

  const AlertType(this.label);
  final String label;
}

/// circles/{cid}/alerts/{id}. One event is written to each of the owner's
/// circles under the same id; the owner keeps its position current while
/// the vehicle is missing.
class CircleAlert {
  const CircleAlert({
    required this.id,
    required this.type,
    required this.ownerUid,
    required this.vehicleName,
    required this.message,
    required this.lat,
    required this.lng,
    required this.distanceM,
    required this.ts,
    this.ownerName = '',
    this.vehicleId = '',
    this.radiusM = 0,
    this.recoveredAt,
    this.ackBy = const [],
  });

  final String id;
  final AlertType type;
  final String ownerUid;
  final String ownerName;
  final String vehicleId;
  final String vehicleName;
  final String message;
  final double lat;
  final double lng;

  /// Distance from the boundary center (latest known for a moving vehicle).
  final double distanceM;

  /// The boundary radius when it fired; 0 for non-geofence alerts.
  final double radiusM;
  final DateTime ts;

  /// Set when the owner marks the vehicle recovered.
  final DateTime? recoveredAt;
  final List<String> ackBy;

  /// A theft alert that has not been resolved.
  bool get open => recoveredAt == null && (type == AlertType.geofence || type == AlertType.motion);

  factory CircleAlert.fromMap(String id, Map<String, dynamic> m) => CircleAlert(
    id: id,
    type: readEnum(AlertType.values, m['type'], AlertType.geofence),
    ownerUid: readString(m['ownerUid']),
    ownerName: readString(m['ownerName']),
    vehicleId: readString(m['vehicleId']),
    vehicleName: readString(m['vehicleName']),
    message: readString(m['message']),
    lat: readDouble(m['lat']),
    lng: readDouble(m['lng']),
    distanceM: readDouble(m['distanceM']),
    radiusM: readDouble(m['radiusM']),
    ts: readDate(m['ts']),
    recoveredAt: readDateOrNull(m['recoveredAt']),
    ackBy: readStringList(m['ackBy']),
  );

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'ownerUid': ownerUid,
    'ownerName': ownerName,
    'vehicleId': vehicleId,
    'vehicleName': vehicleName,
    'message': message,
    'lat': lat,
    'lng': lng,
    'distanceM': distanceM,
    'radiusM': radiusM,
    'ts': ts,
    'recoveredAt': recoveredAt,
    'ackBy': ackBy,
  };

  CircleAlert copyWith({
    double? lat,
    double? lng,
    double? distanceM,
    DateTime? recoveredAt,
    List<String>? ackBy,
  }) => CircleAlert(
    id: id,
    type: type,
    ownerUid: ownerUid,
    ownerName: ownerName,
    vehicleId: vehicleId,
    vehicleName: vehicleName,
    message: message,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    distanceM: distanceM ?? this.distanceM,
    radiusM: radiusM,
    ts: ts,
    recoveredAt: recoveredAt ?? this.recoveredAt,
    ackBy: ackBy ?? this.ackBy,
  );
}
