// Dev Firebase project: mohaffez-dev
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DevFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DevFirebaseOptions not configured for ${defaultTargetPlatform.name}.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCfHpFSKV2pGanreNzowMo59Xc2UubZaKw',
    appId: '1:389775667878:web:847be3b6c2c9a1d3b87a67',
    messagingSenderId: '389775667878',
    projectId: 'mohaffez-dev',
    authDomain: 'mohaffez-dev.firebaseapp.com',
    storageBucket: 'mohaffez-dev.firebasestorage.app',
    measurementId: 'G-1S2SRKZGZC',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBmTp0UTPt4IN6GLMO25uHZoq72MS9cNNM',
    appId: '1:389775667878:android:9f2d6c01c106b089b87a67',
    messagingSenderId: '389775667878',
    projectId: 'mohaffez-dev',
    storageBucket: 'mohaffez-dev.firebasestorage.app',
  );
}
