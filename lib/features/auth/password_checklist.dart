import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/validators.dart';

/// Live password rules under a new-password field.
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => Wrap(
        spacing: Space.m,
        runSpacing: Space.xs,
        children: [
          for (final (label, ok) in passwordChecks(value.text))
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: kMotion,
                  child: Icon(
                    ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    key: ValueKey(ok),
                    size: 16,
                    color: ok ? AppColors.tracking : AppColors.parked,
                  ),
                ),
                const SizedBox(width: Space.xs),
                Text(
                  label,
                  style: style?.copyWith(color: ok ? AppColors.text : AppColors.textMuted),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
