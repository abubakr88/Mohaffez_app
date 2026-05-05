import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PrayerTimeService {
  static const int _egyptianMethod = 5;
  static const _prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

  // In-memory cache — prayer times don't change during a session
  Map<String, String>? _cache;

  /// Returns {Fajr: "04:30", Dhuhr: "12:15", ...} using the teacher's
  /// stored location (addressLat / addressLng on their Firestore profile).
  /// Returns null if location is missing or the API call fails.
  Future<Map<String, String>?> fetchTodayPrayerTimes() async {
    if (_cache != null) return _cache;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();
    if (data == null) return null;

    final lat = data['addressLat'] as double?;
    final lng = data['addressLng'] as double?;
    if (lat == null || lng == null) return null;

    final now = DateTime.now();
    final date =
        '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';

    final uri = Uri.parse(
      'https://api.aladhan.com/v1/timings/$date'
      '?latitude=$lat&longitude=$lng&method=$_egyptianMethod',
    );

    final response =
        await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final timings =
        (json['data'] as Map<String, dynamic>)['timings'] as Map<String, dynamic>;

    final result = <String, String>{};
    for (final name in _prayers) {
      final raw = timings[name] as String?;
      if (raw != null) {
        // Strip optional timezone suffix e.g. "04:30 (EET)"
        result[name] = raw.split(' ').first;
      }
    }

    _cache = result;
    return result;
  }

  void clearCache() => _cache = null;
}
