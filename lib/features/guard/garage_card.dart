import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../widgets/visuals.dart';
import 'guard_screen.dart';
import 'vehicles_controller.dart';
import 'vehicles_screen.dart';

/// Me tab summary of my vehicles, with a way into guard mode.
class GarageCard extends StatelessWidget {
  const GarageCard({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<VehiclesController>();
    final t = Theme.of(context).textTheme;
    final muted = t.bodySmall?.copyWith(color: AppColors.textMuted);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.s, Space.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Vehicles', style: t.titleMedium)),
                TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: (_) => const VehiclesScreen())),
                  child: const Text('Manage'),
                ),
              ],
            ),
            if (ctrl.vehicles.isEmpty)
              Text('Add your bike, motorbike or car to use guard mode.', style: muted)
            else
              for (final v in ctrl.vehicles.take(3))
                Padding(
                  padding: const EdgeInsets.only(top: Space.xs, right: Space.s),
                  child: Row(
                    children: [
                      Icon(v.type.icon, size: 20, color: AppColors.ink),
                      const SizedBox(width: Space.s),
                      Expanded(child: Text(v.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text(vehicleStatusLabel(v.status), style: muted),
                    ],
                  ),
                ),
            const SizedBox(height: Space.m),
            Padding(
              padding: const EdgeInsets.only(right: Space.s),
              child: OutlinedButton.icon(
                onPressed: () => openGuard(context),
                icon: const Icon(Icons.shield_outlined),
                label: const Text('Guard mode'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
