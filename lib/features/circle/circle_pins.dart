import 'package:flutter/material.dart';

import '../../core/geo.dart';
import '../../core/theme.dart';
import '../../data/models/circle.dart';
import '../../data/models/circle_alert.dart';
import '../../widgets/map_view.dart';
import '../../widgets/member_avatar.dart';
import '../../widgets/visuals.dart';
import '../alerts/alert_dialog.dart';

/// Pins for the Circle map: open alerts (a missing vehicle's last spot),
/// sharing members, and my own unshared position from locate-me.
List<MapMarker> circlePins({
  required List<Member> members,
  required List<CircleAlert> openAlerts,
  required String? myUid,
  GeoPoint? here,
}) => [
  for (final a in openAlerts)
    MapMarker(
      id: 'alert-${a.id}',
      point: GeoPoint(a.lat, a.lng),
      size: 30,
      child: const AlertPin(),
    ),
  for (final m in members)
    MapMarker(
      id: m.uid,
      point: m.point,
      size: 52,
      child: MemberAvatar(
        initial: m.initial,
        ringColor: m.status.color,
        badge: m.vehicle?.type.icon,
        highlight: m.uid == myUid,
        outline: true,
        size: 48,
      ),
    ),
  if (here != null) MapMarker(id: 'here', point: here, size: 22, child: const _HereDot()),
];

class _HereDot extends StatelessWidget {
  const _HereDot();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'You are here (not shared)',
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.mapInk,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
    ),
  );
}
