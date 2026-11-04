import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/units.dart';
import '../../data/models/circle.dart';
import '../../data/models/public_profile.dart';
import '../../widgets/cover_photo.dart';
import '../../widgets/profile_image.dart';
import '../../widgets/time_ago.dart';
import '../../widgets/visuals.dart';
import '../feed/activity_card.dart';
import '../feed/activity_detail_screen.dart';
import '../feed/circle_feed_controller.dart';
import '../me/settings_controller.dart';
import 'circle_controller.dart';
import 'member_tile.dart';

/// Opens what [member] shows the circle. [onShowOnMap] closes it and
/// centers the map on them.
Future<void> openMemberProfile(
  BuildContext context,
  Member member, {
  required bool isMe,
  required bool isOwner,
  VoidCallback? onShowOnMap,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) =>
        MemberProfileScreen(member: member, isMe: isMe, isOwner: isOwner, onShowOnMap: onShowOnMap),
  ),
);

/// A circle member's cover, photo, name, hometown, bio, live status and
/// the rides they shared with the circle. Never their email.
class MemberProfileScreen extends StatefulWidget {
  const MemberProfileScreen({
    super.key,
    required this.member,
    required this.isMe,
    required this.isOwner,
    this.onShowOnMap,
  });

  final Member member;
  final bool isMe;
  final bool isOwner;
  final VoidCallback? onShowOnMap;

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  late final Future<PublicProfile?> _profile = context.read<CircleController>().profileOf(
    widget.member.uid,
  );

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    return Scaffold(
      appBar: AppBar(title: Text(widget.isMe ? 'How your circle sees you' : m.displayName)),
      body: FutureBuilder<PublicProfile?>(
        future: _profile,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          // Not published yet (or offline): the name from the member list.
          final p = snap.data ?? PublicProfile(uid: m.uid, displayName: m.displayName);
          return LayoutBuilder(
            builder: (context, c) {
              final width = c.maxWidth.clamp(0.0, 720.0);
              return Center(
                child: SizedBox(width: width, child: _body(context, p, width)),
              );
            },
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, PublicProfile p, double width) {
    final t = Theme.of(context).textTheme;
    final m = widget.member;
    final units = context.select<SettingsController, Units>((s) => s.units);
    final rides = [
      for (final s in context.watch<CircleFeedController>().items)
        if (s.ownerUid == m.uid) s,
    ];
    final coverH = coverHeightFor(width);
    const r = 48.0;
    final muted = t.bodyMedium?.copyWith(color: AppColors.textMuted);
    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xl),
      children: [
        SizedBox(
          height: coverH + r * 1.1,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: coverH,
                child: CoverPhoto(url: p.coverUrl),
              ),
              Positioned(
                left: Space.m,
                top: coverH - r * 1.15,
                child: UserAvatar(photoUrl: p.photoUrl, initial: p.initial, radius: r, ring: 4),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(child: Text(p.displayName, style: t.headlineSmall, maxLines: 2)),
                  if (widget.isOwner) const MemberTag('Owner'),
                ],
              ),
              if (p.hometown.isNotEmpty) ...[
                const SizedBox(height: Space.xs),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Flexible(child: Text(p.hometown, style: muted)),
                  ],
                ),
              ],
              if (p.bio.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(p.bio, style: t.bodyLarge?.copyWith(height: 1.4)),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    m.vehicle?.type.icon ?? Icons.person_outline,
                    size: 18,
                    color: m.status.color,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: m.sharing
                        ? TimeAgo(m.ts, prefix: '${m.status.label} · ', style: muted)
                        : Text(m.status.label, style: muted),
                  ),
                ],
              ),
              if (widget.onShowOnMap != null && m.onMap) ...[
                const SizedBox(height: Space.m),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onShowOnMap!();
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Show on map'),
                ),
              ],
              const SizedBox(height: Space.l),
              Text('Shared with the circle', style: t.titleMedium),
              const SizedBox(height: Space.s),
              if (rides.isEmpty)
                Text('No shared activities yet.', style: muted)
              else
                for (final s in rides.take(10)) ...[
                  ActivityCard(
                    activity: s.activity,
                    units: units,
                    now: DateTime.now(),
                    ownerName: s.ownerName,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ActivityDetailScreen(activity: s.activity, ownerName: s.ownerName),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.s),
                ],
            ],
          ),
        ),
      ],
    );
  }
}
