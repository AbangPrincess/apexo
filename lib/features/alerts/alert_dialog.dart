import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/models/circle_alert.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/visuals.dart';

/// "Moved 120 m from its boundary (limit 50 m)" and friends.
String alertDetail(CircleAlert a) => switch (a.type) {
  AlertType.geofence =>
    'Moved ${a.distanceM.round()} m from its boundary'
        '${a.radiusM > 0 ? ' (limit ${a.radiusM.round()} m)' : ''}',
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
Future<AlertChoice?> showIncomingAlert(BuildContext context, CircleAlert a) {
  final apple = isApple(context);
  Widget action(BuildContext ctx, String label, AlertChoice c, {bool primary = false}) {
    void pop() => Navigator.of(ctx).pop(c);
    if (apple) {
      return CupertinoDialogAction(isDefaultAction: primary, onPressed: pop, child: Text(label));
    }
    return primary
        ? FilledButton(onPressed: pop, child: Text(label))
        : TextButton(onPressed: pop, child: Text(label));
  }

  return showAdaptiveDialog<AlertChoice>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog.adaptive(
      icon: apple ? null : Icon(a.type.icon, color: a.type.color, size: 32),
      title: Text(a.message),
      content: Text(alertDetail(a)),
      actions: [
        if (a.type != AlertType.lowbattery)
          action(ctx, 'View on map', AlertChoice.viewOnMap, primary: true),
        if (a.type != AlertType.lowbattery) action(ctx, 'Navigate', AlertChoice.navigate),
        action(ctx, a.type == AlertType.lowbattery ? 'OK' : "It's me", AlertChoice.itsMe),
      ],
    ),
  );
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
