import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math'; // ✅ إضافة هذا السطر
import 'teacher_badge.dart';
import 'teacher_discovery.dart';
import 'user_model.dart';

Map<String, dynamic> withPublicTeacherRatingV2(
  Map<String, dynamic> data,
) {
  final ratingPolicyVersion =
      (data['ratingPolicyVersion'] as num?)?.toInt() ?? 0;
  final usesCurrentRatingPolicy = ratingPolicyVersion == 2;
  return {
    ...data,
    'rating': usesCurrentRatingPolicy
        ? (data['rating'] as num?)?.toDouble() ?? 0.0
        : 0.0,
    'reviewCount': usesCurrentRatingPolicy
        ? (data['reviewCount'] as num?)?.toInt() ?? 0
        : 0,
    'ratingPolicyVersion': ratingPolicyVersion,
  };
}

class MohaffezModel {
  final String id;
  final String name;
  final String? honorific;
  final String? photoUrl;
  final String? specialization;
  final Map<String, bool> teachingServices;
  final LearnerAudienceMatrix learnerAudiences;
  final Map<String, bool> learnerAgeGroups;
  final Map<String, bool> learnerGenders;
  final Map<String, bool> learnerLevels;
  final Map<String, bool> teachingLanguages;
  final String? primaryTeachingLanguage;
  final int discoveryProfileVersion;
  final double? addressLat;
  final double? addressLng;
  final String? addressText;
  final double rating;
  final int reviewCount;
  final int ratingPolicyVersion;
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
    this.teachingServices = const {},
    this.learnerAudiences = const {},
    this.learnerAgeGroups = const {},
    this.learnerGenders = const {},
    this.learnerLevels = const {},
    this.teachingLanguages = const {},
    this.primaryTeachingLanguage,
    this.discoveryProfileVersion = 0,
    this.addressLat,
    this.addressLng,
    this.addressText,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.ratingPolicyVersion = 0,
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
    final rawData = doc.data() as Map<String, dynamic>?;
    if (rawData == null) {
      throw Exception('Document data is null');
    }
    final data = withPublicTeacherRatingV2(rawData);

    return MohaffezModel(
      id: doc.id,
      name: data['name'] as String? ?? 'لا يوجد اسم',
      honorific: data['honorific'] as String?,
      photoUrl: data['photoUrl'] as String?,
      specialization: data['specialization'] as String?,
      teachingServices: parseDiscoveryFacet(data['teachingServices']),
      learnerAudiences: parseLearnerAudiences(data['learnerAudiences']),
      learnerAgeGroups: parseDiscoveryFacet(data['learnerAgeGroups']),
      learnerGenders: parseDiscoveryFacet(data['learnerGenders']),
      learnerLevels: parseDiscoveryFacet(data['learnerLevels']),
      teachingLanguages: parseDiscoveryFacet(data['teachingLanguages']),
      primaryTeachingLanguage: data['primaryTeachingLanguage'] as String?,
      discoveryProfileVersion:
          (data['discoveryProfileVersion'] as num?)?.toInt() ?? 0,
      addressLat: (data['addressLat'] as num?)?.toDouble(),
      addressLng: (data['addressLng'] as num?)?.toDouble(),
      addressText: data['addressText'] as String?,
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      ratingPolicyVersion: (data['ratingPolicyVersion'] as num?)?.toInt() ?? 0,
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
  String get ratingLabel =>
      reviewCount > 0 ? rating.toStringAsFixed(1) : 'جديد';

  Set<String> get effectiveTeachingServiceIds => teachingServices.isNotEmpty
      ? teachingServices.keys.toSet()
      : TeacherDiscoveryTaxonomy.legacyServiceIds(specialization);

  bool supportsService(String? id) =>
      id == null || effectiveTeachingServiceIds.contains(id);

  LearnerAudienceMatrix get effectiveLearnerAudiences {
    if (!learnerAudiencesAreEmpty(learnerAudiences)) {
      return learnerAudiences;
    }
    return learnerAudiencesFromLegacy(learnerAgeGroups, learnerGenders);
  }

  bool get hasLearnerAudienceData =>
      !learnerAudiencesAreEmpty(effectiveLearnerAudiences);

  bool teachesAudience(
    String? ageGroup,
    String? learnerGender, {
    bool allowIncomplete = false,
  }) {
    if (ageGroup == null || learnerGender == null) return false;
    if (!hasLearnerAudienceData) return allowIncomplete;
    return learnerAudienceContains(
      effectiveLearnerAudiences,
      ageGroup,
      learnerGender,
    );
  }

  bool matchesDiscoveryFilters({
    String? service,
    String? ageGroup,
    String? learnerGender,
    String? learnerLevel,
    String? teachingLanguage,
  }) {
    bool matches(Map<String, bool> facet, String? id) =>
        id == null || id.isEmpty || facet[id] == true;
    return supportsService(service) &&
        ((ageGroup == null && learnerGender == null) ||
            teachesAudience(ageGroup, learnerGender)) &&
        matches(learnerLevels, learnerLevel) &&
        matches(teachingLanguages, teachingLanguage);
  }

  int discoveryMatchScore({
    String? service,
    String? ageGroup,
    String? learnerGender,
    String? learnerLevel,
    String? teachingLanguage,
  }) {
    var score = 0;
    if (service != null && supportsService(service)) score += 40;
    if (teachingLanguage != null &&
        teachingLanguages[teachingLanguage] == true) {
      score += 25;
      if (primaryTeachingLanguage == teachingLanguage) score += 2;
    }
    if (teachesAudience(ageGroup, learnerGender)) {
      score += 25;
    }
    if (learnerLevel != null && learnerLevels[learnerLevel] == true) {
      score += 10;
    }
    return score;
  }

  List<String> discoveryBadges({int max = 3, bool english = false}) {
    final badges = <String>[];
    for (final service in effectiveTeachingServiceIds) {
      badges.add(TeacherDiscoveryTaxonomy.label(
        TeacherDiscoveryTaxonomy.services,
        service,
        english: english,
      ));
      if (badges.length == max) return badges;
    }
    for (final ageGroup
        in learnerAudienceAgeGroups(effectiveLearnerAudiences)) {
      badges.add(TeacherDiscoveryTaxonomy.label(
        TeacherDiscoveryTaxonomy.ageGroups,
        ageGroup,
        english: english,
      ));
      if (badges.length == max) return badges;
    }
    for (final language in teachingLanguages.keys) {
      badges.add(TeacherDiscoveryTaxonomy.label(
        TeacherDiscoveryTaxonomy.languages,
        language,
        english: english,
      ));
      if (badges.length == max) return badges;
    }
    return badges;
  }

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
