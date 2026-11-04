import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../data/models/circle_alert.dart';

/// System notifications (with sound) for theft alerts. Every call is safe
/// to make anywhere: where notifications are unavailable it does nothing.
class AlertNotifier extends ChangeNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _enabled = false;

  /// Known only after [refresh] or [requestPermission].
  bool get enabled => _enabled;

  Future<bool> _init() async {
    if (_ready) return true;
    try {
      _ready =
          await _plugin.initialize(
            settings: const InitializationSettings(
              android: AndroidInitializationSettings('@mipmap/ic_launcher'),
              iOS: DarwinInitializationSettings(
                requestAlertPermission: false,
                requestBadgePermission: false,
                requestSoundPermission: false,
              ),
            ),
          ) ??
          false;
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  /// Reads the current permission without asking. On the web nothing is
  /// set up until the person turns notifications on.
  Future<void> refresh() async {
    if (kIsWeb) return;
    if (!await _init()) return;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final ios = _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      _set(
        await android?.areNotificationsEnabled() ??
            (await ios?.checkPermissions())?.isEnabled ??
            false,
      );
    } catch (_) {}
  }

  /// Shows the system permission dialog; call it from a button press.
  Future<bool> requestPermission() async {
    if (!await _init()) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final ios = _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final web = _plugin
          .resolvePlatformSpecificImplementation<WebFlutterLocalNotificationsPlugin>();
      _set(
        await android?.requestNotificationsPermission() ??
            await ios?.requestPermissions(alert: true, sound: true) ??
            await web?.requestNotificationsPermission() ??
            false,
      );
    } catch (_) {}
    return _enabled;
  }

  Future<void> show(CircleAlert alert, String detail) async {
    if (!_enabled || !await _init()) return;
    try {
      await _plugin.show(
        id: alert.id.hashCode & 0x7fffffff,
        title: alert.message,
        body: detail,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'theft_alerts',
            'Theft alerts',
            channelDescription: 'When a vehicle in your circles leaves its boundary',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
      );
    } catch (_) {}
  }

  void _set(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    notifyListeners();
  }
}
