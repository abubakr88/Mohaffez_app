import 'bootstrap.dart';
import 'firebase_options_dev.dart';

void main() => bootstrap(firebaseOptions: DevFirebaseOptions.currentPlatform);
