import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import 'platform_time_zone_detector.dart';

/// Best-effort device time-zone sync used only to format server notifications.
/// Booking schedules are always interpreted in Africa/Cairo by the server.
class TimeZoneService {
  TimeZoneService._();

  static StreamSubscription<User?>? _authSubscription;

  static Future<String?> deviceTimeZoneId() async {
    if (kIsWeb) {
      try {
        return _normalizeDetectedTimeZone(detectPlatformTimeZoneId());
      } catch (error) {
        debugPrint('Unable to detect browser time zone: $error');
        return null;
      }
    }

    try {
      final info = await FlutterTimezone.getLocalTimezone();
      return _normalizeDetectedTimeZone(info.identifier);
    } catch (error) {
      debugPrint('Unable to detect device time zone: $error');
      return null;
    }
  }

  static String? _normalizeDetectedTimeZone(Object? value) {
    if (!isPlausibleIanaTimeZone(value)) return null;
    return (value! as String).trim();
  }

  static bool isPlausibleIanaTimeZone(Object? value) {
    if (value is! String) return false;
    final identifier = value.trim();
    if (identifier.isEmpty || identifier.length > 100) return false;
    if (identifier == 'UTC' || identifier == 'GMT') return true;
    return RegExp(r'^[A-Za-z][A-Za-z0-9_+.-]*/[A-Za-z0-9_+./-]+$')
        .hasMatch(identifier);
  }

  static Future<void> initialize() async {
    await _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) return;
      unawaited(syncUserTimeZone(user));
    });
  }

  static Future<void> syncUserTimeZone(User user) async {
    try {
      final detected = await deviceTimeZoneId();
      if (detected == null) return;

      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final snapshot = await ref.get();
      final data = snapshot.data() ?? const <String, dynamic>{};
      if (data['timeZoneId'] == detected &&
          data['timeZoneSource'] == 'device') {
        return;
      }

      await ref.set(
        {
          'timeZoneId': detected,
          'timeZoneSource': 'device',
          'timeZoneUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (error) {
      debugPrint('Time zone sync skipped: $error');
    }
  }
}
