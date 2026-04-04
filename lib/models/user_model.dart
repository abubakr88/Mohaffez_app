import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

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
    String? specialization,
    String? phoneNumber,
    @Default(0) int followerCount,
    @Default(0) int followingCount,
    @Default(0.0) double rating,
    @Default(0) int reviewCount,
    String? addressText,
    double? addressLat,
    double? addressLng,
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
    // ─────────────────────────────────────────────────────────
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromJson({
      ...data,
      'uid': doc.id,
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
