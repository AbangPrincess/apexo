import 'package:flutter/material.dart';

import '../core/theme.dart';

/// App mark: a route glyph in an accent tile, with the wordmark when [showName].
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32, this.showName = true});

  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'PedalTrack',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(size * 0.3),
            ),
            child: Icon(Icons.route_rounded, color: Colors.white, size: size * 0.6),
          ),
          if (showName) ...[
            SizedBox(width: size * 0.3),
            Text(
              'PedalTrack',
              style: TextStyle(
                fontSize: size * 0.58,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: AppColors.text,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
