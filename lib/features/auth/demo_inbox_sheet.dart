import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../data/fake/fake_auth.dart';
import '../../data/repository.dart';
import '../../widgets/time_ago.dart';
import 'auth_widgets.dart';
import 'password_checklist.dart';

/// Shows the emails the demo backend "sent" to [email]. Real emails are sent
/// once Firebase is connected (see README).
Future<void> showDemoInbox(BuildContext context, String email) {
  final repo = context.read<AppRepository>();
  if (repo is! DemoMailbox) return Future.value();
  final mailbox = repo as DemoMailbox;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (context, scroll) {
        final mail = mailbox.inbox(email);
        final t = Theme.of(context).textTheme;
        return ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(Space.m, 0, Space.m, Space.l),
          children: [
            Text('Demo inbox', style: t.titleLarge),
            const SizedBox(height: Space.xs),
            Text(
              'In the live app this email goes to $email. Demo mode shows it here instead.',
              style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: Space.m),
            if (mail.isEmpty) Text('No emails for this address yet.', style: t.bodyMedium),
            for (final e in mail) ...[
              _EmailCard(email: e, onAction: () => _act(sheet, mailbox, e)),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    ),
  );
}

Future<void> _act(BuildContext sheet, DemoMailbox mailbox, DemoEmail e) async {
  final messenger = ScaffoldMessenger.of(sheet);
  final navigator = Navigator.of(sheet);
  try {
    if (e.kind == DemoEmailKind.verify) {
      await mailbox.openVerifyLink(e);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Email verified. Welcome to Apexo!')));
      return;
    }
    final password = await _askNewPassword(sheet);
    if (password == null) return;
    await mailbox.resetPassword(e, password);
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Password updated. Sign in with your new password.')),
    );
  } on AuthException catch (err) {
    messenger.showSnackBar(SnackBar(content: Text(err.message)));
  }
}

Future<String?> _askNewPassword(BuildContext context) {
  final controller = TextEditingController();
  final form = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Choose a new password'),
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PasswordField(controller: controller, newPassword: true, validator: validatePassword),
            const SizedBox(height: Space.s),
            PasswordChecklist(controller: controller),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (form.currentState?.validate() ?? false) Navigator.pop(ctx, controller.text);
          },
          child: const Text('Save password'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

class _EmailCard extends StatelessWidget {
  const _EmailCard({required this.email, required this.onAction});

  final DemoEmail email;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = t.bodySmall?.copyWith(color: AppColors.textMuted);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mail_outline_rounded, size: 18, color: AppColors.accent),
                const SizedBox(width: Space.s),
                Expanded(child: Text('Apexo', style: t.labelLarge)),
                TimeAgo(email.sentAt, style: muted),
              ],
            ),
            const SizedBox(height: Space.s),
            Text(email.subject, style: t.titleMedium),
            const SizedBox(height: Space.xs),
            Text(email.body, style: t.bodyMedium?.copyWith(height: 1.4)),
            const SizedBox(height: 12),
            if (email.usable)
              FilledButton(onPressed: onAction, child: Text(email.actionLabel))
            else
              Text(
                email.used ? 'Link already used' : 'Link expired, a newer email was sent',
                style: muted,
              ),
          ],
        ),
      ),
    );
  }
}
