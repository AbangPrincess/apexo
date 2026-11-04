import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/brand_mark.dart';
import 'app_tab.dart';

/// Tablet and web navigation: a rail with a Record action on top. Tap the
/// Apexo mark to fold it to icons only, and again to open it.
class SideNav extends StatelessWidget {
  const SideNav({
    super.key,
    required this.current,
    required this.onSelect,
    required this.extended,
    required this.onToggle,
    this.alertCount = 0,
    this.recording = false,
  });

  final AppTab current;
  final ValueChanged<AppTab> onSelect;
  final bool extended;
  final VoidCallback onToggle;
  final int alertCount;
  final bool recording;

  static const _railTabs = [AppTab.home, AppTab.circle, AppTab.alerts, AppTab.me];

  /// Folded, the icons have no label beside them, so they get a tooltip.
  Widget _tip(String label, Widget icon) => extended ? icon : Tooltip(message: label, child: icon);

  @override
  Widget build(BuildContext context) {
    final index = _railTabs.indexOf(current);
    return NavigationRail(
      extended: extended,
      minExtendedWidth: 232,
      // Folded: icons only (each has a tooltip and keeps its label for
      // screen readers).
      labelType: NavigationRailLabelType.none,
      selectedIndex: index < 0 ? null : index,
      onDestinationSelected: (i) => onSelect(_railTabs[i]),
      groupAlignment: -1,
      leading: _RailTop(
        extended: extended,
        onToggle: onToggle,
        record: (wide) => _RecordAction(
          key: const ValueKey('nav-record'),
          extended: wide,
          selected: current == AppTab.record,
          recording: recording,
          onTap: () => onSelect(AppTab.record),
        ),
      ),
      destinations: [
        for (final tab in _railTabs)
          NavigationRailDestination(
            icon: _tip(
              tab.label,
              Badge(
                key: ValueKey('nav-${tab.name}'),
                isLabelVisible: tab == AppTab.alerts && alertCount > 0,
                label: Text('$alertCount'),
                child: Icon(tab.icon),
              ),
            ),
            selectedIcon: _tip(tab.label, Icon(tab.selectedIcon, key: ValueKey('nav-${tab.name}'))),
            label: Text(tab.label),
          ),
      ],
    );
  }
}

/// The mark (a fold/unfold button) and the Record action. They switch to
/// their wide look only once the rail has finished opening, so nothing
/// overflows while it animates.
class _RailTop extends StatelessWidget {
  const _RailTop({required this.extended, required this.onToggle, required this.record});

  final bool extended;
  final VoidCallback onToggle;
  final Widget Function(bool wide) record;

  @override
  Widget build(BuildContext context) {
    final anim = NavigationRail.extendedAnimation(context);
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        final wide = extended && anim.value > 0.99;
        final hint = extended ? 'Collapse menu' : 'Expand menu';
        return Padding(
          padding: const EdgeInsets.only(top: Space.m, bottom: Space.l),
          child: Column(
            crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Tooltip(
                message: hint,
                child: Semantics(
                  button: true,
                  label: 'Apexo. $hint',
                  excludeSemantics: true,
                  child: InkWell(
                    key: const ValueKey('nav-toggle'),
                    onTap: onToggle,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: BrandMark(showName: wide),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.l),
              record(wide),
            ],
          ),
        );
      },
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
            foregroundColor: recording ? AppColors.on(AppColors.tracking) : Colors.white,
            side: selected ? BorderSide(color: AppColors.accentSoft, width: 3) : null,
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
          foregroundColor: recording ? AppColors.on(AppColors.tracking) : Colors.white,
          side: selected ? BorderSide(color: AppColors.accentSoft, width: 3) : null,
        ),
      ),
    );
  }
}
