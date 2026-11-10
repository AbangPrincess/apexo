import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// An alert's title and detail, in the card and the pop-up. The title is
/// the benchmark (owner, 2026-11-11): the detail shrinks (never below
/// 12 pt) until it is no wider than the title's longest line, and wraps
/// inside that width only if 12 pt still won't fit.
class AlertHeading extends StatelessWidget {
  const AlertHeading(
    this.title,
    this.detail, {
    super.key,
    required this.titleStyle,
    required this.detailStyle,
    this.center = false,
    this.gap = 2,
    this.meta,
  });

  final String title;
  final String detail;
  final TextStyle titleStyle;
  final TextStyle detailStyle;
  final bool center;

  /// Between the title and the detail.
  final double gap;

  /// A line under the detail (the card's "just now · Left boundary").
  final Widget? meta;

  @override
  Widget build(BuildContext context) {
    final align = center ? TextAlign.center : TextAlign.start;
    final scaler = MediaQuery.textScalerOf(context);
    final dir = Directionality.of(context);
    double widestLine(String s, TextStyle style, double maxWidth) {
      final p = TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: dir,
        textScaler: scaler,
        textAlign: align,
      )..layout(maxWidth: maxWidth);
      final w = p.computeLineMetrics().fold(0.0, (m, line) => math.max(m, line.width));
      p.dispose();
      return w;
    }

    return LayoutBuilder(
      builder: (context, c) {
        final width = widestLine(title, titleStyle, c.maxWidth).ceilToDouble();
        final full = widestLine(detail, detailStyle, double.infinity);
        // 2% under the exact fit, so rounding never pushes a word down.
        final size = full <= width
            ? detailStyle.fontSize!
            : math.max(12.0, detailStyle.fontSize! * width / full * 0.98);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Text(title, textAlign: align, style: titleStyle),
            SizedBox(height: gap),
            SizedBox(
              width: width,
              child: Text(
                detail,
                key: const ValueKey('alert-detail'),
                textAlign: align,
                style: detailStyle.copyWith(fontSize: size),
              ),
            ),
            if (meta != null) ...[const SizedBox(height: Space.xs), meta!],
          ],
        );
      },
    );
  }
}
