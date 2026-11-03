import 'map_read.dart';

enum AlertType {
  geofence('Left boundary'),
  motion('Movement'),
  lowbattery('Low battery'),
  sos('SOS');

  const AlertType(this.label);
  final String label;
}

/// circles/{cid}/alerts/{id}
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
    this.ackBy = const [],
  });

  final String id;
  final AlertType type;
  final String ownerUid;
  final String vehicleName;
  final String message;
  final double lat;
  final double lng;

  /// Distance from the boundary center when the alert fired.
  final double distanceM;
  final DateTime ts;
  final List<String> ackBy;

  factory CircleAlert.fromMap(String id, Map<String, dynamic> m) => CircleAlert(
        id: id,
        type: readEnum(AlertType.values, m['type'], AlertType.geofence),
        ownerUid: readString(m['ownerUid']),
        vehicleName: readString(m['vehicleName']),
        message: readString(m['message']),
        lat: readDouble(m['lat']),
        lng: readDouble(m['lng']),
        distanceM: readDouble(m['distanceM']),
        ts: readDate(m['ts']),
        ackBy: readStringList(m['ackBy']),
      );

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'ownerUid': ownerUid,
        'vehicleName': vehicleName,
        'message': message,
        'lat': lat,
        'lng': lng,
        'distanceM': distanceM,
        'ts': ts,
        'ackBy': ackBy,
      };
}
