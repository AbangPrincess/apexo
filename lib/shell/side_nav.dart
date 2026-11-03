import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/brand_mark.dart';
import 'app_tab.dart';

/// Tablet and web navigation: a rail with a Record action on top.
class SideNav extends StatelessWidget {
  const SideNav({
    super.key,
    required this.current,
    required this.onSelect,
    required this.extended,
    this.alertCount = 0,
    this.recording = false,
  });

  final AppTab current;
  final ValueChanged<AppTab> onSelect;
  final bool extended;
  final int alertCount;
  final bool recording;

  static const _railTabs = [AppTab.home, AppTab.circle, AppTab.alerts, AppTab.me];

  @override
  Widget build(BuildContext context) {
    final index = _railTabs.indexOf(current);
    return NavigationRail(
      extended: extended,
      minExtendedWidth: 232,
      labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
      selectedIndex: index < 0 ? null : index,
      onDestinationSelected: (i) => onSelect(_railTabs[i]),
      groupAlignment: -1,
      leading: Padding(
        padding: const EdgeInsets.only(top: Space.m, bottom: Space.l),
        child: Column(
          crossAxisAlignment: extended ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            BrandMark(showName: extended),
            const SizedBox(height: Space.l),
            _RecordAction(
              key: const ValueKey('nav-record'),
              extended: extended,
              selected: current == AppTab.record,
              recording: recording,
              onTap: () => onSelect(AppTab.record),
            ),
          ],
        ),
      ),
      destinations: [
        for (final tab in _railTabs)
          NavigationRailDestination(
            icon: Badge(
              key: ValueKey('nav-${tab.name}'),
              isLabelVisible: tab == AppTab.alerts && alertCount > 0,
              label: Text('$alertCount'),
              child: Icon(tab.icon),
            ),
            selectedIcon: Icon(tab.selectedIcon, key: ValueKey('nav-${tab.name}')),
            label: Text(tab.label),
          ),
      ],
    );
  }
}

class _RecordAction extends StatelessWidget {
  const _RecordAction({
    super.key,
    required this.extended,
    required this.selected,
    required this.recording,
    required this.onTap,
  });

  final bool extended;
  final bool selected;
  final bool recording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const icon = Icon(Icons.radio_button_checked_rounded);
    if (extended) {
      return SizedBox(
        width: 200,
        child: FilledButton.icon(
          onPressed: onTap,
          icon: icon,
          label: Text(recording ? 'Recording…' : 'Record'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            backgroundColor: recording ? AppColors.tracking : AppColors.accent,
            foregroundColor: recording ? AppColors.ink : Colors.white,
            side: selected ? const BorderSide(color: AppColors.accentSoft, width: 3) : null,
          ),
        ),
      );
    }
    return Tooltip(
      message: recording ? 'Recording in progress' : 'Record',
      child: IconButton.filled(
        onPressed: onTap,
        icon: icon,
        iconSize: 26,
        style: IconButton.styleFrom(
          minimumSize: const Size(56, 56),
          backgroundColor: recording ? AppColors.tracking : AppColors.accent,
          foregroundColor: recording ? AppColors.ink : Colors.white,
          side: selected ? const BorderSide(color: AppColors.accentSoft, width: 3) : null,
        ),
      ),
    );
  }
}
