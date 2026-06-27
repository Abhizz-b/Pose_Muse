// notification_service.dart
// Firestore mein notification preferences save/load karta hai.
// Jab bhi push notifications add karni ho (FCM etc.) tab extend karna.

import 'package:flutter/foundation.dart';
import 'firestore_service.dart';

class NotificationService {
  NotificationService._();

  static bool _pushEnabled = true;
  static bool _remindersEnabled = true;

  // ── In-memory state getters ──
  static bool get pushEnabled => _pushEnabled;
  static bool get remindersEnabled => _remindersEnabled;

  /// App start pe call karo — Firestore se prefs load karta hai
  static Future<void> initialize() async {
    try {
      final prefs = await FirestoreService.loadNotificationPrefs();
      _pushEnabled = prefs['pushNotifications'] ?? true;
      _remindersEnabled = prefs['poseReminders'] ?? true;
      debugPrint(
        'NotificationService: push=$_pushEnabled reminders=$_remindersEnabled',
      );
    } catch (e) {
      debugPrint('NotificationService: init failed — $e');
    }
  }

  /// Push notifications toggle
  static Future<void> setPushNotifications(bool enabled) async {
    _pushEnabled = enabled;
    await FirestoreService.saveNotificationPrefs(
      pushNotifications: enabled,
      poseReminders: _remindersEnabled,
    );
    debugPrint('NotificationService: push set to $enabled');
  }

  /// Pose reminders toggle
  static Future<void> setPoseReminders(bool enabled) async {
    _remindersEnabled = enabled;
    await FirestoreService.saveNotificationPrefs(
      pushNotifications: _pushEnabled,
      poseReminders: enabled,
    );
    debugPrint('NotificationService: reminders set to $enabled');
  }
}
