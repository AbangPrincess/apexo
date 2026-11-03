import '../../core/geo.dart';
import 'map_read.dart';
import 'user.dart';

/// circles/{cid}
class Circle {
  const Circle({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.ownerUid,
    required this.memberUids,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String inviteCode;
  final String ownerUid;
  final List<String> memberUids;
  final DateTime createdAt;

  factory Circle.fromMap(String id, Map<String, dynamic> m) => Circle(
    id: id,
    name: readString(m['name'], 'Circle'),
    inviteCode: readString(m['inviteCode']),
    ownerUid: readString(m['ownerUid']),
    memberUids: readStringList(m['memberUids']),
    createdAt: readDate(m['createdAt']),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'inviteCode': inviteCode,
    'ownerUid': ownerUid,
    'memberUids': memberUids,
    'createdAt': createdAt,
  };
}

enum MemberStatus {
  tracking('Moving'),
  parked('Parked'),
  alert('Alert'),
  paused('Sharing paused');

  const MemberStatus(this.label);
  final String label;
}

/// The vehicle summary shown on a member's pin.
class MemberVehicle {
  const MemberVehicle({required this.type, required this.name, this.status = VehicleStatus.ok});

  final VehicleType type;
  final String name;
  final VehicleStatus status;

  factory MemberVehicle.fromMap(Map<String, dynamic> m) => MemberVehicle(
    type: readEnum(VehicleType.values, m['type'], VehicleType.bike),
    name: readString(m['name']),
    status: readEnum(VehicleStatus.values, m['status'], VehicleStatus.ok),
  );

  Map<String, dynamic> toMap() => {'type': type.name, 'name': name, 'status': status.name};

  MemberVehicle withStatus(VehicleStatus s) => MemberVehicle(type: type, name: name, status: s);
}

/// circles/{cid}/members/{uid}
class Member {
  const Member({
    required this.uid,
    required this.displayName,
    required this.lat,
    required this.lng,
    required this.ts,
    this.speedKmh = 0,
    this.heading = 0,
    this.battery = 100,
    this.status = MemberStatus.parked,
    this.sharing = true,
    this.vehicle,
  });

  final String uid;
  final String displayName;
  final double lat;
  final double lng;
  final double speedKmh;
  final double heading;

  /// Battery percent, 0-100.
  final int battery;
  final MemberStatus status;
  final bool sharing;
  final DateTime ts;
  final MemberVehicle? vehicle;

  GeoPoint get point => GeoPoint(lat, lng);

  String get initial {
    final n = displayName.trim();
    return n.isEmpty ? '?' : n[0].toUpperCase();
  }

  factory Member.fromMap(String uid, Map<String, dynamic> m) {
    final v = readMap(m['vehicle']);
    return Member(
      uid: uid,
      displayName: readString(m['displayName'], 'Member'),
      lat: readDouble(m['lat']),
      lng: readDouble(m['lng']),
      speedKmh: readDouble(m['speedKmh']),
      heading: readDouble(m['heading']),
      battery: readInt(m['battery'], 100),
      status: readEnum(MemberStatus.values, m['status'], MemberStatus.paused),
      sharing: m['sharing'] == true,
      ts: readDate(m['ts']),
      vehicle: v == null ? null : MemberVehicle.fromMap(v),
    );
  }

  Map<String, dynamic> toMap() => {
    'displayName': displayName,
    'lat': lat,
    'lng': lng,
    'speedKmh': speedKmh,
    'heading': heading,
    'battery': battery,
    'status': status.name,
    'sharing': sharing,
    'ts': ts,
    'vehicle': vehicle?.toMap(),
  };

  Member copyWith({
    double? lat,
    double? lng,
    double? speedKmh,
    double? heading,
    int? battery,
    MemberStatus? status,
    bool? sharing,
    DateTime? ts,
    MemberVehicle? vehicle,
  }) => Member(
    uid: uid,
    displayName: displayName,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    speedKmh: speedKmh ?? this.speedKmh,
    heading: heading ?? this.heading,
    battery: battery ?? this.battery,
    status: status ?? this.status,
    sharing: sharing ?? this.sharing,
    ts: ts ?? this.ts,
    vehicle: vehicle ?? this.vehicle,
  );
}
