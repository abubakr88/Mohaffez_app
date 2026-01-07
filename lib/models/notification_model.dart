
import 'package:freezed_annotation/freezed_annotation.dart';
import 'user_model.dart';

part 'notification_model.freezed.dart';
part 'notification_model.g.dart';

@freezed
class NotificationModel with _$NotificationModel {
  const factory NotificationModel({
    String? id,
    required String userId,
    required String title,
    required String body,
    required String type, // 'session', 'follow', 'system'
    @Default(false) bool isRead,
    String? scheduleId,
    String? mohaffezId,
    String? mohaffezName,
    @TimestampConverter() DateTime? createdAt,
  }) = _NotificationModel;

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);
}
