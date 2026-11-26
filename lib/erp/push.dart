import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';

import 'erp_api.dart';
import 'push_config.dart';

// Push notifications. Registers this phone with the school server after sign-in.
// App closed or in the background: Android shows the notification with sound by itself.
// App open: a banner is shown by the caller, plus a short vibration and alert tone.
class PushService {
  static bool _started = false;
  static void Function(String title, String body)? _onMessage;

  static Future<void> start({required void Function(String title, String body) onMessage}) async {
    _onMessage = onMessage;
    if (_started) {
      await _sync();
      return;
    }
    _started = true;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: aspireFirebaseOptions);
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission(alert: true, badge: true, sound: true);
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n == null) return;
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.mediumImpact();
        _onMessage?.call(n.title ?? 'Aspire', n.body ?? '');
      });
      fm.onTokenRefresh.listen(_register);
      await _sync();
    } catch (_) {
      _started = false;
    }
  }

  static Future<void> _sync() async {
    try {
      final t = await FirebaseMessaging.instance.getToken();
      if (t != null) await _register(t);
    } catch (_) {}
  }

  static Future<void> _register(String token) async {
    try {
      await ErpApi.postAuth('/api/mobile/push', {'token': token, 'platform': 'android'});
    } catch (_) {}
  }
}