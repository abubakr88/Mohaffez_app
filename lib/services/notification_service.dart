import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('NotificationService: Background message: ${message.messageId}');
  // Create notification in database when app is in background
  await NotificationService.createDatabaseNotificationFromRemote(message);
}

class NotificationService {
  static final FirebaseMessaging messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Centralized channel configuration
  static const String channelId = 'mohaffez_finder_channel';
  static const String channelName = 'Mohaffez Finder Notifications';
  static const String channelDescription = 'Notifications for Quran sessions and lessons';
  
  static int _tokenRetryCount = 0;
  static const int _maxTokenRetries = 3;

  /// Initialize notifications with better error handling
  static Future<void> initialize() async {
    try {
      // Request permissions
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('NotificationService: Permission granted');
      } else {
        debugPrint('NotificationService: Permission denied');
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

      await localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('NotificationService: Notification tapped: ${response.payload}');
          handleNotificationTap(response.payload);
        },
      );

      // Create notification channel
      await createNotificationChannel();

      // Save FCM token
      await saveFCMToken();

      // Listen for token refresh
      messaging.onTokenRefresh.listen(updateFCMToken);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(handleForegroundMessage);

      debugPrint('NotificationService: Initialized successfully');
    } catch (e, stack) {
      debugPrint('NotificationService: Initialization error: $e');
      debugPrint('NotificationService: Stack trace: $stack');
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

    await localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    debugPrint('NotificationService: Channel created');
  }

  /// Save FCM token with retry logic
  static Future<void> saveFCMToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('NotificationService: No authenticated user');
      return;
    }

    try {
      final token = await messaging.getToken();
      if (token == null) {
        debugPrint('NotificationService: Failed to get FCM token');
        if (_tokenRetryCount < _maxTokenRetries) {
          _tokenRetryCount++;
          final delay = Duration(seconds: 5 * _tokenRetryCount);
          debugPrint('NotificationService: Retrying token fetch in ${delay.inSeconds}s');
          Future.delayed(delay, () => saveFCMToken());
        }
        return;
      }

      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('NotificationService: FCM token saved: $token');
      _tokenRetryCount = 0;
    } catch (e) {
      debugPrint('NotificationService: Error saving token: $e');
      if (_tokenRetryCount < _maxTokenRetries) {
        _tokenRetryCount++;
        Future.delayed(Duration(seconds: 5 * _tokenRetryCount), () => saveFCMToken());
      }
    }
  }

  /// Update FCM token
  static Future<void> updateFCMToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('NotificationService: Token updated: $token');
    } catch (e) {
      debugPrint('NotificationService: Error updating token: $e');
    }
  }

  /// Handle foreground messages
  static Future<void> handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification != null) {
      try {
        // Create database notification
        await createDatabaseNotificationFromRemote(message);

        // Show local notification
        await localNotifications.show(
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
          payload: jsonEncode(message.data),
        );
        debugPrint('NotificationService: Foreground notification shown');
      } catch (e) {
        debugPrint('NotificationService: Error showing notification: $e');
      }
    }
  }

  /// Handle notification tap
  static void handleNotificationTap(String? payload) {
    if (payload != null && payload.isNotEmpty) {
      debugPrint('NotificationService: Payload: $payload');
      // The actual navigation will be handled in the UI layer
      // This is just for logging and data extraction
    }
  }

  // ==================== NEW METHODS FOR NOTIFICATIONS ====================

  /// Create database notification from RemoteMessage
  static Future<void> createDatabaseNotificationFromRemote(RemoteMessage message) async {
    try {
      final data = message.data;
      final userId = data['userId'] as String?;
      
      if (userId == null) return;

      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': message.notification?.title ?? '',
        'body': message.notification?.body ?? '',
        'type': data['type'] ?? 'general',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': data,
      });

      debugPrint('NotificationService: Database notification created');
    } catch (e) {
      debugPrint('NotificationService: Error creating database notification: $e');
    }
  }

  /// Send Payment Required Notification
  static Future<void> sendPaymentRequiredNotification({
    required String studentId,
    required String requestId,
    required String mohaffezId,
    required String mohaffezName,
    required Map<String, dynamic> sessionDetails,
  }) async {
    try {
      // 1. Create notification in database
      await _firestore.collection('notifications').add({
        'userId': studentId,
        'title': 'الدفع مطلوب!',
        'body': '$mohaffezName قبل طلبك. الرجاء إتمام الدفع لتأكيد الجلسة.',
        'type': 'paymentrequired',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'mohaffezId': mohaffezId,
        'mohaffezName': mohaffezName,
        'data': {
          'requestId': requestId,
          'mohaffezId': mohaffezId,
          'mohaffezName': mohaffezName,
          ...sessionDetails,
        },
      });

      // 2. Send FCM push notification
      await _sendFCMNotification(
        userId: studentId,
        title: 'الدفع مطلوب!',
        body: '$mohaffezName قبل طلبك. اضغط للدفع.',
        data: {
          'type': 'paymentrequired',
          'requestId': requestId,
          'mohaffezId': mohaffezId,
          'mohaffezName': mohaffezName,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      );

      debugPrint('✅ Payment required notification sent');
    } catch (e) {
      debugPrint('❌ Error sending payment notification: $e');
    }
  }

  /// Send Session Accepted Notification
  static Future<void> sendSessionAcceptedNotification({
    required String studentId,
    required String mohaffezName,
    required String sessionId,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': studentId,
        'title': 'تم قبول الجلسة!',
        'body': '$mohaffezName قبل جلستك. يمكنك الآن رؤية التفاصيل.',
        'type': 'sessionaccepted',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': {
          'sessionId': sessionId,
          'mohaffezName': mohaffezName,
        },
      });

      await _sendFCMNotification(
        userId: studentId,
        title: 'تم قبول الجلسة!',
        body: '$mohaffezName قبل جلستك.',
        data: {
          'type': 'sessionaccepted',
          'sessionId': sessionId,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      );

      debugPrint('✅ Session accepted notification sent');
    } catch (e) {
      debugPrint('❌ Error sending session accepted notification: $e');
    }
  }

  /// Send Session Rejected Notification
  static Future<void> sendSessionRejectedNotification({
    required String studentId,
    required String mohaffezName,
    required String? rejectionReason,
  }) async {
    try {
      final body = rejectionReason != null && rejectionReason.isNotEmpty
          ? '$mohaffezName رفض جلستك. السبب: $rejectionReason'
          : '$mohaffezName رفض جلستك.';

      await _firestore.collection('notifications').add({
        'userId': studentId,
        'title': 'تم رفض الجلسة',
        'body': body,
        'type': 'sessionrejected',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': {
          'mohaffezName': mohaffezName,
          'rejectionReason': rejectionReason,
        },
      });

      await _sendFCMNotification(
        userId: studentId,
        title: 'تم رفض الجلسة',
        body: body,
        data: {
          'type': 'sessionrejected',
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      );

      debugPrint('✅ Session rejected notification sent');
    } catch (e) {
      debugPrint('❌ Error sending session rejected notification: $e');
    }
  }

  /// Send New Session Request Notification (to Mohaffez)
  static Future<void> sendNewRequestNotification({
    required String mohaffezId,
    required String studentName,
    required String requestId,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': mohaffezId,
        'title': 'طلب جلسة جديد!',
        'body': '$studentName أرسل لك طلب جلسة جديد.',
        'type': 'sessionrequest',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': {
          'requestId': requestId,
          'studentName': studentName,
        },
      });

      await _sendFCMNotification(
        userId: mohaffezId,
        title: 'طلب جلسة جديد!',
        body: '$studentName أرسل لك طلب جلسة.',
        data: {
          'type': 'sessionrequest',
          'requestId': requestId,
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      );

      debugPrint('✅ New request notification sent');
    } catch (e) {
      debugPrint('❌ Error sending new request notification: $e');
    }
  }

  /// Private method to send FCM notification
  static Future<void> _sendFCMNotification({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      // Get user's FCM token
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('⚠️ No FCM token found for user: $userId');
        return;
      }

      // ✅ Use your deployed Cloud Function URL
      final response = await http.post(
        Uri.parse('https://us-central1-mohaffez-ba2ec.cloudfunctions.net/sendNotification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': fcmToken,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': data,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        debugPrint('✅ FCM notification sent successfully: ${result['messageId']}');
      } else {
        debugPrint('❌ FCM send failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error sending FCM: $e');
    }
  }

  /// Clear all notifications
  static Future<void> clearAllNotifications() async {
    await localNotifications.cancelAll();
    debugPrint('NotificationService: All notifications cleared');
  }

  /// Clear specific notification
  static Future<void> clearNotification(int id) async {
    await localNotifications.cancel(id);
    debugPrint('NotificationService: Notification $id cleared');
  }

  /// Get unread notification count
  static Future<int> getUnreadCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }
}
