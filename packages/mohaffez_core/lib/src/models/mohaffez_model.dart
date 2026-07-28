import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math'; // ✅ إضافة هذا السطر
import 'teacher_badge.dart';
import 'user_model.dart';

class MohaffezModel {
  final String id;
  final String name;
  final String? honorific;
  final String? photoUrl;
  final String? specialization;
  final double? addressLat;
  final double? addressLng;
  final String? addressText;
  final double rating;
  final int reviewCount;
  final int followerCount;
  final String? bio;
  final String? phoneNumber;
  final String? gender;
  final bool acceptingNewBookings;
  final bool trialSessionEnabled;
  final String? pricingSearchText;
  final UserBadges badges;

  MohaffezModel({
    required this.id,
    required this.name,
    this.honorific,
    this.photoUrl,
    this.specialization,
    this.addressLat,
    this.addressLng,
    this.addressText,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.followerCount = 0,
    this.bio,
    this.phoneNumber,
    this.gender,
    this.acceptingNewBookings = true,
    this.trialSessionEnabled = false,
    this.pricingSearchText,
    this.badges = const UserBadges(),
  });

  factory MohaffezModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null');
    }

    return MohaffezModel(
      id: doc.id,
      name: data['name'] as String? ?? 'لا يوجد اسم',
      honorific: data['honorific'] as String?,
      photoUrl: data['photoUrl'] as String?,
      specialization: data['specialization'] as String?,
      addressLat: (data['addressLat'] as num?)?.toDouble(),
      addressLng: (data['addressLng'] as num?)?.toDouble(),
      addressText: data['addressText'] as String?,
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      followerCount: data['followerCount'] as int? ?? 0,
      bio: data['bio'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      gender: data['gender'] as String?,
      acceptingNewBookings: data['acceptingNewBookings'] != false,
      trialSessionEnabled: data['trialSessionEnabled'] == true,
      pricingSearchText: data['pricingSearchText'] as String?,
      badges: UserBadges.fromJson(data['badges']),
    );
  }

  String get displayName => composeTeacherDisplayName(name, honorific);

  /// Confidence-adjusted score used for ordering teachers. Five prior reviews
  /// at the neutral-positive platform baseline prevent one early review from
  /// placing a new teacher at the top or bottom of the list.
  double get reputationScore {
    if (reviewCount <= 0 || rating <= 0) return 0;
    const priorRating = 4.0;
    const priorWeight = 5;
    final normalizedRating = rating.clamp(0.0, 5.0);
    return ((normalizedRating * reviewCount) + (priorRating * priorWeight)) /
        (reviewCount + priorWeight);
  }

  // Calculate distance from user location
  double? getDistanceFrom(double? userLat, double? userLng) {
    if (userLat == null ||
        userLng == null ||
        addressLat == null ||
        addressLng == null) {
      return null;
    }
    return _calculateDistance(userLat, userLng, addressLat!, addressLng!);
  }

  // Haversine formula - ✅ استخدام الدوال من dart:math
  static double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180.0;
}
