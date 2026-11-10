import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// An alert's choices, text only (owner, 2026-11-11): View on map (left)
/// and Navigate (right) at equal width across the card or pop-up, the same
/// padding from both edges, and an optional [third] choice centered under
/// them in a button of the same size with no outline: the quiet gray
/// "It's me" or the owner's "Mark recovered". Narrower than [minWidth],
/// everything stacks at full width instead (narrow phones, very large text).
class AlertActions extends StatelessWidget {
  const AlertActions({
    super.key,
    required this.onViewMap,
    required this.onNavigate,
    this.filledMap = false,
    this.third,
    this.onThird,
    this.quietThird = true,
  });

  final VoidCallback onViewMap;
  final VoidCallback onNavigate;

  /// View on map as the filled main action (the pop-up).
  final bool filledMap;
  final String? third;
  final VoidCallback? onThird;
  final bool quietThird;

  static const _map = 'View on map';
  static const _navigate = 'Navigate';

  // Padding 2 x 12 and a 1 px border on each side.
  static const _chrome = 26.0;
  static const _padding = EdgeInsets.symmetric(horizontal: 12);

  TextStyle? _thirdStyle(TextTheme t) => quietThird ? t.labelMedium : t.labelLarge;

  /// The narrowest width that still fits two buttons side by side.
  double minWidth(BuildContext context) {
    final t = Theme.of(context).textTheme;
    double labelWidth(String label, TextStyle? style) {
      final p = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final w = p.width;
      p.dispose();
      return w;
    }

    final widest = [
      labelWidth(_map, t.labelLarge),
      labelWidth(_navigate, t.labelLarge),
      if (third != null) labelWidth(third!, _thirdStyle(t)),
    ].reduce(math.max);
    return 2 * (widest + _chrome) + Space.s;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final min = minWidth(context);
    Widget label(String s) => Text(s, maxLines: 1, overflow: TextOverflow.ellipsis);
    final outlined = OutlinedButton.styleFrom(padding: _padding);
    final map = filledMap
        ? FilledButton(
            key: const ValueKey('alert-view-map'),
            onPressed: onViewMap,
            style: FilledButton.styleFrom(padding: _padding),
            child: label(_map),
          )
        : OutlinedButton(
            key: const ValueKey('alert-view-map'),
            onPressed: onViewMap,
            style: outlined,
            child: label(_map),
          );
    final nav = OutlinedButton(
      key: const ValueKey('alert-navigate'),
      onPressed: onNavigate,
      style: outlined,
      child: label(_navigate),
    );

    return LayoutBuilder(
      builder: (context, c) {
        final row = c.maxWidth >= min;
        final cell = row ? (c.maxWidth - Space.s) / 2 : c.maxWidth;
        Widget sized(Widget b) => SizedBox(width: cell, child: b);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (row)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  sized(map),
                  const SizedBox(width: Space.s),
                  sized(nav),
                ],
              )
            else ...[
              sized(map),
              const SizedBox(height: Space.s),
              sized(nav),
            ],
            if (third != null) ...[
              const SizedBox(height: Space.s),
              sized(
                // Same size as the pair, but no outline (owner, 2026-11-11).
                TextButton(
                  key: const ValueKey('alert-third'),
                  onPressed: onThird,
                  style: TextButton.styleFrom(
                    padding: _padding,
                    foregroundColor: quietThird ? AppColors.textMuted : null,
                    textStyle: _thirdStyle(t),
                  ),
                  child: label(third!),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
