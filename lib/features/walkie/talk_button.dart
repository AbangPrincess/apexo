import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/units.dart';
import '../../widgets/permission_rationale.dart';
import 'walkie_controller.dart';

/// The push-to-talk button, big enough to hit with gloves. Hold it while
/// you talk and let go to send, or tap once, talk, and tap again to send.
/// While talking it turns red and shows the seconds.
class TalkButton extends StatefulWidget {
  const TalkButton({super.key, this.size = 64, this.onDark = false});

  final double size;

  /// On the dark recording cockpit.
  final bool onDark;

  @override
  State<TalkButton> createState() => _TalkButtonState();
}

class _TalkButtonState extends State<TalkButton> {
  bool _pressed = false;
  bool _toggle = false;
  DateTime _downAt = clock.now();

  Future<void> _down(WalkieController w) async {
    if (w.talking && _toggle) return _send(w);
    if (w.talk != TalkState.idle) return;
    _pressed = true;
    _downAt = clock.now();
    if (!w.micReady && !await w.hasMicAccess()) {
      // First time: explain, then the system asks. Press again to talk.
      _pressed = false;
      if (!mounted) return;
      if (await explainPermission(context, PermissionNeed.microphone)) await w.requestMicAccess();
      return;
    }
    w.micReady = true;
    unawaited(HapticFeedback.mediumImpact());
    await w.startTalking();
  }

  void _up(WalkieController w) {
    if (!_pressed) return;
    _pressed = false;
    if (clock.now().difference(_downAt) < const Duration(milliseconds: 400)) {
      // A tap: keep talking until the next tap.
      setState(() => _toggle = true);
      return;
    }
    _send(w);
  }

  void _send(WalkieController w) {
    _toggle = false;
    unawaited(HapticFeedback.lightImpact());
    w.stopAndSend();
  }

  void _cancel(WalkieController w) {
    if (!_pressed) return;
    _pressed = false;
    w.cancelTalking();
  }

  @override
  Widget build(BuildContext context) {
    final w = context.watch<WalkieController>();
    if (!w.available) return const SizedBox.shrink();
    if (!w.talking) _toggle = false;
    final live = w.talk == TalkState.recording;
    final fill = live
        ? AppColors.alert
        : widget.onDark
        ? AppColors.darkRaised
        : AppColors.ink;
    final fg = live || widget.onDark ? Colors.white : AppColors.onInk;
    final Widget face = switch (w.talk) {
      TalkState.recording => Text(
        formatDuration(w.talkTime.inSeconds),
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: widget.size * 0.24,
          fontFeatures: kTabular,
        ),
      ),
      TalkState.sending || TalkState.starting => SizedBox.square(
        dimension: widget.size * 0.36,
        child: CircularProgressIndicator(strokeWidth: 3, color: fg),
      ),
      TalkState.idle => Icon(Icons.mic_rounded, color: fg, size: widget.size * 0.46),
    };
    return Semantics(
      button: true,
      label: live ? 'Talking, ${w.talkTime.inSeconds} seconds' : 'Talk to your circle',
      hint: w.talking ? 'Double tap to send' : 'Double tap to start talking',
      excludeSemantics: true,
      onTap: () => w.talking ? _send(w) : _down(w).then((_) => setState(() => _toggle = true)),
      child: Listener(
        onPointerDown: (_) => _down(w),
        onPointerUp: (_) => _up(w),
        onPointerCancel: (_) => _cancel(w),
        // Claims drags so the sheet doesn't scroll while you hold it.
        child: GestureDetector(
          onVerticalDragStart: (_) {},
          onHorizontalDragStart: (_) {},
          child: AnimatedContainer(
            key: const ValueKey('talk-button'),
            duration: kMotion,
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: widget.onDark && !live
                  ? Border.all(color: AppColors.darkLine, width: 2)
                  : null,
              boxShadow: live
                  ? [BoxShadow(color: AppColors.alert.withValues(alpha: 0.45), spreadRadius: 6)]
                  : null,
            ),
            child: face,
          ),
        ),
      ),
    );
  }
}
