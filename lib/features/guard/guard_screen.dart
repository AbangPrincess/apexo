import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/guard_logic.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../data/models/user.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/permission_rationale.dart';
import '../../widgets/responsive.dart';
import '../../widgets/visuals.dart';
import '../alerts/alert_notifier.dart';
import '../me/settings_controller.dart';
import '../record/location_rationale.dart';
import 'guard_controller.dart';
import 'guard_panels.dart';
import 'vehicle_form.dart';
import 'vehicles_controller.dart';
import 'vehicles_screen.dart';

void openGuard(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GuardScreen()));

/// Arm, watch and disarm guard mode for the active vehicle.
class GuardScreen extends StatelessWidget {
  const GuardScreen({super.key});

  void _vehicles(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const VehiclesScreen()));

  @override
  Widget build(BuildContext context) {
    final guard = context.watch<GuardController>();
    final units = context.select<SettingsController, Units>((s) => s.units);
    final loaded = context.select<VehiclesController, bool>((c) => c.loaded);
    final v = guard.vehicle;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guard mode'),
        actions: [
          IconButton(
            tooltip: 'Vehicles',
            icon: const Icon(Icons.garage_outlined),
            onPressed: () => _vehicles(context),
          ),
          const SizedBox(width: Space.s),
        ],
      ),
      body: !loaded
          ? const Center(child: CircularProgressIndicator.adaptive())
          : v == null
          ? EmptyState(
              icon: Icons.shield_outlined,
              title: 'Add a vehicle to guard',
              message:
                  'Leave your phone on your bike, motorbike or car. If it moves, '
                  'everyone in your circles gets an alert.',
              actionLabel: 'Add vehicle',
              onAction: () => showVehicleForm(context),
            )
          : PageListView(
              maxWidth: 640,
              children: [
                Card(
                  child: ListTile(
                    leading: IconTile(icon: v.type.icon),
                    title: Text(v.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${v.type.label} · ${vehicleStatusLabel(v.status)}'),
                    trailing: guard.armed
                        ? null
                        : TextButton(
                            onPressed: () => _vehicles(context),
                            child: const Text('Change'),
                          ),
                  ),
                ),
                const SizedBox(height: Space.m),
                if (guard.stolen && guard.watching)
                  StolenPanel(vehicle: v)
                else if (guard.watching)
                  ArmedPanel(vehicle: v)
                else if (guard.armedElsewhere)
                  ElsewherePanel(vehicle: v)
                else ...[
                  Text(
                    'Leave this phone on or in the vehicle. If it moves more than '
                    '${distanceText(guard.radiusM, units)} from where you arm it, everyone in your circles '
                    'gets an alert.',
                    style: t.bodyMedium?.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: Space.m),
                  if (!guard.hasCircles) const _NoCircleNote(),
                  const _SetupCard(),
                  const SizedBox(height: Space.l),
                  const _ArmButton(),
                ],
              ],
            ),
    );
  }
}

class _NoCircleNote extends StatelessWidget {
  const _NoCircleNote();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.m),
    child: Row(
      children: [
        const Icon(Icons.info_outline_rounded, color: AppColors.caution),
        const SizedBox(width: Space.s),
        Expanded(
          child: Text(
            'You are not in a circle yet, so nobody would get the alert. Join or create '
            'one in Circle.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    ),
  );
}

class _SetupCard extends StatelessWidget {
  const _SetupCard();

  @override
  Widget build(BuildContext context) {
    final guard = context.watch<GuardController>();
    final units = context.select<SettingsController, Units>((s) => s.units);
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.m, 0),
              child: Row(
                children: [
                  Expanded(child: Text('Alert distance', style: t.titleSmall)),
                  Text(
                    distanceText(guard.radiusM, units),
                    style: t.titleMedium?.copyWith(fontFeatures: kTabular),
                  ),
                ],
              ),
            ),
            Slider.adaptive(
              value: guard.radiusM,
              min: GuardController.minRadiusM,
              max: GuardController.maxRadiusM,
              divisions: 48,
              label: distanceText(guard.radiusM, units),
              onChanged: guard.setRadius,
            ),
            const Divider(),
            SwitchListTile.adaptive(
              value: guard.motionOn,
              onChanged: (on) => guard.setMotion(on: on),
              title: const Text('Movement detection'),
              subtitle: const Text('Also alert when the phone is shaken or lifted'),
            ),
            if (guard.motionOn)
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.m, 0, Space.m, Space.s),
                child: SegmentedButton<NudgeSensitivity>(
                  showSelectedIcon: false,
                  segments: [
                    for (final s in NudgeSensitivity.values)
                      ButtonSegment(value: s, label: Text(s.label)),
                  ],
                  selected: {guard.sensitivity},
                  onSelectionChanged: (s) => guard.setMotion(level: s.first),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ArmButton extends StatelessWidget {
  const _ArmButton();

  Future<void> _arm(BuildContext context) async {
    final guard = context.read<GuardController>();
    final notifier = context.read<AlertNotifier>();
    final messenger = ScaffoldMessenger.of(context);
    if (!await explainLocationIfNeeded(context, PermissionNeed.guardLocation)) return;
    // Android 13+ hides the "Guard mode on" notification without this.
    // Saying no still arms; the alert just reaches the circle without it.
    if (!kIsWeb) {
      await notifier.refresh();
      if (!notifier.enabled &&
          context.mounted &&
          await explainPermission(context, PermissionNeed.notifications)) {
        await notifier.requestPermission();
      }
    }
    final message = await guard.arm();
    if (message != null) messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.select<GuardController, bool>((g) => g.busy);
    final armed = context.select<GuardController, VehicleStatus?>((g) => g.vehicle?.status);
    return FilledButton(
      key: const ValueKey('arm-guard'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
      ),
      onPressed: busy || armed != VehicleStatus.ok ? null : () => _arm(context),
      child: busy
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2.4),
            )
          : const Text('ARM GUARD', style: TextStyle(letterSpacing: 1.2)),
    );
  }
}
