// lib/repositories/wallet_repository.dart
//
// Read-only Firestore access + thin wrappers around the wallet Cloud
// Functions. All mutations go through callables — Firestore security rules
// reject direct client writes to wallet collections.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/payout_request_model.dart';
import '../models/wallet_model.dart';
import '../models/wallet_transaction_model.dart';

class WalletRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  WalletRepository(this._firestore, this._functions);

  // ──────────────── reads ────────────────

  /// Streams the current wallet for [userId]. Emits an [WalletModel.empty]
  /// placeholder if the wallet doc does not yet exist server-side, so the UI
  /// can render "0.00 ج.م" instead of waiting indefinitely.
  Stream<WalletModel> watchWallet(String userId, WalletOwnerType ownerType) {
    return _firestore
        .collection('wallets')
        .doc(userId)
        .snapshots()
        .map((snap) => snap.exists
            ? WalletModel.fromFirestore(snap)
            : WalletModel.empty(userId, ownerType));
  }

  /// Paginated ledger for [userId]'s wallet, newest first.
  Stream<List<WalletTransactionModel>> watchTransactions(
    String userId, {
    int limit = 30,
  }) {
    return _firestore
        .collection('walletTransactions')
        .where('walletId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => WalletTransactionModel.fromFirestore(d))
            .toList());
  }

  /// All payout requests for a teacher, newest first.
  Stream<List<PayoutRequestModel>> watchPayoutRequests(String mohaffezId) {
    return _firestore
        .collection('payoutRequests')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PayoutRequestModel.fromFirestore(d))
            .toList());
  }

  // ──────────────── admin queues ────────────────

  /// Pending top-up requests awaiting admin verification, oldest first
  /// (FIFO — fairer to users who've been waiting longest).
  Stream<List<Map<String, dynamic>>> watchPendingTopUps() {
    return _firestore
        .collection('topUpRequests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {...d.data(), 'id': d.id})
            .toList());
  }

  /// Active payout requests (requested OR processing) for the admin queue.
  Stream<List<PayoutRequestModel>> watchActivePayouts() {
    return _firestore
        .collection('payoutRequests')
        .where('status', whereIn: ['requested', 'processing'])
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PayoutRequestModel.fromFirestore(d))
            .toList());
  }

  // ──────────────── mutations (callables) ────────────────

  /// Student creates a pending top-up request after sending money via
  /// bank/wallet. Admin verifies it via [verifyWalletTopUp] (server-side).
  /// Returns the new request id.
  Future<String> createTopUpRequest({
    required String userId,
    required WalletOwnerType ownerType,
    required double amountEgp,
    required String method, // 'instapay' | 'vodafone_cash' | 'bank_transfer'
    required String referenceNumber,
    String? proofUrl,
  }) async {
    final ref = await _firestore.collection('topUpRequests').add({
      'userId': userId,
      'ownerType': ownerType == WalletOwnerType.student ? 'student' : 'mohaffez',
      'amountEgp': amountEgp,
      'method': method,
      'referenceNumber': referenceNumber,
      'proofUrl': proofUrl,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Student pays a session from their wallet. Returns the new session id.
  /// [amountEgp] is always sent — server prefers paymentAmount on the doc
  /// when present and falls back to this otherwise.
  Future<String> payFromWallet({
    required String sessionRequestId,
    required double amountEgp,
  }) async {
    final res = await _functions.httpsCallable('payFromWallet').call({
      'sessionRequestId': sessionRequestId,
      'amountEgp': amountEgp,
    });
    return (res.data as Map)['sessionId'] as String;
  }

  /// Teacher requests a payout.
  Future<String> requestPayout({
    required double amountEgp,
    required PayoutMethod method,
    required String accountDetails,
  }) async {
    final res = await _functions.httpsCallable('requestPayout').call({
      'amountEgp': amountEgp,
      'method': _methodToWire(method),
      'accountDetails': accountDetails,
    });
    return (res.data as Map)['payoutRequestId'] as String;
  }

  // ──────────────── admin mutations ────────────────

  Future<void> verifyWalletTopUp({
    required String topUpRequestId,
    double? paidAmountEgp,
    String? adminNote,
  }) async {
    await _functions.httpsCallable('verifyWalletTopUp').call({
      'topUpRequestId': topUpRequestId,
      if (paidAmountEgp != null) 'paidAmountEgp': paidAmountEgp,
      if (adminNote != null) 'adminNote': adminNote,
    });
  }

  Future<void> rejectWalletTopUp({
    required String topUpRequestId,
    required String reason,
  }) async {
    await _functions.httpsCallable('rejectWalletTopUp').call({
      'topUpRequestId': topUpRequestId,
      'reason': reason,
    });
  }

  Future<void> adminCreditWallet({
    required String userId,
    required WalletOwnerType ownerType,
    required double amountEgp,
    required String reason,
    String type = 'adjustment',
  }) async {
    await _functions.httpsCallable('adminCreditWallet').call({
      'userId': userId,
      'ownerType':
          ownerType == WalletOwnerType.student ? 'student' : 'mohaffez',
      'amountEgp': amountEgp,
      'reason': reason,
      'type': type,
    });
  }

  Future<void> refundSessionPayment({
    required String sessionId,
    required String reason,
  }) async {
    await _functions.httpsCallable('refundSessionPayment').call({
      'sessionId': sessionId,
      'reason': reason,
    });
  }

  Future<void> startPayout(String payoutRequestId) async {
    await _functions
        .httpsCallable('startPayout')
        .call({'payoutRequestId': payoutRequestId});
  }

  Future<void> completePayout(String payoutRequestId,
      {String? bankReference}) async {
    await _functions.httpsCallable('completePayout').call({
      'payoutRequestId': payoutRequestId,
      if (bankReference != null) 'bankReference': bankReference,
    });
  }

  Future<void> failPayout(String payoutRequestId, String reason) async {
    await _functions.httpsCallable('failPayout').call({
      'payoutRequestId': payoutRequestId,
      'reason': reason,
    });
  }

  String _methodToWire(PayoutMethod m) {
    switch (m) {
      case PayoutMethod.instapay:
        return 'instapay';
      case PayoutMethod.vodafoneCash:
        return 'vodafone_cash';
      case PayoutMethod.bankTransfer:
        return 'bank_transfer';
    }
  }
}

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(
    FirebaseFirestore.instance,
    FirebaseFunctions.instance,
  );
});
