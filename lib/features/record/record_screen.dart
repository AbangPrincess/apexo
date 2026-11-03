import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/activity_type.dart';
import '../../core/ride_tracker.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../shell/app_tab.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/responsive.dart';
import '../../widgets/route_thumbnail.dart';
import '../../widgets/visuals.dart';
import '../auth/auth_widgets.dart';
import '../auth/session_controller.dart';
import '../me/settings_controller.dart';
import 'finish_sheet.dart';
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
    if (!rec.source.simulated && !await rec.source.hasAccess()) {
      if (!mounted) return;
      final ok = await confirmAction(
        context,
        title: 'Use your location?',
        message:
            'PedalTrack uses your location while you record, to map your route, '
            'distance and speed. It is not shared unless you post the activity to a circle.',
        confirmLabel: 'Continue',
      );
      if (!ok) return;
    }
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

    return Scaffold(
      appBar: AppBar(title: const Text('Record')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            return SingleChildScrollView(
              // Side padding caps the width. The min height plus spaceBetween
              // keeps the controls at thumb reach, and short screens scroll.
              padding: pageInsets(c.maxWidth, maxWidth: 560, bottom: Space.m),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight - Space.xl),
                child: rec.isActive ? _live(rec, units) : _idle(rec, units),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _idle(RecordController rec, Units units) {
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
                avatar: Icon(type.icon, size: 18),
                label: Text(type.label),
                selected: type == _type,
                onSelected: (_) => setState(() => _type = type),
              ),
          ],
        ),
        const SizedBox(height: Space.l),
        RecordStats(units: units, movingTime: Duration.zero, distanceM: 0, speedKmh: 0, avgKmh: 0),
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
        ),
        const SizedBox(height: Space.m),
        if (path.length >= 2)
          RouteThumbnail(points: path, height: 150, background: AppColors.surface)
        else
          SizedBox(
            height: 150,
            child: Center(
              child: Text(
                'Waiting for GPS…',
                style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.9)),
              ),
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
                    onPressed: rec.resume,
                    size: 96,
                  ),
                  RoundAction(
                    label: 'FINISH',
                    icon: Icons.stop_rounded,
                    color: AppColors.text,
                    onPressed: _finish,
                    size: 96,
                  ),
                ]
              : [
                  RoundAction(
                    label: 'PAUSE',
                    icon: Icons.pause_rounded,
                    color: AppColors.text,
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
