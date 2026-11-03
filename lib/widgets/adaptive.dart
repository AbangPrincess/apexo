import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';

bool isApple(BuildContext context) {
  final p = Theme.of(context).platform;
  return p == TargetPlatform.iOS || p == TargetPlatform.macOS;
}

/// Native-looking confirm dialog on iPhone, Material elsewhere.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final apple = isApple(context);
  Widget action(BuildContext ctx, String label, bool value, {bool danger = false}) {
    void pop() => Navigator.of(ctx).pop(value);
    if (apple) {
      return CupertinoDialogAction(
        isDestructiveAction: danger,
        isDefaultAction: !value,
        onPressed: pop,
        child: Text(label),
      );
    }
    return TextButton(
      onPressed: pop,
      style: danger ? TextButton.styleFrom(foregroundColor: AppColors.alert) : null,
      child: Text(label),
    );
  }

  final result = await showAdaptiveDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog.adaptive(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        action(ctx, 'Cancel', false),
        action(ctx, confirmLabel, true, danger: destructive),
      ],
    ),
  );
  return result ?? false;
}
