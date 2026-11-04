import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Why Apexo needs a permission, shown before the system asks (SPEC P6).
enum PermissionNeed {
  recordLocation(
    Icons.route_rounded,
    'Use your location to record?',
    'Apexo uses your location while you record, to map your route, distance and speed. '
        'It is not shared unless you post the activity to a circle.',
  ),
  shareLocation(
    Icons.share_location_rounded,
    'Share your location with your circle?',
    'Members see where you are only while sharing is on, and a bar shows it on every tab. '
        'You can pause it any time.',
  ),
  findMe(
    Icons.my_location_rounded,
    'Show where you are on the map?',
    'Apexo uses your location to put you on the map. Nobody else sees it unless you '
        'turn on sharing.',
  ),
  guardLocation(
    Icons.shield_outlined,
    'Let guard mode watch your vehicle?',
    'Guard mode checks this phone\'s location to know if the vehicle moves, and tells '
        'your circle if it leaves its boundary.',
  ),
  microphone(
    Icons.mic_none_rounded,
    'Use the microphone for the walkie-talkie?',
    'Apexo listens only while you hold (or have tapped) the Talk button, and sends that '
        'message to your circle. Nothing is recorded at any other time.',
  ),
  notifications(
    Icons.notifications_active_outlined,
    'Get theft alerts as notifications?',
    'Apexo shows a notification with sound when a vehicle in your circles moves, and '
        'one that stays while guard mode is on. Nothing else.',
  );

  const PermissionNeed(this.icon, this.title, this.why);
  final IconData icon;
  final String title;
  final String why;
}

/// True when the person chose to continue to the system dialog.
Future<bool> explainPermission(BuildContext context, PermissionNeed need) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (sheet) {
      final t = Theme.of(sheet).textTheme;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: AppColors.surfaceAlt, shape: BoxShape.circle),
                  child: Icon(need.icon, size: 30, color: AppColors.ink),
                ),
              ),
              const SizedBox(height: Space.m),
              Text(need.title, style: t.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: Space.s),
              Text(
                need.why,
                style: t.bodyMedium?.copyWith(color: AppColors.textMuted, height: 1.45),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.l),
              FilledButton(
                onPressed: () => Navigator.of(sheet).pop(true),
                child: const Text('Continue'),
              ),
              const SizedBox(height: Space.xs),
              TextButton(
                onPressed: () => Navigator.of(sheet).pop(false),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      );
    },
  );
  return ok ?? false;
}
