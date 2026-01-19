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
    required String sessionType, // home or mosque
    required String location,
    String? mohaffezPhone,
    double? imamAddressLat,
    double? imamAddressLng,
    String? preferredTimeSlot,
    @Default(1) int juzCount,
    
    // التكليف الحالي (الذي سيُنجز في الجلسة القادمة)
    String? hifzAssignment,
    String? murajaAssignment,
    
    // ✅ NEW: تقييم التكليف السابق
    bool? previousHifzCompleted,
    @Default(0) int previousHifzRating, // من 10
    bool? previousMurajaCompleted,
    @Default(0) int previousMurajaRating, // من 10
    String? performanceNotes, // ملاحظات على أداء التكليف السابق
    
    // التقييم العام للجلسة
    @Default(10) int sessionRating, // CHANGED from 5 to 10
    String? sessionNotes,
    
    @TimestampConverter() DateTime? sessionDate,
    @TimestampConverter() DateTime? slotStart,
    @TimestampConverter() DateTime? slotEnd,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? completedAt, // ✅ NEW: تاريخ الإكمال
    
    String? status, // pending, accepted, completed, rejected, cancelled
  }) = _SessionModel;

  factory SessionModel.fromJson(Map<String, dynamic> json) =>
      _$SessionModelFromJson(json);

  // Required for Firestore integration
  factory SessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SessionModel.fromJson({
      ...data,
      'id': doc.id,
    });
  }
}
