import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/permission_rationale.dart';
import 'record_controller.dart';

/// Explains [need] first when location access has not been granted yet.
/// False when the person chose "Not now". Simulated GPS never asks.
Future<bool> explainLocationIfNeeded(BuildContext context, PermissionNeed need) async {
  final source = context.read<RecordController>().source;
  if (source.simulated || await source.hasAccess()) return true;
  if (!context.mounted) return false;
  return explainPermission(context, need);
}
