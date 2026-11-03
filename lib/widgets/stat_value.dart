import 'package:flutter/material.dart';

import '../core/theme.dart';

/// A number with its unit and a small label, using tabular figures so
/// changing digits do not jitter.
class StatValue extends StatelessWidget {
  const StatValue({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.size = StatSize.medium,
    this.align = CrossAxisAlignment.start,
  });

  final String label;
  final String value;
  final String? unit;
  final StatSize size;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final valueStyle = switch (size) {
      StatSize.small => t.titleMedium,
      StatSize.medium => t.titleLarge,
      StatSize.large => t.displaySmall?.copyWith(fontWeight: FontWeight.w700),
    }?.copyWith(fontFeatures: kTabular, letterSpacing: -0.5, height: 1.1);
    final unitStyle = t.bodyMedium?.copyWith(color: AppColors.textMuted);

    return Semantics(
      label: '$label ${unit == null ? value : '$value $unit'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: align,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: t.labelMedium?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: value, style: valueStyle),
                if (unit != null) TextSpan(text: ' $unit', style: unitStyle),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

enum StatSize { small, medium, large }
