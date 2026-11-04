import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/login_throttle.dart';
import '../../core/theme.dart';
import '../../widgets/visuals.dart';
import 'auth_widgets.dart';
import 'demo_inbox_sheet.dart';
import 'session_controller.dart';

/// Holds a new account here until its email is verified.
class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key});

  Future<void> _resend(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await context.read<SessionController>().resendVerification()) {
      messenger.showSnackBar(const SnackBar(content: Text('Verification email sent.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final email = session.user?.email ?? '';
    final t = Theme.of(context).textTheme;
    final cooldown = session.cooldownLeft;
    final muted = t.bodyMedium?.copyWith(color: AppColors.textMuted, height: 1.45);

    return AuthLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: IconTile(icon: Icons.mark_email_unread_outlined, size: 56),
          ),
          const SizedBox(height: Space.l),
          Text('Check your email', style: t.headlineMedium),
          const SizedBox(height: Space.s),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'We sent a verification link to '),
                TextSpan(
                  text: email,
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
                ),
                const TextSpan(text: '. Open it to activate your account.'),
              ],
            ),
            style: muted,
          ),
          const SizedBox(height: Space.m),
          const _SpamTip(),
          if (session.error != null) ...[
            const SizedBox(height: Space.m),
            ErrorBanner(session.error!),
          ],
          const SizedBox(height: Space.l),
          FilledButton(
            onPressed: session.busy ? null : session.checkVerified,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: session.pending == SessionAction.reload
                ? ButtonSpinner(color: AppColors.onInk)
                : const Text("I've verified my email"),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: session.busy || cooldown != null ? null : () => _resend(context),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: session.pending == SessionAction.resend
                ? const ButtonSpinner()
                : Text(cooldown == null ? 'Resend email' : 'Resend in ${formatWait(cooldown)}'),
          ),
          if (session.isDemo) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => showDemoInbox(context, email),
              icon: const Icon(Icons.inbox_outlined),
              label: const Text('Open demo inbox'),
            ),
          ],
          const SizedBox(height: Space.m),
          TextButton(
            onPressed: session.busy ? null : session.signOut,
            child: const Text('Use a different email'),
          ),
        ],
      ),
    );
  }
}

/// Most "it never came" reports are a link sitting in Spam, so say where
/// to look before anything else.
class _SpamTip extends StatelessWidget {
  const _SpamTip();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final line = t.bodyMedium?.copyWith(height: 1.35);
    return Container(
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.report_outlined, color: AppColors.text),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Not in your inbox?', style: t.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Look in Spam or Junk (Gmail: also Promotions), or search your mail for '
                  '"Apexo". It can take a minute to arrive.',
                  style: line,
                ),
                const SizedBox(height: 4),
                Text('Found it in Spam? Mark it "Not spam", then open the link.', style: line),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
