import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models/circle.dart';
import '../../data/models/circle_alert.dart';
import '../../shell/app_tab.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/responsive.dart';
import '../circle/circle_controller.dart';
import 'alert_card.dart';
import 'alert_notifier.dart';
import 'alerts_controller.dart';

/// Every alert from my circles, newest first, with filters.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  AlertScope _scope = AlertScope.all;
  AlertType? _type;
  AlertPeriod _period = AlertPeriod.any;

  bool get _filtered => _scope != AlertScope.all || _type != null || _period != AlertPeriod.any;

  @override
  void initState() {
    super.initState();
    context.read<AlertNotifier>().refresh();
  }

  void _clear() => setState(() {
    _scope = AlertScope.all;
    _type = null;
    _period = AlertPeriod.any;
  });

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<AlertsController>();
    final circle = context.select<CircleController, Circle?>((c) => c.circle);
    final scope = circle == null && _scope == AlertScope.circle ? AlertScope.all : _scope;
    final list = alerts.filtered(scope: scope, circleId: circle?.id, type: _type, period: _period);
    final t = Theme.of(context).textTheme;

    Widget body;
    if (!alerts.loaded) {
      body = const Center(child: CircularProgressIndicator.adaptive());
    } else if (alerts.all.isEmpty) {
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
      body = PageListView(
        children: [
          if (circle != null) const _NotificationsCard(),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AlertScope>(
              showSelectedIcon: false,
              segments: [
                for (final s in AlertScope.values)
                  if (s != AlertScope.circle || circle != null)
                    ButtonSegment(value: s, label: Text(s.label)),
              ],
              selected: {scope},
              onSelectionChanged: (s) => setState(() => _scope = s.first),
            ),
          ),
          const SizedBox(height: Space.s),
          Wrap(
            spacing: Space.s,
            runSpacing: Space.xs,
            children: [
              _MenuChip<AlertType?>(
                label: _type?.label ?? 'Any type',
                active: _type != null,
                values: const [null, ...AlertType.values],
                labelOf: (v) => v?.label ?? 'Any type',
                onSelected: (v) => setState(() => _type = v),
              ),
              _MenuChip<AlertPeriod>(
                label: _period.label,
                active: _period != AlertPeriod.any,
                values: AlertPeriod.values,
                labelOf: (v) => v.label,
                onSelected: (v) => setState(() => _period = v),
              ),
              if (_filtered) TextButton(onPressed: _clear, child: const Text('Clear')),
            ],
          ),
          const SizedBox(height: Space.m),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xl),
              child: Text(
                'No alerts match these filters.',
                textAlign: TextAlign.center,
                style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
            ),
          for (final a in list) ...[
            AlertCard(key: ValueKey(a.id), alert: a, myUid: alerts.uid),
            const SizedBox(height: 12),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: body,
    );
  }
}

class _MenuChip<T> extends StatelessWidget {
  const _MenuChip({
    required this.label,
    required this.active,
    required this.values,
    required this.labelOf,
    required this.onSelected,
  });

  final String label;
  final bool active;
  final List<T> values;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
    tooltip: 'Filter',
    position: PopupMenuPosition.under,
    onSelected: onSelected,
    itemBuilder: (_) => [for (final v in values) PopupMenuItem(value: v, child: Text(labelOf(v)))],
    child: Chip(
      avatar: Icon(Icons.filter_list_rounded, size: 18, color: active ? Colors.white : null),
      label: Text(label, style: TextStyle(color: active ? Colors.white : null)),
      backgroundColor: active ? AppColors.ink : null,
    ),
  );
}

/// Offers system notifications (with sound) for alerts while Apexo is in
/// the background; hidden once they are on.
class _NotificationsCard extends StatelessWidget {
  const _NotificationsCard();

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AlertNotifier>();
    if (notifier.enabled) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.m),
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.notifications_active_outlined, color: AppColors.ink),
          title: const Text('Get alerts as notifications'),
          subtitle: const Text('With sound, while Apexo is open or in the background.'),
          trailing: TextButton(onPressed: notifier.requestPermission, child: const Text('Turn on')),
        ),
      ),
    );
  }
}
