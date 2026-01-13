// models/session_model.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart'; // for TimestampConverter

part 'session_model.freezed.dart';
part 'session_model.g.dart';

@freezed
class SessionModel with _$SessionModel {
  const factory SessionModel({
    String? id,
    required String mohaffezId,
    required String studentId,
    required String mohaffezName,
    required String studentName,
    required String sessionType, // 'home' or 'mosque'
    required String location,
    String? mohaffezPhone,
    double? imamAddressLat,
    double? imamAddressLng,
    String? preferredTimeSlot,
    @Default(1) int juzCount,
    String? hifzAssignment,
    String? murajaAssignment,
    @Default(0) int sessionRating,
    String? sessionNotes,
    @TimestampConverter() DateTime? sessionDate,
    @TimestampConverter() DateTime? slotStart,
    @TimestampConverter() DateTime? slotEnd,
    @TimestampConverter() DateTime? createdAt,
    String? status, // ADD THIS - 'pending', 'accepted', 'completed', 'rejected', 'cancelled'
  }) = _SessionModel;

  factory SessionModel.fromJson(Map<String, dynamic> json) =>
      _$SessionModelFromJson(json);

  // ADD THIS METHOD - Required for Firestore integration
  factory SessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SessionModel.fromJson({
      ...data,
      'id': doc.id,
    });
  }
}
