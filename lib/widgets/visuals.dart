import 'package:flutter/material.dart';

import '../core/activity_type.dart';
import '../core/theme.dart';
import '../data/models/circle.dart';
import '../data/models/circle_alert.dart';
import '../data/models/user.dart';

extension ActivityTypeVisuals on ActivityType {
  IconData get icon => switch (this) {
        ActivityType.cycling => Icons.directions_bike_rounded,
        ActivityType.motorcycling => Icons.two_wheeler_rounded,
        ActivityType.driving => Icons.directions_car_rounded,
      };
}

extension VehicleTypeVisuals on VehicleType {
  IconData get icon => switch (this) {
        VehicleType.bike => Icons.pedal_bike_rounded,
        VehicleType.motorbike => Icons.two_wheeler_rounded,
        VehicleType.car => Icons.directions_car_rounded,
      };
}

extension MemberStatusVisuals on MemberStatus {
  Color get color => switch (this) {
        MemberStatus.tracking => AppColors.tracking,
        MemberStatus.alert => AppColors.alert,
        MemberStatus.parked || MemberStatus.paused => AppColors.parked,
      };
}

extension AlertTypeVisuals on AlertType {
  IconData get icon => switch (this) {
        AlertType.geofence => Icons.wrong_location_outlined,
        AlertType.motion => Icons.vibration_rounded,
        AlertType.lowbattery => Icons.battery_alert_rounded,
        AlertType.sos => Icons.sos_rounded,
      };

  Color get color =>
      this == AlertType.lowbattery ? AppColors.caution : AppColors.alert;
}

/// Rounded tinted square holding an icon, used as a list leading.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.color = AppColors.accent,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      );
}
