import 'dart:js_interop';

import 'package:web/web.dart' as web;

web.WakeLockSentinel? _lock;
bool _wanted = false;
bool _watching = false;

/// A locked iPhone (or a hidden tab) stops web pages, GPS included. While a
/// ride is live, this asks the browser to keep the screen from turning off
/// by itself (Screen Wake Lock: Safari 16.4+, Chrome 84+). The browser drops
/// it whenever the page is hidden, so it is asked for again on return.
void keepScreenAwake(bool on) {
  _wanted = on;
  if (!_watching) {
    _watching = true;
    web.document.addEventListener(
      'visibilitychange',
      ((web.Event _) {
        if (web.document.visibilityState == 'visible') _sync();
      }).toJS,
    );
  }
  _sync();
}

Future<void> _sync() async {
  try {
    final lock = _lock;
    if (_wanted && (lock == null || lock.released)) {
      _lock = await web.window.navigator.wakeLock.request('screen').toDart;
    } else if (!_wanted && lock != null) {
      _lock = null;
      await lock.release().toDart;
    }
  } catch (_) {
    // Not supported, or the page is hidden right now: tried again on return.
  }
}
