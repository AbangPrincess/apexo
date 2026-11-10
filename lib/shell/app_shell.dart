import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/models/circle_alert.dart';
import '../features/alerts/alert_actions.dart';
import '../features/alerts/alert_dialog.dart';
import '../features/alerts/alert_notifier.dart';
import '../features/alerts/alerts_controller.dart';
import '../features/alerts/alerts_screen.dart';
import '../features/circle/circle_screen.dart';
import '../features/guard/guard_screen.dart';
import '../features/feed/home_screen.dart';
import '../features/me/me_screen.dart';
import '../features/me/settings_controller.dart';
import '../features/record/record_controller.dart';
import '../features/record/record_screen.dart';
import '../widgets/responsive.dart';
import '../widgets/visuals.dart';
import 'app_tab.dart';
import 'bottom_nav.dart';
import 'offline_bar.dart';
import 'sharing_banner.dart';
import 'side_nav.dart';

/// Signed-in frame: bottom bar on phones, side rail on tablets and the web.
/// Tabs are built on first visit and then kept alive.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _shell = ShellController();
  final _visited = <AppTab>{AppTab.home};
  late AppTab _lastTab = _shell.tab;
  StreamSubscription<CircleAlert>? _alertSub;

  bool _dialogOpen = false;

  /// The rail is open on wide screens unless folded with the Apexo mark.
  bool? _railExtended;

  @override
  void initState() {
    super.initState();
    _shell.addListener(_onTabChanged);
    _alertSub = context.read<AlertsController>().incoming.listen(_announce);
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    _shell.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    final tab = _shell.tab;
    if (tab == AppTab.alerts || _lastTab == AppTab.alerts) {
      context.read<AlertsController>().markSeen();
    }
    _lastTab = tab;
    setState(() => _visited.add(tab));
  }

  /// Someone else's alert: a system notification with sound (it also works
  /// while Apexo is in the background), plus a dialog for theft alerts.
  Future<void> _announce(CircleAlert alert) async {
    if (!mounted) return;
    final alerts = context.read<AlertsController>();
    context.read<AlertNotifier>().show(
      alert,
      alertDetail(alert, context.read<SettingsController>().units),
    );
    if (alert.type == AlertType.lowbattery) return _snack(alert);
    // One dialog at a time; the Alerts tab lists the rest.
    if (_dialogOpen) return;
    _dialogOpen = true;
    final choice = await showIncomingAlert(context, alert);
    _dialogOpen = false;
    if (!mounted) return;
    final latest = alerts.byId(alert.id) ?? alert;
    switch (choice) {
      case AlertChoice.viewOnMap:
        viewAlertOnMap(context, _shell, latest);
      case AlertChoice.navigate:
        await navigateToAlert(context, latest);
      case AlertChoice.itsMe:
        await alerts.ack(latest);
      case null:
        break;
    }
  }

  void _snack(CircleAlert alert) {
    if (_shell.tab == AppTab.alerts) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Row(
            children: [
              Icon(alert.type.icon, color: alert.type.color),
              const SizedBox(width: Space.m),
              Expanded(child: Text(alert.message)),
            ],
          ),
          action: SnackBarAction(label: 'View', onPressed: () => _shell.go(AppTab.alerts)),
        ),
      );
  }

  Widget _page(AppTab tab) => switch (tab) {
    AppTab.home => const HomeScreen(),
    AppTab.circle => const CircleScreen(),
    AppTab.record => const RecordScreen(),
    AppTab.alerts => const AlertsScreen(),
    AppTab.me => const MeScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final unseen = context.select<AlertsController, int>((c) => c.unseenCount);
    final recording = context.select<RecordController, bool>((r) => r.isActive);
    final tab = _shell.tab;
    final badge = tab == AppTab.alerts ? 0 : unseen;
    final body = Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: tab.index,
            children: [
              for (final t in AppTab.values)
                _visited.contains(t) ? _page(t) : const SizedBox.shrink(),
            ],
          ),
        ),
        const OfflineBar(),
        SharingBanner(onSharing: () => _shell.go(AppTab.circle), onGuard: () => openGuard(context)),
      ],
    );

    return ChangeNotifierProvider.value(
      value: _shell,
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < Breakpoints.medium) {
            return Scaffold(
              body: body,
              bottomNavigationBar: BottomNav(
                current: tab,
                onSelect: _shell.go,
                alertCount: badge,
                recording: recording,
              ),
            );
          }
          final extended = _railExtended ?? c.maxWidth >= Breakpoints.large;
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  SideNav(
                    current: tab,
                    onSelect: _shell.go,
                    extended: extended,
                    onToggle: () => setState(() => _railExtended = !extended),
                    alertCount: badge,
                    recording: recording,
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
