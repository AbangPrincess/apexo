import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Material 3 window size classes.
abstract final class Breakpoints {
  /// Below this: phones, bottom bar.
  static const medium = 600.0;

  /// From this: side-by-side panes.
  static const expanded = 840.0;

  /// From this: extended side rail with labels.
  static const large = 1200.0;
}

/// Horizontal padding that centers content in [maxWidth] while keeping the
/// scrollbar at the window edge.
EdgeInsets pageInsets(double width,
    {double maxWidth = 720, double top = Space.m, double bottom = Space.xl}) {
  final side = math.max(Space.m, (width - maxWidth) / 2);
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}

/// A ListView whose content is centered and width-capped on wide screens.
class PageListView extends StatelessWidget {
  const PageListView({
    super.key,
    required this.children,
    this.maxWidth = 720,
  });

  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => ListView(
          padding: pageInsets(c.maxWidth, maxWidth: maxWidth),
          children: children,
        ),
      );
}

/// Centers [child] and caps its width.
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}
