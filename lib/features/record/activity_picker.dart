import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import '../../core/activity_type.dart';
import '../../core/theme.dart';
import '../../widgets/visuals.dart';

/// The activity choice on one line with even gaps. Centered when it fits;
/// on narrow screens it scrolls sideways and fades out at the edge that
/// still has chips beyond it.
class ActivityPicker extends StatefulWidget {
  const ActivityPicker({super.key, required this.value, required this.onChanged});

  final ActivityType value;
  final ValueChanged<ActivityType> onChanged;

  @override
  State<ActivityPicker> createState() => _ActivityPickerState();
}

class _ActivityPickerState extends State<ActivityPicker> {
  static const _fade = 28.0;

  bool _moreBefore = false;
  bool _moreAfter = false;

  bool _onScroll(Notification n) {
    final metrics = switch (n) {
      ScrollMetricsNotification(depth: 0) => n.metrics,
      ScrollUpdateNotification(depth: 0) => n.metrics,
      _ => null,
    };
    if (metrics != null) {
      final before = metrics.pixels > metrics.minScrollExtent + 1;
      final after = metrics.pixels < metrics.maxScrollExtent - 1;
      if (before != _moreBefore || after != _moreAfter) {
        setState(() {
          _moreBefore = before;
          _moreAfter = after;
        });
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final (i, type) in ActivityType.values.indexed) ...[
        if (i > 0) const SizedBox(width: Space.s),
        ChoiceChip(
          showCheckmark: false,
          avatar: Icon(
            type.icon,
            size: 18,
            color: type == widget.value ? AppColors.onInk : AppColors.text,
          ),
          label: Text(type.label),
          selected: type == widget.value,
          onSelected: (_) => widget.onChanged(type),
        ),
      ],
    ];
    return LayoutBuilder(
      builder: (context, c) => ShaderMask(
        // An alpha mask, not a visible color: opaque keeps, clear fades.
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) {
          final f = (_fade / rect.width).clamp(0.0, 0.5);
          return LinearGradient(
            colors: [
              _moreBefore ? Colors.transparent : Colors.black,
              Colors.black,
              Colors.black,
              _moreAfter ? Colors.transparent : Colors.black,
            ],
            stops: [0, f, 1 - f, 1],
          ).createShader(rect);
        },
        child: NotificationListener<Notification>(
          onNotification: _onScroll,
          // Drag with a mouse too, not only touch (desktop browsers).
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: c.maxWidth),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: chips),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
