import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/units.dart';
import '../../data/models/circle_alert.dart';
import '../../widgets/visuals.dart';
import '../me/settings_controller.dart';
import 'alert_buttons.dart';
import 'alert_heading.dart';

/// "Moved 0.07 km away (limit 0.05 km)" and friends. Distances follow the
/// Kilometers / Miles setting like ride distances (owner, 2026-11-11); the
/// distance is from where the vehicle was guarded.
String alertDetail(CircleAlert a, Units units) => switch (a.type) {
  AlertType.geofence =>
    'Moved ${distanceText(a.distanceM, units)} away'
        '${a.radiusM > 0 ? ' (limit ${distanceText(a.radiusM, units)})' : ''}',
  AlertType.motion => 'Movement detected while guarded',
  AlertType.lowbattery => 'Guard mode may stop soon',
  AlertType.sos => 'Asked the circle for help',
};

/// Directions in Google Maps (app or web) to where the alert is now.
Future<bool> navigateTo(double lat, double lng) async {
  final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

enum AlertChoice { viewOnMap, navigate, itsMe }

/// The interruption other members see when a vehicle in their circle
/// moves. Dismissing it (tap outside, back) leaves the alert unacknowledged.
/// Same layout on iPhone, Android and the web: View on map and Navigate
/// side by side under the title, a quiet "It's me" of the same size below.
Future<AlertChoice?> showIncomingAlert(BuildContext context, CircleAlert a) =>
    showDialog<AlertChoice>(
      context: context,
      barrierDismissible: true,
      builder: (_) => IncomingAlertDialog(alert: a),
    );

class IncomingAlertDialog extends StatelessWidget {
  const IncomingAlertDialog({super.key, required this.alert});

  final CircleAlert alert;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final units = context.select<SettingsController, Units>((s) => s.units);
    final battery = alert.type == AlertType.lowbattery;
    void pick(AlertChoice c) => Navigator.of(context).pop(c);
    return Dialog(
      insetPadding: const EdgeInsets.all(Space.l),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        // The same 24 pt on every side, so the last button sits as far
        // from the bottom edge as the icon does from the top.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(alert.type.icon, color: alert.type.color, size: 32),
              const SizedBox(height: Space.m),
              AlertHeading(
                alert.message,
                alertDetail(alert, units),
                titleStyle: t.titleLarge!,
                detailStyle: t.bodyMedium!.copyWith(color: AppColors.textMuted),
                center: true,
                gap: Space.s,
              ),
              const SizedBox(height: Space.l),
              // Low battery never pops up (a snack bar instead).
              if (!battery)
                AlertActions(
                  filledMap: true,
                  onViewMap: () => pick(AlertChoice.viewOnMap),
                  onNavigate: () => pick(AlertChoice.navigate),
                  third: "It's me",
                  onThird: () => pick(AlertChoice.itsMe),
                )
              else ...[
                Center(
                  child: TextButton(
                    onPressed: () => pick(AlertChoice.itsMe),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small red pin for an open alert's last known spot on the map.
class AlertPin extends StatelessWidget {
  const AlertPin({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Last reported position of a missing vehicle',
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.alert,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
      ),
      child: const Icon(Icons.priority_high_rounded, color: Colors.white, size: 18),
    ),
  );
}
