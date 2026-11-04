import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/units.dart';
import '../../data/models/circle.dart';
import '../../widgets/member_avatar.dart';
import '../../widgets/time_ago.dart';
import '../../widgets/visuals.dart';

class MemberTile extends StatelessWidget {
  const MemberTile({
    super.key,
    required this.member,
    required this.units,
    required this.isMe,
    required this.isOwner,
    this.onTap,
    this.onOpenProfile,
  });

  final Member member;
  final Units units;
  final bool isMe;
  final bool isOwner;
  final VoidCallback? onTap;

  /// Tapping the photo (or a long press) opens their profile.
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final m = member;
    final moving = m.status == MemberStatus.tracking || m.status == MemberStatus.alert;
    final muted = t.bodySmall?.copyWith(color: AppColors.textMuted);
    final alert = m.status == MemberStatus.alert;
    final status = alert ? '${m.vehicle?.name ?? 'Vehicle'} moved' : m.status.label;
    final statusStyle = alert
        ? muted?.copyWith(color: AppColors.alert, fontWeight: FontWeight.w600)
        : muted;

    final avatar = MemberAvatar(
      initial: m.initial,
      ringColor: m.status.color,
      badge: m.vehicle?.type.icon,
      highlight: isMe,
    );
    return ListTile(
      onTap: onTap,
      onLongPress: onOpenProfile,
      leading: onOpenProfile == null
          ? avatar
          : Semantics(
              button: true,
              label: isMe ? 'Your profile' : 'Profile of ${m.displayName}',
              excludeSemantics: true,
              child: Tooltip(
                message: 'View profile',
                child: InkResponse(
                  key: ValueKey('profile-${m.uid}'),
                  onTap: onOpenProfile,
                  radius: 28,
                  child: avatar,
                ),
              ),
            ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              m.displayName,
              style: t.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isOwner) const MemberTag('Owner'),
        ],
      ),
      subtitle: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: m.status.color,
              shape: BoxShape.circle,
              // Keeps the light volt dot visible on white.
              border: Border.all(color: AppColors.ink, width: 0.75),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: m.sharing
                ? TimeAgo(m.ts, prefix: '$status · ', style: statusStyle)
                : Text(status, style: statusStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (moving)
            Text(
              '${formatSpeed(m.speedKmh, units)} ${units.speedLabel}',
              style: t.labelLarge?.copyWith(fontFeatures: kTabular),
            ),
          _Battery(m.battery),
        ],
      ),
    );
  }
}

class MemberTag extends StatelessWidget {
  const MemberTag(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AppColors.hairline),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
    ),
  );
}

class _Battery extends StatelessWidget {
  const _Battery(this.percent);

  final int percent;

  @override
  Widget build(BuildContext context) {
    final low = percent <= 20;
    final icon = switch (percent) {
      > 80 => Icons.battery_full_rounded,
      > 50 => Icons.battery_5_bar_rounded,
      > 20 => Icons.battery_3_bar_rounded,
      _ => Icons.battery_alert_rounded,
    };
    // Orange marks the icon only; small orange text would be hard to read.
    final color = low ? AppColors.caution : AppColors.textMuted;
    final textColor = low ? AppColors.text : AppColors.textMuted;
    return Semantics(
      label: 'Battery $percent percent',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          Text(
            '$percent%',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: textColor, fontFeatures: kTabular),
          ),
        ],
      ),
    );
  }
}
