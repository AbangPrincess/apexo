import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/login_throttle.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import 'auth_widgets.dart';
import 'demo_inbox_sheet.dart';
import 'session_controller.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final ok = await context.read<SessionController>().sendPasswordReset(_email.text.trim());
    if (ok && mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final t = Theme.of(context).textTheme;
    final cooldown = session.cooldownLeft;
    final muted = t.bodyLarge?.copyWith(color: AppColors.textMuted, height: 1.4);

    return AuthLayout(
      showBack: true,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: Space.l),
            Text(_sent ? 'Check your email' : 'Reset your password', style: t.headlineMedium),
            const SizedBox(height: Space.s),
            Text(
              _sent
                  ? 'If an account exists for ${_email.text.trim()}, we sent a link to reset its password.'
                  : "Enter your account's email and we'll send you a link to set a new password.",
              style: muted,
            ),
            const SizedBox(height: Space.l),
            if (!_sent)
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                validator: validateEmail,
                onFieldSubmitted: (_) => _send(),
                decoration: const InputDecoration(labelText: 'Email'),
              ),
            if (session.error != null) ...[
              const SizedBox(height: Space.m),
              ErrorBanner(session.error!),
            ],
            const SizedBox(height: Space.l),
            FilledButton(
              onPressed: session.busy || cooldown != null ? null : _send,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: session.pending == SessionAction.reset
                  ? const ButtonSpinner(color: Colors.white)
                  : Text(
                      cooldown != null
                          ? 'Send again in ${formatWait(cooldown)}'
                          : _sent
                          ? 'Send again'
                          : 'Send reset link',
                    ),
            ),
            if (_sent && session.isDemo) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => showDemoInbox(context, _email.text.trim()),
                icon: const Icon(Icons.inbox_outlined),
                label: const Text('Open demo inbox'),
              ),
            ],
            if (_sent)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to sign in'),
              ),
          ],
        ),
      ),
    );
  }
}
