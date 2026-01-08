import 'package:freezed_annotation/freezed_annotation.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

part 'session_request_model.freezed.dart';
part 'session_request_model.g.dart';

enum SessionRequestStatus {
  pending,
  accepted,
  rejected,
}

@freezed
class SessionRequestModel with _$SessionRequestModel {
  const factory SessionRequestModel({
    String? id,
    required String studentId,
    required String mohaffezId,
    required String studentName,
    required String mohaffezName,
    required String sessionType,
    required String preferredTimeSlot,
    @Default(SessionRequestStatus.pending) SessionRequestStatus status,
    String? imamAddressText,
    double? imamAddressLat,
    double? imamAddressLng,
    String? mohaffezPhone,
    @TimestampConverter() DateTime? slotDate,
    @TimestampConverter() DateTime? slotStart,
    @TimestampConverter() DateTime? slotEnd,
    @TimestampConverter() DateTime? createdAt,
  }) = _SessionRequestModel;

  factory SessionRequestModel.fromJson(Map<String, dynamic> json) =>
      _$SessionRequestModelFromJson(json);
}
