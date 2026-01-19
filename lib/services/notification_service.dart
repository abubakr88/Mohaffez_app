import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Centralized channel configuration
  static const String channelId = 'mohaffezfinder_channel';
  static const String channelName = 'Mohaffez Finder Notifications';
  static const String channelDescription =
      'Notifications for Quran sessions and lessons';

  static int _tokenRetryCount = 0;
  static const int _maxTokenRetries = 3;

  /// Initialize notifications with better error handling
  static Future<void> initialize() async {
    try {
      print("NotificationService: Starting initialization...");

      // Request permissions
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print("NotificationService: Permission granted");
      } else {
        print("NotificationService: Permission denied");
        // Continue initialization even if permission denied
      }

      // Initialize local notifications
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
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
          print("NotificationService: Notification tapped: ${response.payload}");
          handleNotificationTap(response.payload);
        },
      );

      // Create notification channel (Android)
      await createNotificationChannel();

      // Save FCM token
      await saveFCMToken();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_updateFCMToken);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(handleForegroundMessage);

      print("NotificationService: Initialized successfully");
    } catch (e, stack) {
      print("NotificationService: Initialization error: $e");
      print("NotificationService: Stack trace: $stack");
    }
  }

  /// Create Android notification channel
  static Future<void> createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    print("NotificationService: Channel created");
  }

  /// Save FCM token with retry logic and proper error handling
  static Future<void> saveFCMToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("NotificationService: No authenticated user");
      return;
    }

    try {
      final token = await _messaging.getToken();
      if (token == null) {
        print("NotificationService: Failed to get FCM token");
        
        // Retry with exponential backoff
        if (_tokenRetryCount < _maxTokenRetries) {
          _tokenRetryCount++;
          final delay = Duration(seconds: 5 * _tokenRetryCount);
          print("NotificationService: Retrying token fetch in ${delay.inSeconds}s (attempt $_tokenRetryCount)");
          Future.delayed(delay, saveFCMToken);
        }
        return;
      }

      // Use set with merge to avoid document not found error
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      print("NotificationService: FCM token saved: $token");
      _tokenRetryCount = 0; // Reset retry count on success
    } catch (e) {
      print("NotificationService: Error saving token: $e");
      
      // Retry with limit
      if (_tokenRetryCount < _maxTokenRetries) {
        _tokenRetryCount++;
        final delay = Duration(seconds: 5 * _tokenRetryCount);
        print("NotificationService: Retrying in ${delay.inSeconds}s (attempt $_tokenRetryCount)");
        Future.delayed(delay, saveFCMToken);
      } else {
        print("NotificationService: Max retries reached for token save");
      }
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
          .set(
        {
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      print("NotificationService: Token updated: $token");
    } catch (e) {
      print("NotificationService: Error updating token: $e");
    }
  }

  /// Handle foreground messages with better error recovery
  static Future<void> handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification != null) {
      try {
        await _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channelId,
              channelName,
              channelDescription: channelDescription,
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

        print("NotificationService: Foreground notification shown");
      } catch (e) {
        print("NotificationService: Error showing notification: $e");
      }
    }
  }

  /// Handle notification tap with navigation
  static void handleNotificationTap(String? payload) {
    if (payload != null) {
      print("NotificationService: Payload: $payload");
      
      // Parse payload and navigate
      try {
        // Assuming payload format: "type:sessionId" or "type:userId"
        final parts = payload.split(':');
        if (parts.length == 2) {
          final type = parts[0];
          final id = parts[1];
          
          // Navigate based on type
          // Note: You'll need to implement your navigation logic here
          // This is just a template
          print("NotificationService: Navigate to $type with ID $id");
          
          // TODO: Use your navigation service/router to navigate
          // Example: navigatorKey.currentState?.pushNamed('/session/$id');
        }
      } catch (e) {
        print("NotificationService: Error parsing payload: $e");
      }
    }
  }

  /// Clear all notifications
  static Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
    print("NotificationService: All notifications cleared");
  }

  /// Clear specific notification
  static Future<void> clearNotification(int id) async {
    await _localNotifications.cancel(id);
    print("NotificationService: Notification $id cleared");
  }
}
