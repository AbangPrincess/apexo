import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/activity_type.dart';
import '../../core/geo.dart';
import '../../core/ride_tracker.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../widgets/map_view.dart';
import '../../widgets/responsive.dart';
import '../auth/auth_widgets.dart';
import 'live_map.dart';
import 'record_controller.dart';
import 'record_widgets.dart';
import '../walkie/walkie_card.dart';

/// While recording: a live street map that fills nearly the whole screen
/// and follows you (the route so far, where you are and the GPS accuracy
/// ring) with the controls floating on it, then a slim stats strip. Pan
/// the map and it stops following until you tap re-center.
class LiveRideView extends StatefulWidget {
  const LiveRideView({super.key, required this.units, required this.onFinish});

  final Units units;
  final VoidCallback onFinish;

  @override
  State<LiveRideView> createState() => _LiveRideViewState();
}

class _LiveRideViewState extends State<LiveRideView> {
  final _map = MapViewController();
  bool _follow = true;
  GeoPoint? _followed;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _keepCentered(GeoPoint? p, {bool force = false}) {
    if (p == null || (!force && (!_follow || p == _followed))) return;
    _followed = p;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _map.follow(p);
      } catch (_) {
        // The map's first frame is not laid out yet; it opened on [p].
      }
    });
  }

  void _recenter(GeoPoint? p) {
    setState(() => _follow = true);
    _keepCentered(p, force: true);
  }

  @override
  Widget build(BuildContext context) {
    final rec = context.watch<RecordController>();
    final here = rec.position;
    _keepCentered(here);

    Widget controls({required bool onMap}) => _Controls(
      paused: rec.state == RideState.paused,
      onPause: rec.pause,
      onResume: rec.resume,
      onFinish: widget.onFinish,
      onMap: onMap,
    );
    Widget map({Widget? controls, Widget? talk}) => LiveMap(
      controller: _map,
      position: here,
      accuracyM: rec.accuracyM,
      path: rec.path,
      following: _follow,
      onUserMove: () {
        if (_follow) setState(() => _follow = false);
      },
      onRecenter: () => _recenter(here),
      status: RecordStatusPill(
        state: rec.state,
        simulated: rec.source.simulated,
        waiting: rec.waiting,
      ),
      controls: controls,
      talk: talk,
    );
    Widget stats({bool oneRow = false}) => RecordStats(
      units: widget.units,
      type: rec.type ?? ActivityType.cycling,
      movingTime: rec.movingTime,
      distanceM: rec.distanceM,
      speedKmh: rec.currentKmh,
      avgKmh: rec.avgKmh,
      dark: true,
      oneRow: oneRow,
    );
    final error = rec.error;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= Breakpoints.expanded) {
            return Padding(
              padding: const EdgeInsets.all(Space.m),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: map()),
                  const SizedBox(width: Space.m),
                  SizedBox(
                    width: 380,
                    child: Column(
                      children: [
                        stats(),
                        if (error != null) ...[const SizedBox(height: Space.m), ErrorBanner(error)],
                        const Spacer(),
                        const Align(alignment: Alignment.centerLeft, child: WalkieOnMap()),
                        const SizedBox(height: Space.m),
                        controls(onMap: false),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          // Phones: the map takes everything but a slim stats strip, with the
          // controls floating on it. Very short screens (a phone on its side)
          // scroll, with the map at a fixed height.
          final short = c.maxHeight < 420;
          final onMap = map(controls: controls(onMap: true), talk: const WalkieOnMap());
          final column = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (short) SizedBox(height: 300, child: onMap) else Expanded(child: onMap),
              if (error != null) ...[const SizedBox(height: Space.s), ErrorBanner(error)],
              const SizedBox(height: Space.s),
              stats(oneRow: true),
            ],
          );
          final padded = Padding(
            padding: const EdgeInsets.fromLTRB(Space.s, Space.s, Space.s, Space.s),
            child: column,
          );
          return short ? SingleChildScrollView(child: padded) : padded;
        },
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.paused,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
    required this.onMap,
  });

  final bool paused;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;

  /// Floating on the map: a little smaller and side by side in the middle.
  final bool onMap;

  @override
  Widget build(BuildContext context) {
    final size = onMap ? 72.0 : 84.0;
    final buttons = paused
        ? [
            RoundAction(
              label: 'RESUME',
              icon: Icons.play_arrow_rounded,
              color: AppColors.tracking,
              onPressed: onResume,
              size: size,
            ),
            if (onMap) const SizedBox(width: Space.xl),
            RoundAction(
              label: 'FINISH',
              icon: Icons.stop_rounded,
              color: AppColors.alert,
              onPressed: onFinish,
              size: size,
            ),
          ]
        : [
            RoundAction(
              label: 'PAUSE',
              icon: Icons.pause_rounded,
              color: AppColors.darkRaised,
              border: AppColors.darkLine,
              onPressed: onPause,
              size: size,
            ),
          ];
    return Row(
      mainAxisAlignment: onMap ? MainAxisAlignment.center : MainAxisAlignment.spaceEvenly,
      children: buttons,
    );
  }
}
