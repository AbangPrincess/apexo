import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models/user.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/responsive.dart';
import '../../widgets/visuals.dart';
import 'guard_controller.dart';
import 'vehicle_form.dart';
import 'vehicles_controller.dart';

String vehicleStatusLabel(VehicleStatus s) => switch (s) {
  VehicleStatus.ok => 'Not guarded',
  VehicleStatus.guarding => 'Guard mode on',
  VehicleStatus.stolen => 'Left its boundary',
};

/// My vehicles. Tap one to make it active: it shows on my pin and is the
/// one guard mode protects.
class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<VehiclesController>();
    // Switching while a vehicle is guarded would leave it unwatched.
    final locked = context.select<GuardController, bool>((g) => g.armed);
    final active = ctrl.active;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Vehicles')),
      floatingActionButton: ctrl.vehicles.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showVehicleForm(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add vehicle'),
            ),
      body: !ctrl.loaded
          ? const Center(child: CircularProgressIndicator.adaptive())
          : ctrl.vehicles.isEmpty
          ? EmptyState(
              icon: Icons.garage_outlined,
              title: 'Add your first vehicle',
              message:
                  'Your bike, motorbike or car. Its icon shows on your pin, and guard '
                  'mode can watch it for you.',
              actionLabel: 'Add vehicle',
              onAction: () => showVehicleForm(context),
            )
          : PageListView(
              children: [
                if (locked)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.s),
                    child: Text(
                      'Disarm guard mode to switch the active vehicle.',
                      style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                    ),
                  ),
                for (final v in ctrl.vehicles)
                  Card(
                    key: ValueKey(v.id),
                    child: ListTile(
                      onTap: locked || v.id == active?.id ? null : () => ctrl.setActive(v.id),
                      leading: IconTile(icon: v.type.icon),
                      title: Text(v.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        [
                          v.type.label,
                          vehicleStatusLabel(v.status),
                          if (v.id == active?.id) 'Active',
                        ].join(' · '),
                      ),
                      trailing: IconButton(
                        tooltip: 'Edit ${v.name}',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => showVehicleForm(context, vehicle: v),
                      ),
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
    );
  }
}
