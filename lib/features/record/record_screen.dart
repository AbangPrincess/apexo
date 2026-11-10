import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/activity_type.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../shell/app_tab.dart';
import '../../widgets/permission_rationale.dart';
import '../../widgets/responsive.dart';
import '../auth/auth_widgets.dart';
import '../auth/session_controller.dart';
import '../me/settings_controller.dart';
import '../weather/weather_card.dart';
import 'activity_picker.dart';
import 'finish_sheet.dart';
import 'live_ride_view.dart';
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
    final outcome = await showFinishSheet(context, rec, draft);
    if (outcome == SaveOutcome.discarded) return;
    shell.go(AppTab.home);
    // With no connection the ride waits on this device and uploads by
    // itself. A web page keeps it only while it stays open.
    final message = outcome == SaveOutcome.uploaded
        ? 'Activity saved'
        : kIsWeb
        ? "Saved. It uploads when you're back online, so keep Apexo open until then."
        : "Saved on this phone. It uploads when you're back online.";
    messenger.showSnackBar(SnackBar(content: Text(message)));
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
      body: rec.isActive
          ? LiveRideView(units: units, onFinish: _finish)
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, c) {
                  return SingleChildScrollView(
                    // Side padding caps the width. The min height plus
                    // spaceBetween keeps START at thumb reach; short screens scroll.
                    padding: pageInsets(c.maxWidth, maxWidth: 560, bottom: Space.m),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight - Space.xl),
                      child: _idle(rec, roomy: c.maxHeight >= 900),
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
        ActivityPicker(value: _type, onChanged: (type) => setState(() => _type = type)),
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
              ? 'Keep this tab open: the screen stays on while you record, because a locked '
                    'iPhone pauses web pages. No internet needed once it is open.'
              : 'Keeps recording with the screen locked until you finish. No internet needed.',
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
          'Records your ${_type.label.toLowerCase()} route, time and '
          '${_type.usesPace ? 'pace' : 'speed'}',
          textAlign: TextAlign.center,
          style: muted,
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
