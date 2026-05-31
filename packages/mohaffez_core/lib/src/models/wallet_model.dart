// lib/models/wallet_model.dart
//
// Mirror of the server-side wallet schema. Amounts are stored as integer
// piastres on the server; the model exposes both [balancePiastres] (the
// authoritative value) and [balanceEgp] for display.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'pricing_plan_model.dart'; // re-uses TimestampConverter

part 'wallet_model.freezed.dart';
part 'wallet_model.g.dart';

enum WalletOwnerType {
  @JsonValue('student')
  student,
  @JsonValue('mohaffez')
  mohaffez,
  @JsonValue('system')
  system,
}

@freezed
class WalletModel with _$WalletModel {
  const WalletModel._();

  const factory WalletModel({
    required String ownerId,
    required WalletOwnerType ownerType,
    required int balancePiastres,
    /// Teacher-only. Gross earnings of the current commission cycle, not
    /// yet settled. Becomes part of [balancePiastres] (net of commission)
    /// when the bi-weekly settlement runs. Not withdrawable.
    @Default(0) int pendingCyclePiastres,
    /// Teacher-only. Accumulated commission OWED to the platform from
    /// direct-payment (cash) sessions this cycle. Negative when the
    /// teacher owes; zeroed/reduced at settlement (drained from available
    /// balance, any leftover rolls forward as a still-negative value).
    @Default(0) int directCommissionOwedPiastres,
    /// Teacher-only. Timestamp of the last cycle settlement on this wallet.
    @TimestampConverter() DateTime? lastSettledAt,
    @Default('EGP') String currency,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? updatedAt,
  }) = _WalletModel;

  factory WalletModel.fromJson(Map<String, dynamic> json) =>
      _$WalletModelFromJson(json);

  factory WalletModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalletModel.fromJson({
      ...data,
      'ownerId': doc.id,
    });
  }

  /// Convenience: display value in EGP. Server is source of truth in piastres.
  double get balanceEgp => balancePiastres / 100.0;

  /// Teacher-only. Current cycle's gross earnings in EGP, awaiting settlement.
  double get pendingCycleEgp => pendingCyclePiastres / 100.0;

  /// Teacher-only. True when there is current-cycle gross still pending.
  bool get hasPendingCycleEarnings => pendingCyclePiastres > 0;

  /// Teacher-only. Direct-payment commission owed to the platform this
  /// cycle, expressed as a POSITIVE EGP value (the stored field is
  /// negative; we flip it so 'owes 30 ج.م' reads naturally in UI).
  double get directCommissionOwedEgp =>
      directCommissionOwedPiastres >= 0
          ? 0
          : (-directCommissionOwedPiastres) / 100.0;

  /// Teacher-only. True when the teacher owes the platform commission
  /// from cash sessions (i.e. directCommissionOwedPiastres < 0).
  bool get hasDuesOwed => directCommissionOwedPiastres < 0;

  /// A brand-new wallet for a user who has never had any ledger activity.
  /// Used so UI can render `0.00 ج.م` instead of a spinner forever when no
  /// wallet doc has been created yet (wallets are created lazily server-side).
  factory WalletModel.empty(String userId, WalletOwnerType type) =>
      WalletModel(
        ownerId: userId,
        ownerType: type,
        balancePiastres: 0,
        pendingCyclePiastres: 0,
        directCommissionOwedPiastres: 0,
      );
}
