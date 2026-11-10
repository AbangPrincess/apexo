import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/units.dart';
import '../../data/models/circle_alert.dart';
import '../../shell/app_tab.dart';
import '../../widgets/time_ago.dart';
import '../../widgets/visuals.dart';
import '../me/settings_controller.dart';
import 'alert_actions.dart';
import 'alert_buttons.dart';
import 'alert_dialog.dart';
import 'alert_heading.dart';
import 'alerts_controller.dart';

class AlertCard extends StatelessWidget {
  const AlertCard({super.key, required this.alert, required this.myUid});

  final CircleAlert alert;
  final String? myUid;

  @override
  Widget build(BuildContext context) {
    final a = alert;
    final t = Theme.of(context).textTheme;
    final mine = a.ownerUid == myUid;
    final acked = myUid != null && a.ackBy.contains(myUid);
    final theft = a.type == AlertType.geofence || a.type == AlertType.motion;
    final urgent = a.open && !mine && !acked;
    final status = [
      a.type.label,
      if (a.recoveredAt != null) 'Recovered' else if (acked) 'Seen',
    ].join(' · ');
    final shell = context.read<ShellController>();
    final units = context.select<SettingsController, Units>((s) => s.units);
    final (third, onThird) = mine
        ? ('Mark recovered', () => markRecovered(context, a))
        : !acked
        ? ("It's me", () => context.read<AlertsController>().ack(a))
        : (null, null);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: BorderSide(color: urgent ? a.type.color.withValues(alpha: 0.4) : AppColors.hairline),
      ),
      child: InkWell(
        onTap: theft ? () => viewAlertOnMap(context, shell, a) : null,
        // 16 pt on every side, below the last button too. The buttons span
        // the card, the same 16 pt from both edges.
        child: Padding(
          padding: const EdgeInsets.all(Space.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconTile(
                    icon: a.type.icon,
                    color: a.recoveredAt == null ? a.type.color : AppColors.parked,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AlertHeading(
                      a.message,
                      alertDetail(a, units),
                      titleStyle: t.titleMedium!,
                      detailStyle: t.bodyMedium!,
                      meta: TimeAgo(
                        a.ts,
                        suffix: ' · $status',
                        style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                ],
              ),
              if (a.open) ...[
                const SizedBox(height: Space.m),
                AlertActions(
                  onViewMap: () => viewAlertOnMap(context, shell, a),
                  onNavigate: () => navigateToAlert(context, a),
                  third: third,
                  onThird: onThird,
                  quietThird: !mine,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
