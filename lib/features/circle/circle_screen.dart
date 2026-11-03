import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/geo.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../data/models/circle.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/map_view.dart';
import '../../widgets/member_avatar.dart';
import '../../widgets/responsive.dart';
import '../../widgets/visuals.dart';
import '../me/settings_controller.dart';
import 'circle_controller.dart';
import 'member_tile.dart';

class CircleScreen extends StatefulWidget {
  const CircleScreen({super.key});

  @override
  State<CircleScreen> createState() => _CircleScreenState();
}

class _CircleScreenState extends State<CircleScreen> {
  final _map = MapViewController();

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<CircleController>();
    final circle = ctrl.circle;

    return Scaffold(
      appBar: AppBar(
        title: Text(circle?.name ?? 'Circle'),
        actions: [
          if (circle != null)
            IconButton(
              tooltip: 'Invite people',
              icon: const Icon(Icons.person_add_alt_1_outlined),
              onPressed: () => showComingSoon(context, 'Sharing invites'),
            ),
          const SizedBox(width: Space.s),
        ],
      ),
      body: !ctrl.loaded
          ? const Center(child: CircularProgressIndicator.adaptive())
          : circle == null
          ? EmptyState(
              icon: Icons.people_outline_rounded,
              title: 'Ride with your people',
              message:
                  'Create a circle or join one with an invite code. Members see each '
                  'other live on the map, and only after they agree to share.',
              actionLabel: 'Create a circle',
              onAction: () => showComingSoon(context, 'Creating circles'),
              secondaryLabel: 'Join with a code',
              onSecondary: () => showComingSoon(context, 'Joining circles'),
            )
          : _body(context, ctrl, circle),
    );
  }

  Widget _body(BuildContext context, CircleController ctrl, Circle circle) {
    final sharing = ctrl.members.where((m) => m.sharing).toList();
    final map = RepaintBoundary(
      child: MapView(
        controller: _map,
        initialCenter: sharing.isEmpty ? _fallbackCenter : sharing.first.point,
        fitPoints: [for (final m in sharing) m.point],
        markers: [
          for (final m in sharing)
            MapMarker(
              id: m.uid,
              point: m.point,
              size: 52,
              child: MemberAvatar(
                initial: m.initial,
                ringColor: m.status.color,
                badge: m.vehicle?.type.icon,
                highlight: m.uid == ctrl.uid,
                outline: true,
                size: 48,
              ),
            ),
        ],
      ),
    );
    final panel = _MemberPanel(
      circle: circle,
      members: ctrl.members,
      myUid: ctrl.uid,
      onFocus: (m) => _map.focus(m.point),
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= Breakpoints.expanded) {
          return Row(
            children: [
              Expanded(child: map),
              const VerticalDivider(width: 1),
              SizedBox(width: 380, child: panel),
            ],
          );
        }
        return Column(
          children: [
            Expanded(flex: 11, child: map),
            const Divider(),
            Expanded(flex: 10, child: panel),
          ],
        );
      },
    );
  }
}

/// Map center used only when nobody in the circle is sharing.
const _fallbackCenter = GeoPoint(6.50, 124.85);

class _MemberPanel extends StatelessWidget {
  const _MemberPanel({
    required this.circle,
    required this.members,
    required this.myUid,
    required this.onFocus,
  });

  final Circle circle;
  final List<Member> members;
  final String? myUid;
  final ValueChanged<Member> onFocus;

  @override
  Widget build(BuildContext context) {
    final units = context.select<SettingsController, Units>((s) => s.units);
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.m, Space.m, Space.s, Space.s),
          child: Row(
            children: [
              Expanded(child: Text('${members.length} members', style: t.titleMedium)),
              Tooltip(
                message: 'Copy invite code',
                child: TextButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: circle.inviteCode));
                    messenger
                      ..hideCurrentSnackBar()
                      ..showSnackBar(const SnackBar(content: Text('Invite code copied')));
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(
                    circle.inviteCode,
                    style: const TextStyle(letterSpacing: 1.5, fontFeatures: kTabular),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: Space.m),
            itemCount: members.length,
            itemBuilder: (context, i) {
              final m = members[i];
              return MemberTile(
                key: ValueKey(m.uid),
                member: m,
                units: units,
                isMe: m.uid == myUid,
                isOwner: m.uid == circle.ownerUid,
                onTap: m.sharing ? () => onFocus(m) : null,
              );
            },
          ),
        ),
      ],
    );
  }
}
