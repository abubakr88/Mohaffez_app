import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static SharedPreferences? _prefs;
  static final Map<String, Object> _memoryFallback = {};

  static Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      // Some iOS/Safari contexts can deny browser storage during first launch.
      // Keep the app usable with an in-memory fallback for session-scoped cache.
      _prefs = null;
    }
  }

  // User data
  static Future<void> saveUserRole(String role) async {
    await _setString('user_role', role);
  }

  static String? getUserRole() {
    return _getString('user_role');
  }

  static Future<void> saveUserName(String name) async {
    await _setString('user_name', name);
  }

  static String? getUserName() {
    return _getString('user_name');
  }

  static Future<void> saveUserId(String uid) async {
    await _setString('user_id', uid);
  }

  static String? getUserId() {
    return _getString('user_id');
  }

  // Location
  static Future<void> saveLastLocation(double lat, double lng) async {
    await _setDouble('last_lat', lat);
    await _setDouble('last_lng', lng);
  }

  static (double, double)? getLastLocation() {
    final lat = _getDouble('last_lat');
    final lng = _getDouble('last_lng');
    if (lat != null && lng != null) {
      return (lat, lng);
    }
    return null;
  }

  // Clear session-scoped cache on logout. Permanent flags (e.g. wizard-seen)
  // use a 'persistent_' prefix and are intentionally kept across logouts.
  static Future<void> clearAll() async {
    final prefs = _prefs;
    if (prefs == null) {
      _memoryFallback.removeWhere((key, _) => !key.startsWith('persistent_'));
      return;
    }

    final saved = <String, Object>{};
    for (final key
        in prefs.getKeys().where((k) => k.startsWith('persistent_'))) {
      final v = prefs.get(key);
      if (v != null) saved[key] = v;
    }
    await prefs.clear();
    for (final entry in saved.entries) {
      if (entry.value is bool)
        await prefs.setBool(entry.key, entry.value as bool);
      if (entry.value is int) await prefs.setInt(entry.key, entry.value as int);
      if (entry.value is double)
        await prefs.setDouble(entry.key, entry.value as double);
      if (entry.value is String)
        await prefs.setString(entry.key, entry.value as String);
    }
  }

  // Check if user was logged in (for quick startup)
  static bool hasUserData() {
    return _prefs?.containsKey('user_id') ??
        _memoryFallback.containsKey('user_id');
  }

  static Future<void> _setString(String key, String value) async {
    final prefs = _prefs;
    if (prefs == null) {
      _memoryFallback[key] = value;
      return;
    }
    await prefs.setString(key, value);
  }

  static String? _getString(String key) {
    return _prefs?.getString(key) ?? _memoryFallback[key] as String?;
  }

  static Future<void> _setDouble(String key, double value) async {
    final prefs = _prefs;
    if (prefs == null) {
      _memoryFallback[key] = value;
      return;
    }
    await prefs.setDouble(key, value);
  }

  static double? _getDouble(String key) {
    return _prefs?.getDouble(key) ?? _memoryFallback[key] as double?;
  }
}
