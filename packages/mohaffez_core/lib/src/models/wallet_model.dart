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

  /// A brand-new wallet for a user who has never had any ledger activity.
  /// Used so UI can render `0.00 ج.م` instead of a spinner forever when no
  /// wallet doc has been created yet (wallets are created lazily server-side).
  factory WalletModel.empty(String userId, WalletOwnerType type) =>
      WalletModel(
        ownerId: userId,
        ownerType: type,
        balancePiastres: 0,
      );
}
