import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/units.dart';
import '../../data/models/circle.dart';
import '../me/settings_controller.dart';
import 'invite_card.dart';
import 'member_tile.dart';
import 'share_tile.dart';

String memberCount(int n) => n == 1 ? '1 member' : '$n members';

/// Member count, invite code, my sharing switch and the member list. On
/// phones it fills the draggable sheet ([scrollController] and [handle]).
class MemberPanel extends StatelessWidget {
  const MemberPanel({
    super.key,
    required this.circle,
    required this.members,
    required this.myUid,
    required this.onFocus,
    this.scrollController,
    this.handle = false,
  });

  final Circle circle;
  final List<Member> members;
  final String? myUid;
  final ValueChanged<Member> onFocus;
  final ScrollController? scrollController;
  final bool handle;

  @override
  Widget build(BuildContext context) {
    final units = context.select<SettingsController, Units>((s) => s.units);
    final t = Theme.of(context).textTheme;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: Space.m),
      children: [
        if (handle)
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 2),
              decoration: BoxDecoration(
                color: AppColors.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.m, Space.xs, Space.s, 0),
          child: Row(
            children: [
              Expanded(child: Text(memberCount(members.length), style: t.titleMedium)),
              TextButton.icon(
                onPressed: () => showInviteSheet(context, circle),
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: Text(
                  circle.inviteCode,
                  style: const TextStyle(letterSpacing: 1.5, fontFeatures: kTabular),
                ),
              ),
            ],
          ),
        ),
        ShareTile(circleId: circle.id, compact: true),
        for (final m in members)
          MemberTile(
            key: ValueKey(m.uid),
            member: m,
            units: units,
            isMe: m.uid == myUid,
            isOwner: m.uid == circle.ownerUid,
            onTap: m.onMap ? () => onFocus(m) : null,
          ),
      ],
    );
  }
}
