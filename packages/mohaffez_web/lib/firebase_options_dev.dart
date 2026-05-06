// Dev Firebase project: mohaffez-dev — web platform.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DevFirebaseOptions {
  static FirebaseOptions get currentPlatform => web;

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCfHpFSKV2pGanreNzowMo59Xc2UubZaKw',
    appId: '1:389775667878:web:847be3b6c2c9a1d3b87a67',
    messagingSenderId: '389775667878',
    projectId: 'mohaffez-dev',
    authDomain: 'mohaffez-dev.firebaseapp.com',
    storageBucket: 'mohaffez-dev.firebasestorage.app',
    measurementId: 'G-1S2SRKZGZC',
  );
}
