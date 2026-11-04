import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Keeps the neutral [AppColors] roles in step with the active theme.
/// Widgets read those roles without depending on Theme, so when the system
/// switches between light and dark at runtime the whole tree is rebuilt in
/// place (the same way hot reload does it), keeping tabs, scroll and maps.
class PaletteSync extends StatefulWidget {
  const PaletteSync({super.key, required this.child});

  final Widget child;

  @override
  State<PaletteSync> createState() => _PaletteSyncState();
}

class _PaletteSyncState extends State<PaletteSync> {
  bool _built = false;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    if (AppColors.brightness != b) {
      AppColors.use(b);
      // The first build happens before any child reads a color.
      if (_built) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => WidgetsBinding.instance.reassembleApplication(),
        );
      }
    }
    _built = true;
    return widget.child;
  }
}
