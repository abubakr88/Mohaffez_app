import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static String get googleMapsApiKey {
    final key = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('GOOGLE_MAPS_API_KEY not found in .env file');
    }
    return key;
  }

  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }
}
