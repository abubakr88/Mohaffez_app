import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required String uid,
    required String email,
    required String name,
    required String role, // 'mohaffez' or 'student'
    String? photoUrl,
    String? phone,
    String? mobile,
    String? specialization,
    String? addressText,
    double? addressLat,
    double? addressLng,
    @Default(0) int followerCount,
    @Default(0) int followingCount,
    @Default(0) int reviewCount,
    @Default(4.5) double rating,
    @TimestampConverter() DateTime? createdAt,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
}

// Timestamp converter for Firestore
class TimestampConverter implements JsonConverter<DateTime?, dynamic> {
  const TimestampConverter();

  @override
  DateTime? fromJson(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is int) return DateTime.fromMillisecondsSinceEpoch(timestamp);
    return null;
  }

  @override
  dynamic toJson(DateTime? date) {
    if (date == null) return null;
    return Timestamp.fromDate(date);
  }
}
