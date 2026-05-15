import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static late SharedPreferences _prefs;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // User data
  static Future<void> saveUserRole(String role) async {
    await _prefs.setString('user_role', role);
  }

  static String? getUserRole() {
    return _prefs.getString('user_role');
  }

  static Future<void> saveUserName(String name) async {
    await _prefs.setString('user_name', name);
  }

  static String? getUserName() {
    return _prefs.getString('user_name');
  }

  static Future<void> saveUserId(String uid) async {
    await _prefs.setString('user_id', uid);
  }

  static String? getUserId() {
    return _prefs.getString('user_id');
  }

  // Location
  static Future<void> saveLastLocation(double lat, double lng) async {
    await _prefs.setDouble('last_lat', lat);
    await _prefs.setDouble('last_lng', lng);
  }

  static (double, double)? getLastLocation() {
    final lat = _prefs.getDouble('last_lat');
    final lng = _prefs.getDouble('last_lng');
    if (lat != null && lng != null) {
      return (lat, lng);
    }
    return null;
  }

  // Clear session-scoped cache on logout. Permanent flags (e.g. wizard-seen)
  // use a 'persistent_' prefix and are intentionally kept across logouts.
  static Future<void> clearAll() async {
    final saved = <String, Object>{};
    for (final key in _prefs.getKeys().where((k) => k.startsWith('persistent_'))) {
      final v = _prefs.get(key);
      if (v != null) saved[key] = v;
    }
    await _prefs.clear();
    for (final entry in saved.entries) {
      if (entry.value is bool)   await _prefs.setBool(entry.key, entry.value as bool);
      if (entry.value is int)    await _prefs.setInt(entry.key, entry.value as int);
      if (entry.value is double) await _prefs.setDouble(entry.key, entry.value as double);
      if (entry.value is String) await _prefs.setString(entry.key, entry.value as String);
    }
  }

  // Check if user was logged in (for quick startup)
  static bool hasUserData() {
    return _prefs.containsKey('user_id');
  }
}
