import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/models/circle_alert.dart';
import '../features/alerts/alerts_screen.dart';
import '../features/circle/circle_controller.dart';
import '../features/circle/circle_screen.dart';
import '../features/feed/home_screen.dart';
import '../features/me/me_screen.dart';
import '../features/record/record_controller.dart';
import '../features/record/record_screen.dart';
import '../widgets/responsive.dart';
import '../widgets/visuals.dart';
import 'app_tab.dart';
import 'bottom_nav.dart';
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

  @override
  void initState() {
    super.initState();
    _shell.addListener(_onTabChanged);
    _alertSub = context.read<CircleController>().incomingAlerts.listen(_announce);
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
      context.read<CircleController>().markAlertsSeen();
    }
    _lastTab = tab;
    setState(() => _visited.add(tab));
  }

  void _announce(CircleAlert alert) {
    if (!mounted || _shell.tab == AppTab.alerts) return;
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
    final unseen = context.select<CircleController, int>((c) => c.unseenCount);
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
        SharingBanner(onTap: () => _shell.go(AppTab.circle)),
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
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  SideNav(
                    current: tab,
                    onSelect: _shell.go,
                    extended: c.maxWidth >= Breakpoints.large,
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
