import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Notification channel ID - matches AndroidManifest.xml
  static const String _channelId = 'mohaffez_finder_channel';
  static const String _channelName = 'Mohaffez Finder Notifications';
  static const String _channelDescription =
      'Notifications for Quran sessions and lessons';

  // Initialize notifications
  static Future<void> initialize() async {
    // Request permission for iOS
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted notification permission');
    } else {
      print('User declined or has not accepted notification permission');
    }

    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        print('Notification tapped: ${response.payload}');
        _handleNotificationTap(response.payload);
      },
    );

    // Create notification channel for Android 8.0+
    await _createNotificationChannel();

    // Get and save FCM token
    await _saveFCMToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_updateFCMToken);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Create Android notification channel
  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Save FCM token to Firestore
  static Future<void> _saveFCMToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await _messaging.getToken();
    if (token != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Update FCM token when it refreshes
  static Future<void> _updateFCMToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    });

    print('FCM Token updated: $token');
  }

  // Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
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
    }
  }

  // Handle notification tap
  static void _handleNotificationTap(String? payload) {
    if (payload != null) {
      print('Notification payload: $payload');
      // Handle navigation based on payload
      // Example: Navigate to session details, lesson details, etc.
    }
  }

  // Send notification to followers (Stores in Firestore, actual push via Cloud Functions)
  static Future<void> notifyFollowers({
    required String mohaffezId,
    required String title,
    required String body,
    required String type, // 'session' or 'lesson'
    String? scheduleId,
  }) async {
    try {
      // Get all followers of this Mohaffez
      final followersSnapshot = await FirebaseFirestore.instance
          .collection('follows')
          .where('mohaffezId', isEqualTo: mohaffezId)
          .get();

      if (followersSnapshot.docs.isEmpty) {
        print('No followers to notify');
        return;
      }

      // Get Mohaffez name
      final mohaffezDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(mohaffezId)
          .get();
      final mohaffezName =
          mohaffezDoc.data()?['name'] as String? ?? 'الشيخ';

      // Create notification document for each follower
      for (final doc in followersSnapshot.docs) {
        final studentId = doc.data()['studentId'] as String;

        // Save notification to Firestore
        await FirebaseFirestore.instance
            .collection('notifications')
            .add({
          'userId': studentId,
          'mohaffezId': mohaffezId,
          'mohaffezName': mohaffezName,
          'title': title,
          'body': body,
          'type': type, // 'session' or 'lesson'
          'scheduleId': scheduleId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Get user's FCM token for push notification
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(studentId)
            .get();
        final fcmToken = userDoc.data()?['fcmToken'] as String?;

        if (fcmToken != null) {
          print('Would send push to FCM token: $fcmToken');
          // TODO: Send actual push notification via Cloud Functions or backend
          // const fbMessaging = admin.messaging();
          // await fbMessaging.send({
          //   notification: { title, body },
          //   token: fcmToken,
          //   data: { type, scheduleId }
          // });
        }
      }

      print('Notification stored for ${followersSnapshot.docs.length} followers');
    } catch (e) {
      print('Error notifying followers: $e');
    }
  }

  // Send notification to specific user
  static Future<void> notifyUser({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? scheduleId,
    String? mohaffezId,
    String? mohaffezName,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
        'userId': userId,
        'mohaffezId': mohaffezId,
        'mohaffezName': mohaffezName,
        'title': title,
        'body': body,
        'type': type,
        'scheduleId': scheduleId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('Notification created for user: $userId');
    } catch (e) {
      print('Error creating notification: $e');
    }
  }
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
  // Handle background notification
  // Note: Limited operations in background
}
