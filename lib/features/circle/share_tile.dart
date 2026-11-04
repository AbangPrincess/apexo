import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import 'circle_controller.dart';
import 'sharing_controller.dart';

Future<void> toggleSharing(BuildContext context, String circleId, bool on) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await context.read<SharingController>().setSharing(circleId, on);
  if (message == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// "Share my location" for the active circle; off means paused.
class ShareTile extends StatelessWidget {
  const ShareTile({super.key, required this.circleId, this.compact = false});

  final String circleId;

  /// One line, for the member sheet; the subtitle shows only on problems.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final on = context.select<CircleController, bool?>((c) => c.me?.sharing);
    final blocked = context.select<SharingController, bool>((s) => s.blocked);
    final subtitle = on != true
        ? (compact ? null : 'Paused. Members cannot see where you are.')
        : blocked
        ? 'On, but this device is not giving a location.'
        : (compact ? null : 'Members see where you are.');
    return SwitchListTile.adaptive(
      key: const ValueKey('share-switch'),
      dense: compact,
      value: on ?? false,
      onChanged: on == null ? null : (v) => toggleSharing(context, circleId, v),
      secondary: AnimatedContainer(
        duration: kMotion,
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: on == true ? AppColors.tracking : AppColors.surfaceAlt,
          shape: BoxShape.circle,
          border: Border.all(color: on == true ? AppColors.ink : AppColors.parked),
        ),
      ),
      title: const Text('Share my location'),
      subtitle: subtitle == null ? null : Text(subtitle),
    );
  }
}
