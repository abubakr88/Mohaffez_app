import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

import 'app.dart';
import 'services/notification_service.dart';
import 'services/sound_service.dart';
import 'shared/widgets/dev_mode_overlay.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) return;
  await Firebase.initializeApp();
  debugPrint('📨 Background message received: ${message.messageId}');
}

Future<void> bootstrap({required FirebaseOptions firebaseOptions}) async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: firebaseOptions);
      debugPrint('✅ Firebase initialized');
    }

    if (!kIsWeb) {
      if (kReleaseMode) {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.deviceCheck,
        );
      } else {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.debug,
          appleProvider: AppleProvider.debug,
        );
      }
      if (kReleaseMode) {
        await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
      }
      if (kDebugMode) {
        FirebaseAppCheck.instance.onTokenChange.listen((token) {
          final hasToken = token != null && token.isNotEmpty;
          debugPrint('App Check token: ${hasToken ? 'valid' : 'null_or_empty'}');
        });
      }
    } else {
      debugPrint('ℹ️ Firebase App Check skipped for web');
    }

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      NotificationService.initialize().then((_) {
        debugPrint('✅ NotificationService initialized');
      });
    }

    await initializeDateFormatting('ar', null);
    await initializeDateFormatting('ar_SA', null);
    await initializeDateFormatting('ar_EG', null);

    await CacheService.initialize();
    await SoundService.initialize();

    final hasStaleData = CacheService.getUserId() != null &&
        FirebaseAuth.instance.currentUser == null;
    if (hasStaleData) {
      debugPrint('⚠️ Stale cache detected — clearing...');
      await CacheService.clearAll();
    }

    if (!kIsWeb) {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: AppThemeConstants.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppThemeConstants.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ));
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    debugPrint('🚀 Launching Al-Mohaffez...');
    runApp(const ProviderScope(child: DevModeOverlay(child: MyApp())));
  } catch (e, stackTrace) {
    debugPrint('❌ Initialization error: $e');
    debugPrint('$stackTrace');
    runApp(buildErrorApp(e, stackTrace));
  }
}
