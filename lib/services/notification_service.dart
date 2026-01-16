// lib/services/notification_service.dart - KEY IMPROVEMENTS
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // ✅ Centralized channel configuration
  static const String _channelId = 'mohaffez_finder_channel';
  static const String _channelName = 'Mohaffez Finder Notifications';
  static const String _channelDescription =
      'Notifications for Quran sessions and lessons';

  /// Initialize notifications with better error handling
  static Future<void> initialize() async {
    try {
      // Request permissions
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('[NotificationService] Permission granted');
      } else {
        print('[NotificationService] Permission denied');
        return; // Don't proceed if permission denied
      }

      // Initialize local notifications
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          print('[NotificationService] Notification tapped: ${response.payload}');
          _handleNotificationTap(response.payload);
        },
      );

      // Create notification channel
      await _createNotificationChannel();

      // Save FCM token
      await saveFCMToken();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_updateFCMToken);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      print('[NotificationService] Initialized successfully');
    } catch (e, stack) {
      print('[NotificationService] Initialization error: $e');
      print('[NotificationService] Stack trace: $stack');
    }
  }

  /// Create Android notification channel
  static Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true, // ✅ Added vibration
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    print('[NotificationService] Channel created');
  }

  /// ✅ IMPROVED: Save FCM token with retry logic
  static Future<void> saveFCMToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('[NotificationService] No authenticated user');
      return;
    }

    try {
      final token = await _messaging.getToken();
      if (token == null) {
        print('[NotificationService] Failed to get FCM token');
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });

      print('[NotificationService] FCM token saved: $token');
    } catch (e) {
      print('[NotificationService] Error saving token: $e');
      // ✅ Retry after 5 seconds
      Future.delayed(const Duration(seconds: 5), saveFCMToken);
    }
  }

  /// Update FCM token
  static Future<void> _updateFCMToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });

      print('[NotificationService] Token updated: $token');
    } catch (e) {
      print('[NotificationService] Error updating token: $e');
    }
  }

  /// ✅ IMPROVED: Handle foreground messages with error recovery
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      try {
        await _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              playSound: true,
              enableVibration: true,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: message.data['payload'],
        );

        print('[NotificationService] Foreground notification shown');
      } catch (e) {
        print('[NotificationService] Error showing notification: $e');
      }
    }
  }

  /// Handle notification tap
  static void _handleNotificationTap(String? payload) {
    if (payload != null) {
      print('[NotificationService] Payload: $payload');
      // TODO: Navigate based on payload
    }
  }

  /// ✅ ADDED: Clear all notifications
  static Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
    print('[NotificationService] All notifications cleared');
  }

  /// ✅ ADDED: Clear specific notification
  static Future<void> clearNotification(int id) async {
    await _localNotifications.cancel(id);
    print('[NotificationService] Notification $id cleared');
  }
}

/// Background message handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('[NotificationService] Background message: ${message.messageId}');
}
