import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/responsive.dart';
import '../auth/auth_widgets.dart';

/// Explicit consent before any location is shared with a circle (SPEC G1).
/// Both choices complete the join or create; only the first shares.
class ConsentView extends StatelessWidget {
  const ConsentView({
    super.key,
    required this.circleName,
    required this.shareLabel,
    required this.pausedLabel,
    required this.onChoose,
    this.details,
    this.busy = false,
    this.error,
  });

  final String circleName;

  /// e.g. "3 members · Owner: John".
  final String? details;
  final String shareLabel;
  final String pausedLabel;
  final ValueChanged<bool> onChoose;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    // The choices stay pinned within thumb reach; the explanation scrolls.
    return Column(
      children: [
        Expanded(child: _explanation(t)),
        const Divider(),
        MaxWidth(
          maxWidth: 520,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.m, Space.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null) ...[ErrorBanner(error!), const SizedBox(height: Space.s)],
                FilledButton(
                  onPressed: busy ? null : () => onChoose(true),
                  child: busy ? ButtonSpinner(color: AppColors.onInk) : Text(shareLabel),
                ),
                const SizedBox(height: Space.xs),
                TextButton(
                  onPressed: busy ? null : () => onChoose(false),
                  child: Text(pausedLabel),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _explanation(TextTheme t) {
    return PageListView(
      maxWidth: 520,
      children: [
        const SizedBox(height: Space.m),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: AppColors.surfaceAlt, shape: BoxShape.circle),
            child: Icon(Icons.share_location_rounded, size: 32, color: AppColors.ink),
          ),
        ),
        const SizedBox(height: Space.l),
        Text(
          'Share your location with $circleName?',
          style: t.headlineSmall,
          textAlign: TextAlign.center,
        ),
        if (details != null) ...[
          const SizedBox(height: Space.s),
          Text(
            details!,
            style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: Space.l),
        const _Point(
          Icons.place_outlined,
          'Members see your live position, speed, battery and vehicle status while sharing is on.',
        ),
        const _Point(
          Icons.visibility_outlined,
          'A "Sharing live" bar shows in Apexo whenever it is on, and Android also shows a notification.',
        ),
        const _Point(
          Icons.pause_circle_outline_rounded,
          'Pause sharing for this circle or leave it at any time.',
        ),
        const _Point(
          Icons.lock_outline_rounded,
          'Only members of this circle can see it. Pausing also hides your last position.',
        ),
      ],
    );
  }
}

class _Point extends StatelessWidget {
  const _Point(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.m),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.ink),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4)),
        ),
      ],
    ),
  );
}
