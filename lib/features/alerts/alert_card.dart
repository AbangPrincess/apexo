import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models/circle_alert.dart';
import '../../shell/app_tab.dart';
import '../../widgets/time_ago.dart';
import '../../widgets/visuals.dart';
import 'alert_actions.dart';
import 'alert_dialog.dart';
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

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: BorderSide(color: urgent ? a.type.color.withValues(alpha: 0.4) : AppColors.hairline),
      ),
      child: InkWell(
        onTap: theft ? () => viewAlertOnMap(context, shell, a) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.m, Space.m, Space.m, Space.s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.message, style: t.titleMedium),
                        const SizedBox(height: 2),
                        Text(alertDetail(a), style: t.bodyMedium),
                        const SizedBox(height: Space.xs),
                        TimeAgo(
                          a.ts,
                          suffix: ' · $status',
                          style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (a.open) ...[
                const SizedBox(height: Space.xs),
                Wrap(
                  spacing: Space.xs,
                  children: [
                    TextButton.icon(
                      onPressed: () => viewAlertOnMap(context, shell, a),
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('View on map'),
                    ),
                    TextButton.icon(
                      onPressed: () => navigateToAlert(context, a),
                      icon: const Icon(Icons.directions_outlined, size: 18),
                      label: const Text('Navigate'),
                    ),
                    if (mine)
                      TextButton(
                        onPressed: () => markRecovered(context, a),
                        child: const Text('Mark recovered'),
                      )
                    else if (!acked)
                      TextButton(
                        onPressed: () => context.read<AlertsController>().ack(a),
                        child: const Text("It's me"),
                      ),
                  ],
                ),
              ] else
                const SizedBox(height: Space.s),
            ],
          ),
        ),
      ),
    );
  }
}
