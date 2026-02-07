import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

part 'payment_model.freezed.dart';
part 'payment_model.g.dart';

enum PaymentMethod {
  @JsonValue('card')
  card,
  @JsonValue('wallet')
  wallet,
  @JsonValue('cash')
  cash,
  @JsonValue('bank_transfer')
  bankTransfer,
}

enum PaymentStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('processing')
  processing,
  @JsonValue('completed')
  completed,
  @JsonValue('failed')
  failed,
  @JsonValue('refunded')
  refunded,
}

enum PaymentGateway {
  @JsonValue('paymob')
  paymob,
  @JsonValue('fawry')
  fawry,
  @JsonValue('stripe')
  stripe,
  @JsonValue('manual')
  manual,
}

@freezed
class PaymentModel with _$PaymentModel {
  const factory PaymentModel({
    String? id,
    required String studentId,
    required String studentName,
    required String studentEmail,
    required String studentPhone,
    required String mohaffezId,
    required String mohaffezName,
    required String planId,
    required String planTitle,
    required double amount,
    @Default('EGP') String currency,
    required PaymentMethod method,
    required PaymentStatus status,
    PaymentGateway? gateway,
    String? subscriptionId,
    String? sessionId,
    String? transactionReference,
    String? gatewayOrderId,
    String? gatewayTransactionId,
    String? failureReason,
    Map<String, dynamic>? metadata,
    @TimestampConverter() DateTime? paidAt,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? updatedAt,
  }) = _PaymentModel;

  factory PaymentModel.fromJson(Map<String, dynamic> json) =>
      _$PaymentModelFromJson(json);

  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentModel.fromJson({
      ...data,
      'id': doc.id,
    });
  }
}
