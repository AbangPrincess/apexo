import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/activity_type.dart';
import '../../core/ride_tracker.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../shell/app_tab.dart';
import '../../widgets/permission_rationale.dart';
import '../../widgets/responsive.dart';
import '../../widgets/route_thumbnail.dart';
import '../../widgets/visuals.dart';
import '../auth/auth_widgets.dart';
import '../auth/session_controller.dart';
import '../me/settings_controller.dart';
import '../weather/weather_card.dart';
import 'finish_sheet.dart';
import 'location_rationale.dart';
import 'record_controller.dart';
import 'record_widgets.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  late ActivityType _type = context.read<SettingsController>().defaultActivity;

  Future<void> _start() async {
    final rec = context.read<RecordController>();
    // Explain why before the system asks for location.
    if (!await explainLocationIfNeeded(context, PermissionNeed.recordLocation)) return;
    await rec.start(_type);
  }

  Future<void> _finish() async {
    final rec = context.read<RecordController>();
    final shell = context.read<ShellController>();
    final messenger = ScaffoldMessenger.of(context);
    final draft = rec.finish();
    if (draft == null) return;
    final saved = await showFinishSheet(context, rec, draft);
    if (!saved) return;
    shell.go(AppTab.home);
    messenger.showSnackBar(const SnackBar(content: Text('Activity saved')));
  }

  @override
  Widget build(BuildContext context) {
    final rec = context.watch<RecordController>();
    final units = context.select<SettingsController, Units>((s) => s.units);

    // While a ride is live the screen becomes a dark cockpit: higher
    // contrast in sunlight and less battery on OLED phones.
    final cockpit = rec.isActive;
    return Scaffold(
      backgroundColor: cockpit ? AppColors.dark : null,
      appBar: AppBar(
        title: Text('Record', style: cockpit ? const TextStyle(color: Colors.white) : null),
        backgroundColor: cockpit ? AppColors.dark : null,
        foregroundColor: cockpit ? Colors.white : null,
        shape: cockpit ? const Border() : null,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            return SingleChildScrollView(
              // Side padding caps the width. The min height plus spaceBetween
              // keeps the controls at thumb reach, and short screens scroll.
              padding: pageInsets(c.maxWidth, maxWidth: 560, bottom: Space.m),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight - Space.xl),
                child: rec.isActive ? _live(rec, units) : _idle(rec, roomy: c.maxHeight >= 900),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _idle(RecordController rec, {required bool roomy}) {
    final t = Theme.of(context).textTheme;
    final muted = t.bodySmall?.copyWith(color: AppColors.textMuted);
    return _TwoPart(
      top: [
        Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          alignment: WrapAlignment.center,
          children: [
            for (final type in ActivityType.values)
              ChoiceChip(
                avatar: Icon(
                  type.icon,
                  size: 18,
                  color: type == _type ? AppColors.onInk : AppColors.text,
                ),
                label: Text(type.label),
                selected: type == _type,
                onSelected: (_) => setState(() => _type = type),
              ),
          ],
        ),
        const SizedBox(height: Space.l),
        // Before a ride the weather call takes the place of the stats, which
        // appear once recording starts. Short screens fold the hourly part.
        WeatherCard(key: const ValueKey('record-weather'), type: _type, compact: !roomy),
        const SizedBox(height: Space.s),
        if (context.read<SessionController>().isDemo)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: rec.useSimulated,
            onChanged: rec.setSimulated,
            title: const Text('Simulated GPS'),
            subtitle: const Text('Demo rides around Koronadal, so you can try recording anywhere'),
          ),
        Text(
          rec.useSimulated
              ? 'Using simulated GPS.'
              : kIsWeb
              ? 'On the web, keep this tab open while recording.'
              : 'GPS starts when you press Start.',
          textAlign: TextAlign.center,
          style: muted,
        ),
        if (rec.error != null) ...[
          const SizedBox(height: Space.m),
          ErrorBanner(rec.error!),
          if (rec.error!.contains('Settings'))
            TextButton(onPressed: rec.source.openSettings, child: const Text('Open Settings')),
        ],
      ],
      bottom: [
        const SizedBox(height: Space.l),
        Center(
          child: RoundAction(label: 'START', onPressed: rec.starting ? null : _start),
        ),
        const SizedBox(height: Space.s),
        Text(
          'Records your ${_type.label.toLowerCase()} route, time and speed',
          textAlign: TextAlign.center,
          style: muted,
        ),
      ],
    );
  }

  Widget _live(RecordController rec, Units units) {
    final paused = rec.state == RideState.paused;
    final path = rec.path;
    return _TwoPart(
      top: [
        Center(
          child: RecordStatusPill(state: rec.state, simulated: rec.source.simulated),
        ),
        const SizedBox(height: Space.m),
        RecordStats(
          units: units,
          movingTime: rec.movingTime,
          distanceM: rec.distanceM,
          speedKmh: rec.currentKmh,
          avgKmh: rec.avgKmh,
          dark: true,
        ),
        const SizedBox(height: Space.m),
        if (path.length >= 2)
          RouteThumbnail(
            points: path,
            height: 150,
            color: AppColors.tracking,
            background: AppColors.darkRaised,
          )
        else
          SizedBox(
            height: 150,
            child: Center(
              child: Text('Waiting for GPS…', style: TextStyle(color: AppColors.onDarkMuted)),
            ),
          ),
        if (rec.error != null) ...[const SizedBox(height: Space.m), ErrorBanner(rec.error!)],
      ],
      bottom: [
        const SizedBox(height: Space.l),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: paused
              ? [
                  RoundAction(
                    label: 'RESUME',
                    icon: Icons.play_arrow_rounded,
                    color: AppColors.tracking,
                    onPressed: rec.resume,
                    size: 96,
                  ),
                  RoundAction(
                    label: 'FINISH',
                    icon: Icons.stop_rounded,
                    color: AppColors.alert,
                    onPressed: _finish,
                    size: 96,
                  ),
                ]
              : [
                  RoundAction(
                    label: 'PAUSE',
                    icon: Icons.pause_rounded,
                    color: AppColors.darkRaised,
                    border: AppColors.darkLine,
                    onPressed: rec.pause,
                  ),
                ],
        ),
      ],
    );
  }
}

/// Content on top, controls at the bottom of at least the screen's height.
class _TwoPart extends StatelessWidget {
  const _TwoPart({required this.top, required this.bottom});

  final List<Widget> top;
  final List<Widget> bottom;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: top),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: bottom),
    ],
  );
}
