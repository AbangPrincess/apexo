import '../../core/geo.dart';
import '../../core/polyline.dart';
import 'activity.dart';
import 'map_read.dart';
import 'user.dart';

/// circles/{cid}/feed/{aid}: an activity a member shared with the circle.
/// The path is thinned to 25 m and the vehicle link is left out.
class SharedActivity {
  const SharedActivity({
    required this.ownerUid,
    required this.ownerName,
    required this.activity,
    required this.ts,
  });

  final String ownerUid;
  final String ownerName;
  final Activity activity;
  final DateTime ts;

  String get id => activity.id;

  factory SharedActivity.of(AppUser owner, Activity a, DateTime ts) {
    final summary = {
      ...a.toMap(),
      'path': encodePolyline(simplifyPath(a.points, minSpacingM: 25)),
      'visibility': ActivityVisibility.circles.name,
    }..remove('vehicleId');
    return SharedActivity(
      ownerUid: owner.uid,
      ownerName: owner.displayName,
      activity: Activity.fromMap(a.id, summary),
      ts: ts,
    );
  }

  factory SharedActivity.fromMap(String id, Map<String, dynamic> m) => SharedActivity(
    ownerUid: readString(m['ownerUid']),
    ownerName: readString(m['ownerName'], 'Member'),
    activity: Activity.fromMap(id, m),
    ts: readDate(m['ts']),
  );

  Map<String, dynamic> toMap() => {
    ...activity.toMap(),
    'ownerUid': ownerUid,
    'ownerName': ownerName,
    'ts': ts,
  };
}
