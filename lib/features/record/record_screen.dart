import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/activity_type.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/responsive.dart';
import '../../widgets/stat_value.dart';
import '../../widgets/visuals.dart';
import '../me/settings_controller.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  late ActivityType _type = context.read<SettingsController>().defaultActivity;

  @override
  Widget build(BuildContext context) {
    final units = context.select<SettingsController, Units>((s) => s.units);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Record')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            return SingleChildScrollView(
              // Side padding caps the width; the min height lets the Spacer push
              // START down to thumb reach.
              padding: pageInsets(c.maxWidth, maxWidth: 560, bottom: Space.m),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight - Space.xl),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                      _StatsPanel(units: units),
                      const SizedBox(height: Space.m),
                      _GpsHint(
                        text: kIsWeb
                            ? 'On the web, keep this tab open while recording.'
                            : 'GPS starts when you press Start.',
                      ),
                      const Spacer(),
                      const SizedBox(height: Space.l),
                      Center(
                        child: _StartButton(
                          onPressed: () =>
                              showComingSoon(context, 'Live recording'),
                        ),
                      ),
                      const SizedBox(height: Space.s),
                      Text(
                        'Records your ${_type.label.toLowerCase()} route, time and speed',
                        textAlign: TextAlign.center,
                        style: t.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.units});

  final Units units;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.l),
        child: Column(
          children: [
            const StatValue(
              label: 'Time',
              value: '0:00',
              size: StatSize.large,
              align: CrossAxisAlignment.center,
            ),
            const SizedBox(height: Space.l),
            const Divider(),
            const SizedBox(height: Space.m),
            Row(
              children: [
                Expanded(
                  child: StatValue(
                    label: 'Distance',
                    value: formatDistance(0, units),
                    unit: units.distanceLabel,
                    align: CrossAxisAlignment.center,
                  ),
                ),
                Expanded(
                  child: StatValue(
                    label: 'Speed',
                    value: formatSpeed(0, units),
                    unit: units.speedLabel,
                    align: CrossAxisAlignment.center,
                  ),
                ),
                Expanded(
                  child: StatValue(
                    label: 'Avg speed',
                    value: formatSpeed(0, units),
                    unit: units.speedLabel,
                    align: CrossAxisAlignment.center,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GpsHint extends StatelessWidget {
  const _GpsHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(
        Icons.gps_not_fixed_rounded,
        size: 16,
        color: AppColors.textMuted,
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
      ),
    ],
  );
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Start recording',
      excludeSemantics: true,
      child: Material(
        color: AppColors.accent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const SizedBox.square(
            dimension: 104,
            child: Center(
              child: Text(
                'START',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
