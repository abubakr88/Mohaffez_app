import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'teacher_badge.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

const String roleStudent = 'student';
const String roleParent = 'parent';
const String roleMohaffez = 'mohaffez';
const String roleAdmin = 'admin';
const String roleOrganizationAdmin = 'organization_admin';
const String roleOrganizationTeacher = 'organization_teacher';
const String roleOrganizationStudent = 'organization_student';

const Set<String> learnerAccountRoles = {
  roleStudent,
  roleParent,
};

const Set<String> selfSelectableSignupRoles = {
  roleStudent,
  roleParent,
  roleMohaffez,
};

String normalizeRole(String? role) => (role ?? '').trim().toLowerCase();

bool isLearnerAccountRole(String? role) {
  return learnerAccountRoles.contains(normalizeRole(role));
}

bool isSelfSelectableSignupRole(String? role) {
  return selfSelectableSignupRoles.contains(normalizeRole(role));
}

@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required String uid,
    required String name,
    required String email,
    required String role,
    @Default('active') String status,
    String? photoUrl,
    String? bio,
    String? youtubeVideoUrl,
    String? meetingLink,
    @Default({}) Map<String, String> meetingLinks,
    String? specialization,
    String? phoneNumber,
    @Default(0) int followerCount,
    @Default(0) int followingCount,
    @Default(0.0) double rating,
    @Default(0) int reviewCount,
    String? addressText,
    double? addressLat,
    double? addressLng,
    String? country,
    String? countryCode,
    @Default('individual') String accountType,
    String? activeStudentProfileId,
    @TimestampConverter() DateTime? createdAt,
    // ── Setup Account Fields ─────────────────────────────────
    @Default(false) bool setupCompleted,
    @TimestampConverter() DateTime? dateOfBirth,
    String? city,
    double? examScore,
    @TimestampConverter() DateTime? examTakenAt,
    @Default(0) int examRetryCount,
    @Default(false) bool examPassed,
    @TimestampConverter() DateTime? examNextRetryAt,
    String? gender,
    @UserBadgesConverter() @Default(UserBadges()) UserBadges badges,
    // ── Commission Penalty & Warnings ───────────────────────
    @Default(0.0)
    double
        commissionPenaltyPercent, // teacher: highest penalty this cycle (resets each cycle)
    @Default(0)
    int cancellationWarnings, // total warnings issued (admin visibility)
    // ─────────────────────────────────────────────────────────
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['name'] ?? data['displayName'] ?? '').toString().trim();
    final email = (data['email'] ?? '').toString().trim();
    final role = (data['role'] ?? data['userType'] ?? 'student')
        .toString()
        .trim()
        .toLowerCase();
    final rawMeetingLinks = data['meetingLinks'];
    final meetingLinks = rawMeetingLinks is Map
        ? rawMeetingLinks.map(
            (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
          )
        : <String, String>{};

    return UserModel.fromJson({
      ...data,
      'uid': doc.id,
      'name': name.isNotEmpty ? name : email,
      'email': email,
      'role': role.isNotEmpty ? role : 'student',
      'meetingLinks': meetingLinks,
    });
  }
}

class TimestampConverter implements JsonConverter<DateTime?, Object?> {
  const TimestampConverter();

  @override
  DateTime? fromJson(Object? json) {
    if (json == null) return null;
    if (json is Timestamp) return json.toDate();
    if (json is String) return DateTime.parse(json);
    return null;
  }

  @override
  Object? toJson(DateTime? object) {
    return object != null ? Timestamp.fromDate(object) : null;
  }
}
