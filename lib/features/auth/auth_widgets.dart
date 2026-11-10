import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/responsive.dart';
import '../../widgets/visuals.dart';

/// Phones: a single centered column. Wide screens: brand panel + form.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.child, this.showBack = false});

  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= Breakpoints.expanded;
        final form = SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.xl),
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400), child: child),
            ),
          ),
        );
        final back = showBack
            ? const SafeArea(
                child: Padding(padding: EdgeInsets.all(Space.s), child: BackButton()),
              )
            : const SizedBox.shrink();
        if (!wide) return Scaffold(body: Stack(children: [form, back]));
        return Scaffold(
          body: Row(
            children: [
              const Expanded(child: _BrandPanel()),
              Expanded(child: Stack(children: [form, back])),
            ],
          ),
        );
      },
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  static const _pillars = [
    (Icons.route_rounded, 'Record and review every ride'),
    (Icons.people_rounded, 'Live circles you control'),
    (Icons.shield_outlined, 'Theft alerts sent to your circle'),
    (Icons.wb_sunny_outlined, 'A weather call before you go'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      color: AppColors.dark,
      padding: const EdgeInsets.all(Space.xxl),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BrandMark(size: 40, onDark: true),
            const Spacer(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ride further.\nStay close.\nKeep it safe.',
                    style: t.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: Space.l),
                  for (final (icon, label) in _pillars)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.m),
                      child: Row(
                        children: [
                          IconTile(icon: icon, size: 40, color: AppColors.tracking),
                          const SizedBox(width: Space.m),
                          Expanded(
                            child: Text(label, style: t.titleMedium?.copyWith(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              'Your location is shared only inside circles you join, and you can pause it any time.',
              style: t.bodySmall?.copyWith(color: AppColors.onDarkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.validator,
    this.newPassword = false,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final bool newPassword;
  final VoidCallback? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      enableSuggestions: false,
      autocorrect: false,
      autofillHints: [widget.newPassword ? AutofillHints.newPassword : AutofillHints.password],
      textInputAction: TextInputAction.done,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: 'Password',
        suffixIcon: IconButton(
          tooltip: _hidden ? 'Show password' : 'Hide password',
          icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _hidden = !_hidden),
        ),
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.alert.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.alert, size: 20),
          const SizedBox(width: Space.s),
          Expanded(
            child: Text(message, style: const TextStyle(color: AppColors.alert)),
          ),
        ],
      ),
    ),
  );
}

class OrDivider extends StatelessWidget {
  const OrDivider(this.label, {super.key});

  final String label;

  /// The label takes only its own width (wrapping past 70% with very large
  /// text) and the two lines share the rest equally, so it stays centered.
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: c.maxWidth * 0.7),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    ),
  );
}

/// Spinner sized for a button label.
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 20,
    child: CircularProgressIndicator.adaptive(
      strokeWidth: 2.4,
      valueColor: color == null ? null : AlwaysStoppedAnimation(color!),
    ),
  );
}
