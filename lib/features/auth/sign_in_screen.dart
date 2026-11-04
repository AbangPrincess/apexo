import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/login_throttle.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/responsive.dart';
import 'auth_widgets.dart';
import 'create_account_screen.dart';
import 'forgot_password_screen.dart';
import 'session_controller.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final ok = await context.read<SessionController>().signIn(_email.text, _password.text);
    if (ok) _password.clear();
  }

  void _openCreateAccount() {
    context.read<SessionController>().clearError();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const CreateAccountScreen()));
  }

  void _openForgotPassword() {
    context.read<SessionController>().clearError();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ForgotPasswordScreen(initialEmail: _email.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final lock = session.lockLeftFor(_email.text);
    final t = Theme.of(context).textTheme;
    final phone = MediaQuery.sizeOf(context).width < Breakpoints.expanded;
    final pending = session.pending;

    return AuthLayout(
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (phone) ...[
                const Align(alignment: Alignment.centerLeft, child: BrandMark(size: 36)),
                const SizedBox(height: Space.xl),
              ],
              Text('Welcome', style: t.headlineMedium),
              const SizedBox(height: Space.s),
              Text(
                'Track your rides, share live location with people you choose and guard your vehicles.',
                style: t.bodyLarge?.copyWith(color: AppColors.textMuted, height: 1.4),
              ),
              const SizedBox(height: Space.l),
              // The real backend has no demo account.
              if (session.isDemo) ...[
                FilledButton.icon(
                  onPressed: session.busy ? null : session.signInDemo,
                  icon: pending == SessionAction.demo
                      ? ButtonSpinner(color: AppColors.onInk)
                      : const Icon(Icons.play_arrow_rounded),
                  label: const Text('Continue with demo account'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
                const SizedBox(height: Space.s),
                Text(
                  'No sign-up needed. Demo data resets when you reload.',
                  textAlign: TextAlign.center,
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: Space.l),
                const OrDivider('or sign in with email'),
                const SizedBox(height: Space.l),
              ],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                textInputAction: TextInputAction.next,
                validator: validateEmail,
                onChanged: (_) {
                  session.clearError();
                  setState(() {}); // the lock applies per email
                },
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: Space.m),
              PasswordField(
                controller: _password,
                validator: (v) => (v ?? '').isEmpty ? 'Enter your password' : null,
                onChanged: (_) => session.clearError(),
                onSubmitted: _signIn,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: session.busy ? null : _openForgotPassword,
                  child: const Text('Forgot password?'),
                ),
              ),
              if (session.error != null) ...[
                const SizedBox(height: Space.s),
                ErrorBanner(session.error!),
              ],
              const SizedBox(height: Space.m),
              OutlinedButton(
                onPressed: session.busy || lock != null ? null : _signIn,
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: pending == SessionAction.signIn
                    ? const ButtonSpinner()
                    : Text(lock == null ? 'Sign in' : 'Try again in ${formatWait(lock)}'),
              ),
              const SizedBox(height: Space.m),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('New to Apexo?', style: t.bodyMedium),
                  TextButton(
                    onPressed: session.busy ? null : _openCreateAccount,
                    child: const Text('Create account'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
