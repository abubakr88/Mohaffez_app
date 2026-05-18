// lib/models/payout_request_model.dart
//
// Teacher-initiated withdrawal. State machine on server:
//   requested → processing → completed | failed

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'pricing_plan_model.dart'; // TimestampConverter

part 'payout_request_model.freezed.dart';
part 'payout_request_model.g.dart';

enum PayoutStatus {
  @JsonValue('requested')
  requested,
  @JsonValue('processing')
  processing,
  @JsonValue('completed')
  completed,
  @JsonValue('failed')
  failed,
}

enum PayoutMethod {
  @JsonValue('instapay')
  instapay,
  @JsonValue('vodafone_cash')
  vodafoneCash,
  @JsonValue('bank_transfer')
  bankTransfer,
}

@freezed
class PayoutRequestModel with _$PayoutRequestModel {
  const PayoutRequestModel._();

  const factory PayoutRequestModel({
    String? id,
    required String mohaffezId,
    @Default('') String mohaffezName,
    required double amountEgp,
    required int amountPiastres,
    required PayoutMethod method,
    required String accountDetails,
    required PayoutStatus status,
    String? ledgerGroupId,
    String? bankReference,
    String? failureReason,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? startedAt,
    @TimestampConverter() DateTime? completedAt,
    @TimestampConverter() DateTime? failedAt,
    @TimestampConverter() DateTime? updatedAt,
  }) = _PayoutRequestModel;

  factory PayoutRequestModel.fromJson(Map<String, dynamic> json) =>
      _$PayoutRequestModelFromJson(json);

  factory PayoutRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PayoutRequestModel.fromJson({
      ...data,
      'id': doc.id,
    });
  }

  bool get isTerminal =>
      status == PayoutStatus.completed || status == PayoutStatus.failed;
  bool get isInFlight =>
      status == PayoutStatus.requested || status == PayoutStatus.processing;
}
