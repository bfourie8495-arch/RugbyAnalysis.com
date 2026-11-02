import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;

import 'backend.dart';

/// Push alerts are for the Android app only (as in Smack Bang).
bool get alertsSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Push alerts through Firebase Cloud Messaging: the weekend heads-up, kick-off
/// reminders and full-time scores, all sent by the server (functions/main.py).
/// Showing them while the app is closed is automatic, so there is no background
/// code here. Every call is wrapped so a messaging failure never breaks the app.
class Notifications {
  Notifications(this.backend);

  final Backend backend;
  bool _enabled = false;

  /// Listens for taps on a notification; [onOpen] gets its data, such as
  /// {'type': 'kickoff', 'g': 'm', 'h': 'Wales', 'a': 'Japan', 'd': '2026-11-07'}.
  Future<void> start(void Function(Map<String, dynamic> data) onOpen) async {
    try {
      void handle(RemoteMessage? m) {
        if (m != null && m.data.isNotEmpty) onOpen(m.data);
      }

      FirebaseMessaging.onMessageOpenedApp.listen(handle, onError: (Object e) => debugPrint('Alerts: $e'));
      handle(await FirebaseMessaging.instance.getInitialMessage());
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        if (_enabled) _save(token);
      }, onError: (Object e) => debugPrint('Alerts: $e'));
    } catch (e) {
      debugPrint('Alerts could not start: $e');
    }
  }

  /// Asks permission to show alerts (Android 13 and later shows a prompt) and
  /// saves this phone's token so the server can reach it. True if allowed.
  Future<bool> enable() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return false;
      _enabled = true;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _save(token);
      return true;
    } catch (e) {
      debugPrint('Alerts could not be turned on: $e');
      return false;
    }
  }

  Future<void> _save(String token) async {
    try {
      await backend.saveDeviceToken(token);
    } catch (e) {
      debugPrint('Could not save the device token: $e');
    }
  }
}
