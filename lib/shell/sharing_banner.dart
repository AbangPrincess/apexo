import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../features/circle/sharing_controller.dart';

/// Persistent "Sharing live" bar shown on every tab while my location is
/// shared with any circle (SPEC G1: no hidden tracking).
class SharingBanner extends StatelessWidget {
  const SharingBanner({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = context.select<SharingController, int>((s) => s.sharingCount);
    final blocked = context.select<SharingController, bool>((s) => s.blocked);
    final t = Theme.of(context).textTheme;
    final label = blocked
        ? 'Sharing is on, but location is unavailable'
        : count == 1
        ? 'Sharing live with 1 circle'
        : 'Sharing live with $count circles';
    return AnimatedSize(
      duration: kMotion,
      alignment: Alignment.topCenter,
      child: count == 0
          ? const SizedBox(width: double.infinity)
          : Material(
              color: AppColors.darkRaised,
              child: InkWell(
                onTap: onTap,
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
                          decoration: BoxDecoration(
                            color: blocked ? AppColors.caution : AppColors.tracking,
                            shape: BoxShape.circle,
                          ),
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
