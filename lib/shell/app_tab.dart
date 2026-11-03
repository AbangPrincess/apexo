import 'package:flutter/material.dart';

enum AppTab {
  home('Home', Icons.home_outlined, Icons.home_rounded),
  circle('Circle', Icons.people_outline_rounded, Icons.people_rounded),
  record('Record', Icons.radio_button_checked_rounded, Icons.radio_button_checked_rounded),
  alerts('Alerts', Icons.notifications_none_rounded, Icons.notifications_rounded),
  me('Me', Icons.person_outline_rounded, Icons.person_rounded);

  const AppTab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Lets any screen switch tabs, e.g. an empty state's "Start recording".
class ShellController extends ChangeNotifier {
  AppTab _tab = AppTab.home;

  AppTab get tab => _tab;

  void go(AppTab tab) {
    if (tab == _tab) return;
    _tab = tab;
    notifyListeners();
  }
}
