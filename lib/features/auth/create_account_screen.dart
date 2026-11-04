import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/validators.dart';
import 'auth_widgets.dart';
import 'password_checklist.dart';
import 'session_controller.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final navigator = Navigator.of(context);
    final ok = await context.read<SessionController>().createAccount(
      _name.text,
      _email.text,
      _password.text,
    );
    // Signed in: drop this route so the app shell shows.
    if (ok && mounted) navigator.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final t = Theme.of(context).textTheme;

    return AuthLayout(
      showBack: true,
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Space.l),
              Text('Create your account', style: t.headlineMedium),
              const SizedBox(height: Space.s),
              Text(
                'Your location stays private until you join a circle and agree to share it.',
                style: t.bodyLarge?.copyWith(color: AppColors.textMuted, height: 1.4),
              ),
              const SizedBox(height: Space.l),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                validator: validateDisplayName,
                onChanged: (_) => session.clearError(),
                decoration: const InputDecoration(
                  labelText: 'Name',
                  helperText: 'Shown to people in your circles',
                ),
              ),
              const SizedBox(height: Space.m),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                textInputAction: TextInputAction.next,
                validator: validateEmail,
                onChanged: (_) => session.clearError(),
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: Space.m),
              PasswordField(
                controller: _password,
                newPassword: true,
                validator: validatePassword,
                onChanged: (_) => session.clearError(),
                onSubmitted: _create,
              ),
              const SizedBox(height: Space.s),
              PasswordChecklist(controller: _password),
              if (session.error != null) ...[
                const SizedBox(height: Space.m),
                ErrorBanner(session.error!),
              ],
              const SizedBox(height: Space.l),
              FilledButton(
                onPressed: session.busy ? null : _create,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: session.pending == SessionAction.createAccount
                    ? ButtonSpinner(color: AppColors.onInk)
                    : const Text('Create account'),
              ),
              const SizedBox(height: Space.m),
              Text(
                "We'll email you a link to confirm it's really you before the account opens.",
                textAlign: TextAlign.center,
                style: t.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
              if (session.isDemo) ...[
                const SizedBox(height: Space.s),
                Text(
                  'Demo mode: accounts are kept in memory and cleared when you reload.',
                  textAlign: TextAlign.center,
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
