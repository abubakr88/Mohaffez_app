import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'user_model.dart';

part 'suspension_model.freezed.dart';
part 'suspension_model.g.dart';

@freezed
class SuspensionModel with _$SuspensionModel {
  const factory SuspensionModel({
    required String uid,
    required String reason,
    required String adminNote,
    required String suspendedBy,
    @TimestampConverter() required DateTime suspendedAt,
    @TimestampConverter() DateTime? expiresAt,
    required bool isPermanent,
    required String type,
  }) = _SuspensionModel;

  factory SuspensionModel.fromJson(Map<String, dynamic> json) =>
      _$SuspensionModelFromJson(json);

  factory SuspensionModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    // WHY: Guarantee uid aligns with Firestore document id.
    return SuspensionModel.fromJson(<String, dynamic>{...data, 'uid': doc.id});
  }
}
