import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'app_tab.dart';

/// Phone navigation: four tabs around a prominent center Record button.
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.current,
    required this.onSelect,
    this.alertCount = 0,
    this.recording = false,
  });

  final AppTab current;
  final ValueChanged<AppTab> onSelect;
  final int alertCount;

  /// A ride is being recorded: the center button turns green.
  final bool recording;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              for (final tab in AppTab.values)
                Expanded(
                  key: ValueKey('nav-${tab.name}'),
                  child: tab == AppTab.record
                      ? _RecordButton(
                          selected: current == tab,
                          recording: recording,
                          onTap: () => onSelect(tab),
                        )
                      : _NavItem(
                          tab: tab,
                          selected: current == tab,
                          badge: tab == AppTab.alerts ? alertCount : 0,
                          onTap: () => onSelect(tab),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.selected, required this.onTap, this.badge = 0});

  final AppTab tab;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textMuted;
    // Small red text on asphalt is below 4.5:1, so in dark mode only the
    // icon stays red.
    final dark = AppColors.brightness == Brightness.dark;
    final labelColor = selected && dark ? AppColors.text : color;
    final icon = Icon(selected ? tab.selectedIcon : tab.icon, color: color, size: 26);
    return Semantics(
      button: true,
      selected: selected,
      label: badge > 0 ? '${tab.label}, $badge new' : tab.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(isLabelVisible: badge > 0, label: Text('$badge'), child: icon),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: kMotion,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: labelColor,
              ),
              child: Text(tab.label, maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.selected, required this.recording, required this.onTap});

  final bool selected;
  final bool recording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: recording ? 'Recording in progress' : 'Record',
      excludeSemantics: true,
      child: Center(
        child: Material(
          // Volt while a ride is live; Apex Red otherwise.
          color: recording ? AppColors.tracking : AppColors.accent,
          shape: CircleBorder(
            side: BorderSide(color: selected ? AppColors.accentSoft : AppColors.surface, width: 4),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 60,
              height: 60,
              child: Icon(
                Icons.radio_button_checked_rounded,
                color: recording ? AppColors.on(AppColors.tracking) : Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
