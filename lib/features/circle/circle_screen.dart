import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/geo.dart';
import '../../core/theme.dart';
import '../../data/models/circle.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/map_view.dart';
import '../../widgets/member_avatar.dart';
import '../../widgets/responsive.dart';
import '../../widgets/visuals.dart';
import 'circle_controller.dart';
import 'circle_switcher.dart';
import 'invite_card.dart';
import 'member_panel.dart';
import 'members_screen.dart';
import 'sharing_controller.dart';

class CircleScreen extends StatefulWidget {
  const CircleScreen({super.key});

  @override
  State<CircleScreen> createState() => _CircleScreenState();
}

class _CircleScreenState extends State<CircleScreen> {
  final _map = MapViewController();
  final _sheet = DraggableScrollableController();

  /// Where locate-me found me while I am not sharing (shown only to me).
  GeoPoint? _here;

  static const _sheetStart = 0.45;

  @override
  void dispose() {
    _map.dispose();
    _sheet.dispose();
    super.dispose();
  }

  Future<void> _locate(Member? me) async {
    if (me != null && me.onMap) {
      _map.focus(me.point);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final p = await context.read<SharingController>().locate();
    if (!mounted) return;
    if (p == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Allow location access to see where you are.')),
        );
      return;
    }
    setState(() => _here = p);
    _map.focus(p);
  }

  void _openMembers() =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MembersScreen()));

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<CircleController>();
    final circle = ctrl.circle;

    return Scaffold(
      appBar: AppBar(
        title: circle == null ? const Text('Circle') : const CircleSwitcher(),
        actions: [
          if (circle != null) ...[
            IconButton(
              tooltip: 'Invite people',
              icon: const Icon(Icons.person_add_alt_1_outlined),
              onPressed: () => showInviteSheet(context, circle),
            ),
            IconButton(
              tooltip: 'Members and sharing',
              icon: const Icon(Icons.manage_accounts_outlined),
              onPressed: _openMembers,
            ),
          ],
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
              onAction: () => openCreateCircle(context),
              secondaryLabel: 'Join with a code',
              onSecondary: () => openJoinCircle(context),
            )
          : _body(context, ctrl, circle),
    );
  }

  Widget _body(BuildContext context, CircleController ctrl, Circle circle) {
    final me = ctrl.me;
    final onMap = ctrl.members.where((m) => m.onMap).toList();
    final here = me != null && me.onMap ? null : _here;
    final map = RepaintBoundary(
      child: MapView(
        controller: _map,
        initialCenter: onMap.isEmpty ? (here ?? _fallbackCenter) : onMap.first.point,
        fitPoints: [for (final m in onMap) m.point],
        markers: [
          for (final m in onMap)
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
          if (here != null) MapMarker(id: 'here', point: here, size: 22, child: const _HereDot()),
        ],
      ),
    );
    final locate = FloatingActionButton.small(
      heroTag: null,
      tooltip: 'Show my location',
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.ink,
      elevation: 0,
      shape: const CircleBorder(side: BorderSide(color: AppColors.hairline)),
      onPressed: () => _locate(me),
      child: const Icon(Icons.my_location_rounded),
    );
    MemberPanel panel({ScrollController? scroll}) => MemberPanel(
      circle: circle,
      members: ctrl.members,
      myUid: ctrl.uid,
      onFocus: (m) => _map.focus(m.point),
      scrollController: scroll,
      handle: scroll != null,
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= Breakpoints.expanded) {
          return Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: map),
                    Positioned(right: Space.m, bottom: Space.xl, child: locate),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              SizedBox(width: 380, child: panel()),
            ],
          );
        }
        return Stack(
          children: [
            Positioned.fill(child: map),
            // Rides just above the sheet; hidden once the sheet covers the map.
            AnimatedBuilder(
              animation: _sheet,
              builder: (context, _) {
                final size = _sheet.isAttached ? _sheet.size : _sheetStart;
                if (size > 0.75) return const SizedBox.shrink();
                return Positioned(right: Space.m, bottom: size * c.maxHeight + 12, child: locate);
              },
            ),
            DraggableScrollableSheet(
              controller: _sheet,
              initialChildSize: _sheetStart,
              minChildSize: 0.16,
              maxChildSize: 0.92,
              snap: true,
              snapSizes: const [_sheetStart],
              builder: (context, scroll) => DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(top: BorderSide(color: AppColors.hairline)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Material(
                    type: MaterialType.transparency,
                    child: panel(scroll: scroll),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Map center used only when nobody in the circle is sharing.
const _fallbackCenter = GeoPoint(6.50, 124.85);

class _HereDot extends StatelessWidget {
  const _HereDot();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'You are here (not shared)',
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.ink,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
    ),
  );
}
