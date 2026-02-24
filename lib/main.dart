import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'config/app_router.dart';
import 'shared/theme/app_theme_constants.dart';
import 'shared/theme/app_theme_data.dart';
import 'services/cache_service.dart';
import 'providers/system_config_provider.dart';
import 'shared/widgets/dev_mode_overlay.dart';

/// Firebase Cloud Messaging background handler
/// Must be top-level function for isolate entry point
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📨 Background message received: ${message.messageId}');
  debugPrint('📨 Title: ${message.notification?.title}');
  debugPrint('📨 Body: ${message.notification?.body}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // ============================================
    // 1. Load Environment Variables
    // ============================================
    await dotenv.load(fileName: '.env');
    debugPrint('✅ Environment variables loaded');

    // ============================================
    // 2. Initialize Firebase
    // ============================================
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase initialized');
    }

    // ============================================
    // 3. Configure Firestore
    // ============================================
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    debugPrint('✅ Firestore configured with offline persistence');

    // ============================================
    // 4. Setup Firebase Cloud Messaging
    // ============================================
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request notification permissions (iOS)
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint(
        '✅ Notification permission status: ${settings.authorizationStatus}');

    // ============================================
    // 5. Initialize Arabic Date Formatting
    // ============================================
    await initializeDateFormatting('ar', null);
    await initializeDateFormatting('ar_SA', null);
    await initializeDateFormatting('ar_EG', null);
    debugPrint('✅ Arabic date formatting initialized');

    // ============================================
    // 6. Initialize Cache Service
    // ============================================
    await CacheService.initialize();
    debugPrint('✅ Cache service initialized');

    // Check for stale cache data
    final hasStaleData = CacheService.getUserId() != null &&
        FirebaseAuth.instance.currentUser == null;
    if (hasStaleData) {
      debugPrint('⚠️ Stale cache detected - clearing...');
      await CacheService.clearAll();
      debugPrint('✅ Stale cache cleared');
    }

    // ============================================
    // 7. Configure System UI
    // ============================================
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppThemeConstants.surfaceWhite,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    // Lock to portrait orientation
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    debugPrint('✅ System UI configured');

    // ============================================
    // 8. Launch App
    // ============================================
    debugPrint('🚀 Launching Al-Mohaffez app...');
    runApp(const ProviderScope(child: DevModeOverlay(child: MyApp())));
  } catch (e, stackTrace) {
    debugPrint('❌ Initialization error: $e');
    debugPrint('Stack trace: $stackTrace');

    // Show error screen with restart option
    runApp(_buildErrorApp(e, stackTrace));
  }
}

/// Build error screen when initialization fails
Widget _buildErrorApp(Object error, StackTrace stackTrace) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Error Icon
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppThemeConstants.error.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppThemeConstants.error,
                    ),
                  ),
                  const SizedBox(height: AppThemeConstants.spaceLg),

                  // Error Title
                  const Text(
                    'حدث خطأ في التطبيق',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppThemeConstants.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppThemeConstants.spaceMd),

                  // Error Message
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppThemeConstants.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppThemeConstants.spaceLg),

                  // Restart Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Restart the app by popping the navigation stack
                        SystemNavigator.pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeConstants.primaryAmber,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.refresh, size: 20),
                      label: const Text(
                        'إعادة المحاولة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppThemeConstants.spaceSm),

                  // Close Button
                  TextButton(
                    onPressed: () {
                      SystemNavigator.pop();
                    },
                    child: const Text(
                      'إغلاق التطبيق',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppThemeConstants.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// ============================================
// MAIN APP WIDGET
// ============================================
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // keep config streams warm for synchronous guards
    ref.watch(systemConfigProvider);
    ref.watch(devModeProvider);

    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      // ============================================
      // App Configuration
      // ============================================
      title: 'المحفظ',
      debugShowCheckedModeBanner: false,

      // ============================================
      // Theme Configuration
      // ============================================
      themeMode: ThemeMode.light,
      theme: AppThemeData.lightTheme,

      // ============================================
      // ✅ CRITICAL: Arabic Localization
      // ============================================
      locale: const Locale('ar', 'EG'), // Egyptian Arabic (default)

      supportedLocales: const [
        Locale('ar', 'EG'), // Egyptian Arabic
        Locale('ar', 'SA'), // Saudi Arabic
        Locale('ar'), // Generic Arabic
        Locale('en', 'US'), // English (fallback)
      ],

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Locale resolution strategy
      localeResolutionCallback: (locale, supportedLocales) {
        // Check if the current device locale is supported
        if (locale != null) {
          for (var supportedLocale in supportedLocales) {
            if (supportedLocale.languageCode == locale.languageCode) {
              return supportedLocale;
            }
          }
        }
        // Default to Egyptian Arabic
        return const Locale('ar', 'EG');
      },

      // ============================================
      // Router Configuration
      // ============================================
      routerConfig: router,

      // ============================================
      // ✅ CRITICAL: Force RTL globally
      // ============================================
      builder: (context, child) {
        // Wrap entire app with RTL direction
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
