import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models/circle.dart';
import '../../data/models/circle_alert.dart';
import '../../shell/app_tab.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/responsive.dart';
import '../../widgets/time_ago.dart';
import '../../widgets/visuals.dart';
import '../circle/circle_controller.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Select only what this screen shows, so live member moves do not rebuild it.
    final loaded = context.select<CircleController, bool>((c) => c.loaded);
    final circle = context.select<CircleController, Circle?>((c) => c.circle);
    final alerts = context.select<CircleController, List<CircleAlert>>((c) => c.alerts);
    final uid = context.select<CircleController, String?>((c) => c.uid);
    final t = Theme.of(context).textTheme;

    Widget body;
    if (!loaded) {
      body = const Center(child: CircularProgressIndicator.adaptive());
    } else if (alerts.isEmpty) {
      body = EmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'All quiet',
        message: circle == null
            ? 'Join or create a circle and guard alerts from its members will show up here.'
            : 'If a vehicle in ${circle.name} leaves its boundary or a phone runs low, you will see it here.',
        actionLabel: circle == null ? 'Go to Circle' : null,
        onAction: () => context.read<ShellController>().go(AppTab.circle),
      );
    } else {
      body = PageListView(children: [
        if (circle != null) ...[
          Text(circle.name, style: t.titleMedium),
          const SizedBox(height: Space.xs),
          Text('Alerts from members of this circle',
              style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: Space.m),
        ],
        for (final a in alerts) ...[
          _AlertCard(key: ValueKey(a.id), alert: a, seen: uid != null && a.ackBy.contains(uid)),
          const SizedBox(height: 12),
        ],
      ]);
    }

    return Scaffold(appBar: AppBar(title: const Text('Alerts')), body: body);
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({super.key, required this.alert, required this.seen});

  final CircleAlert alert;
  final bool seen;

  String get _detail => switch (alert.type) {
        AlertType.geofence => 'Moved ${alert.distanceM.round()} m from its boundary',
        AlertType.motion => 'Movement detected while guarded',
        AlertType.lowbattery => 'Guard may stop soon',
        AlertType.sos => 'Asked the circle for help',
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = t.bodySmall?.copyWith(color: AppColors.textMuted);
    final urgent = alert.type != AlertType.lowbattery && !seen;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: BorderSide(
          color: urgent ? alert.type.color.withValues(alpha: 0.4) : AppColors.hairline,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.m),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconTile(icon: alert.type.icon, color: alert.type.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.message, style: t.titleMedium),
                  const SizedBox(height: 2),
                  Text(_detail, style: t.bodyMedium),
                  const SizedBox(height: Space.xs),
                  TimeAgo(
                    alert.ts,
                    suffix: ' · ${alert.type.label}${seen ? ' · Seen' : ''}',
                    style: muted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
