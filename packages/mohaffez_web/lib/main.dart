import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use path-based URLs (no # in URLs)
  usePathUrlStrategy();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // App Check — required for Cloud Functions calls in prod.
  // Set APP_CHECK_RECAPTCHA_KEY in .env (reCAPTCHA v3 site key from Firebase Console).
  const recaptchaKey = String.fromEnvironment('APP_CHECK_RECAPTCHA_KEY', defaultValue: '');
  if (recaptchaKey.isNotEmpty) {
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaV3Provider(recaptchaKey),
    );
  }

  const sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 0.1;
      },
      appRunner: () => runApp(const ProviderScope(child: MohaffezWebApp())),
    );
  } else {
    runApp(const ProviderScope(child: MohaffezWebApp()));
  }
}
