import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../features/circle/sharing_controller.dart';
import '../features/guard/guard_controller.dart';

/// Persistent bar shown on every tab while my location is shared with any
/// circle or this phone guards a vehicle (SPEC G1: no hidden tracking).
class SharingBanner extends StatelessWidget {
  const SharingBanner({super.key, required this.onSharing, required this.onGuard});

  final VoidCallback onSharing;
  final VoidCallback onGuard;

  @override
  Widget build(BuildContext context) {
    final count = context.select<SharingController, int>((s) => s.sharingCount);
    final blocked = context.select<SharingController, bool>((s) => s.blocked);
    final guarding = context.select<GuardController, bool>((g) => g.watching);
    final stolen = context.select<GuardController, bool>((g) => g.watching && g.stolen);
    final vehicle = context.select<GuardController, String>((g) => g.vehicle?.name ?? '');
    final t = Theme.of(context).textTheme;
    final sharing = count == 1 ? 'sharing with 1 circle' : 'sharing with $count circles';
    final label = stolen
        ? '$vehicle left its boundary'
        : guarding
        ? ['Guard mode on · $vehicle', if (count > 0) sharing].join(' · ')
        : blocked
        ? 'Sharing is on, but location is unavailable'
        : 'Sharing live with ${count == 1 ? '1 circle' : '$count circles'}';
    final dot = stolen
        ? AppColors.alert
        : blocked && !guarding
        ? AppColors.caution
        : AppColors.tracking;
    return AnimatedSize(
      duration: kMotion,
      alignment: Alignment.topCenter,
      child: count == 0 && !guarding
          ? const SizedBox(width: double.infinity)
          : Material(
              color: AppColors.darkRaised,
              child: InkWell(
                onTap: guarding ? onGuard : onSharing,
                child: Semantics(
                  button: true,
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyMedium?.copyWith(color: Colors.white),
                          ),
                        ),
                        Text('Manage', style: t.labelLarge?.copyWith(color: AppColors.tracking)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
