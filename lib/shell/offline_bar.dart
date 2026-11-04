import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';

/// "You're offline" on every tab while the device has no network. Saved
/// data keeps working from the local copy and syncs later; maps and the
/// weather wait for the connection.
class OfflineBar extends StatefulWidget {
  const OfflineBar({super.key, this.online});

  /// True when online. Defaults to the device's connectivity.
  final Stream<bool>? online;

  @override
  State<OfflineBar> createState() => _OfflineBarState();
}

class _OfflineBarState extends State<OfflineBar> {
  StreamSubscription<bool>? _sub;
  bool _online = true;

  @override
  void initState() {
    super.initState();
    _sub = (widget.online ?? _device()).listen(
      (v) => setState(() => _online = v),
      // Unknown (no plugin, e.g. in tests) counts as online.
      onError: (Object _) {},
    );
  }

  static Stream<bool> _device() async* {
    final c = Connectivity();
    bool has(List<ConnectivityResult> r) => r.any((x) => x != ConnectivityResult.none);
    yield has(await c.checkConnectivity());
    yield* c.onConnectivityChanged.map(has);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AnimatedSize(
      duration: kMotion,
      alignment: Alignment.topCenter,
      child: _online
          ? const SizedBox(width: double.infinity)
          : Semantics(
              liveRegion: true,
              child: Material(
                color: AppColors.darkRaised,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 18, color: AppColors.caution),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "You're offline. Changes sync when you're back.",
                          maxLines: 2,
                          style: t.bodyMedium?.copyWith(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
