import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/geo.dart';
import '../../data/models/circle_alert.dart';
import '../../data/models/user.dart';
import '../../shell/app_tab.dart';
import '../circle/circle_controller.dart';
import '../guard/guard_controller.dart';
import '../guard/vehicles_controller.dart';
import 'alert_dialog.dart';
import 'alerts_controller.dart';

/// Opens Circle on the alert's circle, centered on where the vehicle is.
void viewAlertOnMap(BuildContext context, ShellController shell, CircleAlert a) {
  final circles = context.read<AlertsController>().circlesOf(a.id);
  final ctrl = context.read<CircleController>();
  final current = ctrl.circle?.id;
  final target = circles.contains(current) ? current : circles.firstOrNull;
  if (target == null) return;
  ctrl.focusOn(target, GeoPoint(a.lat, a.lng));
  shell.go(AppTab.circle);
}

Future<void> navigateToAlert(BuildContext context, CircleAlert a) async {
  final messenger = ScaffoldMessenger.of(context);
  if (await navigateTo(a.lat, a.lng)) return;
  messenger.showSnackBar(const SnackBar(content: Text("Couldn't open maps on this device.")));
}

/// The owner closes a theft alert. For the guarded vehicle this also
/// disarms; any other vehicle just returns to "ok".
Future<void> markRecovered(BuildContext context, CircleAlert a) async {
  final guard = context.read<GuardController>();
  final vehicles = context.read<VehiclesController>();
  final alerts = context.read<AlertsController>();
  final messenger = ScaffoldMessenger.of(context);
  if (guard.vehicle?.id == a.vehicleId) {
    await guard.markRecovered();
  } else {
    await alerts.recover(a);
    final v = vehicles.vehicles.where((v) => v.id == a.vehicleId).firstOrNull;
    if (v != null && v.status == VehicleStatus.stolen) {
      await vehicles.save(v.copyWith(status: VehicleStatus.ok, disarm: true));
    }
  }
  messenger.showSnackBar(SnackBar(content: Text('${a.vehicleName} marked recovered')));
}
