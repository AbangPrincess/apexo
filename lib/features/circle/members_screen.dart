import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models/circle.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/member_avatar.dart';
import '../../widgets/responsive.dart';
import '../../widgets/visuals.dart';
import 'circle_controller.dart';
import 'invite_card.dart';
import 'member_panel.dart';
import 'member_tile.dart';
import 'share_tile.dart';

/// Invite code, my sharing switch, the member list (the owner can remove
/// people) and Leave circle.
class MembersScreen extends StatelessWidget {
  const MembersScreen({super.key});

  void _snack(ScaffoldMessengerState m, String text) => m
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _remove(BuildContext context, Circle circle, Member m) async {
    final ctrl = context.read<CircleController>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmAction(
      context,
      title: 'Remove ${m.displayName}?',
      message: 'They stop seeing ${circle.name} and its members right away.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ctrl.remove(circle.id, m.uid);
      _snack(messenger, '${m.displayName} was removed');
    } on Exception catch (e) {
      _snack(messenger, '$e');
    }
  }

  Future<void> _leave(BuildContext context, Circle circle, String? next) async {
    final ctrl = context.read<CircleController>();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final mine = circle.ownerUid == ctrl.uid;
    final ok = await confirmAction(
      context,
      title: 'Leave ${circle.name}?',
      message: circle.memberUids.length <= 1
          ? 'You are the last member, so the circle will be deleted.'
          : mine && next != null
          ? 'You stop sharing with it and seeing its members. $next becomes the owner.'
          : 'You stop sharing with it and seeing its members. You can rejoin with the code.',
      confirmLabel: 'Leave',
      destructive: true,
    );
    if (!ok) return;
    // Pop first, so this screen never shows the next circle.
    nav.pop();
    try {
      await ctrl.leave(circle.id);
      _snack(messenger, 'You left ${circle.name}');
    } on Exception catch (e) {
      _snack(messenger, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<CircleController>();
    final circle = ctrl.circle;
    if (circle == null) return const Scaffold();
    final t = Theme.of(context).textTheme;
    final others = ctrl.members.where((m) => m.uid != ctrl.uid);
    final next = others.isEmpty ? null : others.first.displayName;

    return Scaffold(
      appBar: AppBar(title: Text(circle.name)),
      body: PageListView(
        maxWidth: 640,
        children: [
          InviteCodeCard(circle: circle),
          const SizedBox(height: Space.m),
          Card(child: ShareTile(circleId: circle.id)),
          const SizedBox(height: Space.l),
          Text(memberCount(ctrl.members.length), style: t.titleMedium),
          const SizedBox(height: Space.s),
          for (final m in ctrl.members)
            _MemberRow(
              key: ValueKey(m.uid),
              member: m,
              isMe: m.uid == ctrl.uid,
              isOwner: m.uid == circle.ownerUid,
              onRemove: ctrl.isOwner && m.uid != ctrl.uid
                  ? () => _remove(context, circle, m)
                  : null,
            ),
          const SizedBox(height: Space.l),
          OutlinedButton.icon(
            onPressed: () => _leave(context, circle, next),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.alert),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Leave circle'),
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    super.key,
    required this.member,
    required this.isMe,
    required this.isOwner,
    this.onRemove,
  });

  final Member member;
  final bool isMe;
  final bool isOwner;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final m = member;
    final t = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: MemberAvatar(
        initial: m.initial,
        ringColor: m.status.color,
        badge: m.vehicle?.type.icon,
        highlight: isMe,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              // The demo account is already called "You".
              isMe && m.displayName != 'You' ? '${m.displayName} (you)' : m.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isOwner) const MemberTag('Owner'),
        ],
      ),
      subtitle: Text(
        m.sharing ? 'Sharing location' : 'Sharing paused',
        style: t.bodySmall?.copyWith(color: AppColors.textMuted),
      ),
      trailing: onRemove == null
          ? null
          : IconButton(
              tooltip: 'Remove ${m.displayName}',
              onPressed: onRemove,
              icon: const Icon(Icons.person_remove_outlined),
            ),
    );
  }
}
