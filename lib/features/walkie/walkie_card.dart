import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/units.dart';
import '../../data/models/voice_clip.dart';
import '../../widgets/time_ago.dart';
import 'talk_button.dart';
import 'walkie_controller.dart';

/// The circle's walkie-talkie on the Circle tab: the Talk button, auto-play
/// and the latest messages to replay.
class WalkieCard extends StatelessWidget {
  const WalkieCard({super.key});

  @override
  Widget build(BuildContext context) {
    final w = context.watch<WalkieController>();
    if (!w.available) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final muted = t.bodySmall?.copyWith(color: AppColors.textMuted);
    final status = switch (w.talk) {
      TalkState.starting => 'Starting the microphone…',
      TalkState.recording => 'Talking · let go (or tap) to send',
      TalkState.sending => 'Sending…',
      TalkState.idle => 'Hold to talk, or tap, talk and tap again.',
    };
    return Card(
      key: const ValueKey('walkie-card'),
      margin: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.m, Space.xs),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.s, Space.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.settings_voice_outlined, size: 20, color: AppColors.text),
                const SizedBox(width: Space.s),
                Expanded(child: Text('Walkie-talkie', style: t.titleSmall)),
                Text('Auto-play', style: muted),
                Semantics(
                  label: 'Play new messages by themselves',
                  child: Switch.adaptive(value: w.autoPlay, onChanged: w.setAutoPlay),
                ),
              ],
            ),
            Row(
              children: [
                const TalkButton(),
                const SizedBox(width: Space.m),
                Expanded(child: Text(status, style: t.bodyMedium)),
              ],
            ),
            if (w.error != null)
              Padding(
                padding: const EdgeInsets.only(top: Space.s),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(w.error!, style: t.bodySmall?.copyWith(color: AppColors.alert)),
                    ),
                    IconButton(
                      tooltip: 'Dismiss',
                      onPressed: w.clearError,
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: Space.xs),
            if (w.clips.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.s),
                child: Text('No messages in the last 24 hours.', style: muted),
              )
            else ...[
              for (final c in w.clips.take(3)) VoiceClipTile(c),
              if (w.clips.length > 3)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => showVoiceMessages(context),
                    child: Text('All messages (${w.clips.length})'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One message: who, when, how long, and play or stop.
class VoiceClipTile extends StatelessWidget {
  const VoiceClipTile(this.clip, {super.key});

  final VoiceClip clip;

  @override
  Widget build(BuildContext context) {
    final w = context.watch<WalkieController>();
    final t = Theme.of(context).textTheme;
    final muted = t.bodySmall?.copyWith(color: AppColors.textMuted);
    final playing = w.playingId == clip.id;
    final name = w.isMine(clip) ? 'You' : clip.fromName;
    final sent = clip.sentAt;
    return ListTile(
      key: ValueKey('clip-${clip.id}'),
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: playing ? AppColors.tracking : AppColors.surfaceAlt,
        foregroundColor: playing ? AppColors.on(AppColors.tracking) : AppColors.text,
        child: Text(clip.initial),
      ),
      title: Text(name, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: sent == null
          ? Text('Sending…', style: muted)
          : TimeAgo(sent, style: muted, suffix: ' · ${formatDuration(clip.duration.inSeconds)}'),
      trailing: IconButton(
        tooltip: playing ? 'Stop' : 'Play $name\'s message',
        onPressed: () => playing ? w.stopPlaying() : w.play(clip),
        icon: Icon(playing ? Icons.stop_circle_outlined : Icons.play_circle_outline_rounded),
      ),
      onTap: () => playing ? w.stopPlaying() : w.play(clip),
    );
  }
}

/// Every message of the last 24 hours, to replay.
Future<void> showVoiceMessages(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (sheet) => SafeArea(
    child: Consumer<WalkieController>(
      builder: (context, w, _) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(Space.m, 0, Space.m, Space.m),
        children: [
          Text('Walkie-talkie messages', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Space.s),
          for (final c in w.clips) VoiceClipTile(c),
        ],
      ),
    ),
  ),
);

/// On the ride map: who is talking right now, over the Talk button.
class WalkieOnMap extends StatelessWidget {
  const WalkieOnMap({super.key});

  @override
  Widget build(BuildContext context) {
    final w = context.watch<WalkieController>();
    if (!w.available) return const SizedBox.shrink();
    final id = w.playingId;
    final speaking = id == null ? null : w.clips.where((c) => c.id == id).firstOrNull;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (speaking != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: ActionChip(
              avatar: const Icon(Icons.volume_up_rounded, size: 18, color: Colors.white),
              label: Text(w.isMine(speaking) ? 'You' : speaking.fromName),
              labelStyle: const TextStyle(color: Colors.white),
              backgroundColor: AppColors.darkRaised,
              side: const BorderSide(color: AppColors.darkLine),
              onPressed: w.stopPlaying,
              tooltip: 'Stop',
            ),
          ),
        const TalkButton(size: 60, onDark: true),
      ],
    );
  }
}
