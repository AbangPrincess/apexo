import 'package:battery_plus/battery_plus.dart';

/// Battery percent for the member doc, or null where the platform (some
/// browsers) cannot tell.
Future<int?> readBatteryLevel() async {
  try {
    final level = await Battery().batteryLevel;
    return level >= 0 && level <= 100 ? level : null;
  } catch (_) {
    return null;
  }
}
