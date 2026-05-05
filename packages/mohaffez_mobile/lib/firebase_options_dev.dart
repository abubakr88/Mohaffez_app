// Dev Firebase project: mohaffez-dev
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DevFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DevFirebaseOptions not configured for web. '
        'Add a web app to the mohaffez-dev Firebase project and re-run flutterfire configure.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DevFirebaseOptions not configured for ${defaultTargetPlatform.name}.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBmTp0UTPt4IN6GLMO25uHZoq72MS9cNNM',
    appId: '1:389775667878:android:9f2d6c01c106b089b87a67',
    messagingSenderId: '389775667878',
    projectId: 'mohaffez-dev',
    storageBucket: 'mohaffez-dev.firebasestorage.app',
  );
}
