// lib/models/wallet_transaction_model.dart
//
// One row per ledger leg. Same [groupId] ties multi-leg entries together
// (e.g. a session payment has three legs: student debit, teacher credit,
// system_revenue credit — all share the same groupId).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'pricing_plan_model.dart';
import 'wallet_model.dart';

part 'wallet_transaction_model.freezed.dart';
part 'wallet_transaction_model.g.dart';

enum WalletTxType {
  @JsonValue('topup')
  topup,
  @JsonValue('session_payment')
  sessionPayment,
  @JsonValue('session_refund')
  sessionRefund,
  @JsonValue('cycle_settlement')
  cycleSettlement,
  @JsonValue('payout')
  payout,
  @JsonValue('payout_reversal')
  payoutReversal,
  @JsonValue('promo_credit')
  promoCredit,
  @JsonValue('direct_session_commission')
  directSessionCommission,
  @JsonValue('direct_session_commission_reversal')
  directSessionCommissionReversal,
  @JsonValue('adjustment')
  adjustment,
}

@freezed
class WalletTransactionModel with _$WalletTransactionModel {
  const WalletTransactionModel._();

  const factory WalletTransactionModel({
    String? id,
    required String groupId,
    required String walletId,
    required WalletOwnerType ownerType,
    /// Signed: negative = debit, positive = credit.
    required int amountPiastres,
    required WalletTxType type,
    required String reason,
    String? relatedSessionId,
    String? relatedPaymentId,
    String? relatedPayoutId,
    required String createdBy,
    @TimestampConverter() DateTime? createdAt,
  }) = _WalletTransactionModel;

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) =>
      _$WalletTransactionModelFromJson(json);

  factory WalletTransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalletTransactionModel.fromJson({
      ...data,
      'id': doc.id,
    });
  }

  bool get isCredit => amountPiastres > 0;
  bool get isDebit => amountPiastres < 0;
  double get amountEgp => amountPiastres / 100.0;
  double get absAmountEgp => amountPiastres.abs() / 100.0;
}
