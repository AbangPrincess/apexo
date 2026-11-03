import 'dart:async';

import 'package:flutter/material.dart';

import '../core/time_format.dart';

/// "5 min ago" that refreshes itself, so lists need not rebuild on a timer.
class TimeAgo extends StatefulWidget {
  const TimeAgo(this.time, {super.key, this.prefix = '', this.suffix = '', this.style});

  final DateTime time;
  final String prefix;
  final String suffix;
  final TextStyle? style;

  @override
  State<TimeAgo> createState() => _TimeAgoState();
}

class _TimeAgoState extends State<TimeAgo> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    '${widget.prefix}${formatAgo(widget.time, DateTime.now())}${widget.suffix}',
    style: widget.style,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}
