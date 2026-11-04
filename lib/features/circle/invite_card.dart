import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../data/models/circle.dart';

void _snack(ScaffoldMessengerState messenger, String text) => messenger
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));

/// Opens the system share sheet; copies the invite where sharing is not
/// available (some desktop browsers).
Future<void> shareInvite(BuildContext context, Circle circle) async {
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null || !box.hasSize ? null : box.localToGlobal(Offset.zero) & box.size;
  final messenger = ScaffoldMessenger.of(context);
  final text = 'Join my circle "${circle.name}" on Apexo with invite code ${circle.inviteCode}';
  try {
    await SharePlus.instance.share(
      ShareParams(text: text, subject: 'Join ${circle.name} on Apexo', sharePositionOrigin: origin),
    );
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: text));
    _snack(messenger, 'Invite copied. Paste it in a message.');
  }
}

Future<void> copyInviteCode(BuildContext context, String code) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: code));
  _snack(messenger, 'Invite code copied');
}

Future<void> showInviteSheet(BuildContext context, Circle circle) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.m, 0, Space.m, Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Invite to ${circle.name}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Space.m),
          InviteCodeCard(circle: circle),
        ],
      ),
    ),
  ),
);

/// The invite code in large type, with Share and Copy.
class InviteCodeCard extends StatelessWidget {
  const InviteCodeCard({super.key, required this.circle});

  final Circle circle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final code = circle.inviteCode;
    return Container(
      padding: const EdgeInsets.all(Space.l),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text('Invite code', style: t.labelLarge?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: Space.s),
          Semantics(
            label: 'Invite code ${code.split('').join(' ')}',
            excludeSemantics: true,
            child: FittedBox(
              child: Text(
                code,
                key: const ValueKey('invite-code'),
                style: t.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6,
                  fontFeatures: kTabular,
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.s),
          Text(
            'Friends open Circle, tap "Join with a code" and enter it.',
            textAlign: TextAlign.center,
            style: t.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: Space.m),
          Row(
            children: [
              Expanded(
                child: Builder(
                  builder: (context) => FilledButton.icon(
                    onPressed: () => shareInvite(context, circle),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('Share'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => copyInviteCode(context, code),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
